import Foundation
import UIKit

// MARK: - Planote API Client

/// Cloud Run の Planote API と通信するアクター。
/// - baseURL は Info.plist の `PLANOTE_BASE_URL` から取得 (xcconfig で Debug/Release 切替)
/// - すべての `/v1/*` リクエストに `Authorization: Bearer` と `X-AppAttest-*` ヘッダを自動付与
///   (例外: `/v1/auth/*`, `/v1/attest/*` は循環参照を避けるためスキップ)
actor PlanoteAPIClient {
    static let shared = PlanoteAPIClient()

    private let baseURL: String
    private let session: URLSession

    private init() {
        let resolved = (Bundle.main.object(forInfoDictionaryKey: "PLANOTE_BASE_URL") as? String) ?? ""
        self.baseURL = resolved
        if resolved.isEmpty {
            Log.api.error("PLANOTE_BASE_URL is not configured")
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Full Scan Flow

    /// スキャン → アップロード → ノート作成 → 処理 → 候補取得 を一括実行。
    func scanAndProcess(image: UIImage) async throws -> (noteId: String, candidates: [ExtractionCandidate]) {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError.invalidImage
        }

        let fileName = "scan_\(Int(Date().timeIntervalSince1970)).jpg"

        // 1. 署名付き URL を発行
        let uploadInfo = try await createUpload(contentType: "image/jpeg", fileName: fileName)

        // 2. 画像を署名付き URL にアップロード
        try await uploadImage(data: imageData, to: uploadInfo.upload_url, contentType: "image/jpeg")

        // 3. ノート作成 (object_path はサーバーで解決するためクライアントから送らない)
        let note = try await createNote(uploadId: uploadInfo.upload_id)

        // 4. ノート処理 (OCR + 抽出)
        let processResult = try await processNote(noteId: note.note_id)

        if processResult.extraction_status == "completed" && !processResult.candidates.isEmpty {
            return (note.note_id, processResult.candidates)
        }

        // 5. 完了するまで指数バックオフでポーリング
        let candidates = try await pollForCandidates(noteId: note.note_id)
        return (note.note_id, candidates)
    }

    /// 選択された候補をサーバーに confirm する。
    func confirmCandidates(noteId: String, candidateIds: [String]) async throws -> NoteConfirmResponse {
        let request = NoteConfirmRequest(candidate_ids: candidateIds)
        return try await post(path: "/v1/notes/\(noteId)/confirm", body: request)
    }

    // MARK: - Individual API Calls

    private func createUpload(contentType: String, fileName: String) async throws -> CreateUploadResponse {
        let request = CreateUploadRequest(content_type: contentType, file_name: fileName)
        return try await post(path: "/v1/uploads", body: request, expectedStatus: 201)
    }

    /// 署名付き URL に直接 PUT。GCS のホストのみ許可する。
    private func uploadImage(data: Data, to urlString: String, contentType: String) async throws {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        // ホスト検証: GCS の signed URL でなければ拒否 (中間者対策)
        guard let host = url.host,
              host == "storage.googleapis.com" || host.hasSuffix(".storage.googleapis.com") else {
            Log.api.error("Untrusted upload URL host")
            throw APIError.untrustedUploadURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.api.error("Upload failed: status=\(statusCode)")
            _ = responseData
            throw APIError.uploadFailed(statusCode: statusCode)
        }
    }

    private func createNote(uploadId: String) async throws -> NoteCreateResponse {
        let request = NoteCreateRequest(upload_id: uploadId)
        return try await post(path: "/v1/notes", body: request, expectedStatus: 201)
    }

    private func processNote(noteId: String) async throws -> ProcessResponseV1 {
        // note 単位で固定の Idempotency-Key にすることで、同じ note への再処理を抑止
        let idempotencyKey = "process-\(noteId)"
        return try await post(
            path: "/v1/notes/\(noteId)/process",
            idempotencyKey: idempotencyKey
        )
    }

    private func getCandidates(noteId: String) async throws -> ExtractionsResponse {
        return try await get(path: "/v1/notes/\(noteId)/candidates")
    }

    /// 指数バックオフ + ジッターで候補完了をポーリング。
    private func pollForCandidates(noteId: String, maxAttempts: Int = 12) async throws -> [ExtractionCandidate] {
        var delayMs: UInt64 = 1_000  // 初回 1 秒
        for _ in 0..<maxAttempts {
            let jitter = UInt64.random(in: 0...500)
            try await Task.sleep(nanoseconds: (delayMs + jitter) * 1_000_000)

            let result = try await getCandidates(noteId: noteId)
            switch result.status {
            case "completed":
                return result.candidates
            case "failed":
                throw APIError.processingFailed
            default:
                break
            }
            delayMs = min(delayMs * 2, 8_000)  // 上限 8 秒
        }
        throw APIError.timeout
    }

    // MARK: - HTTP Helpers

    /// `/v1/auth/*`, `/v1/attest/*` を判定して認証ヘッダ付与をスキップする。
    private func shouldSkipAuth(for path: String) -> Bool {
        return path.hasPrefix("/v1/auth/") || path.hasPrefix("/v1/attest/")
    }

    /// 共通ヘッダ (認証 + App Attest) を付与する。
    /// - Parameter skipAuth: bootstrap 系パスでは true を渡す。
    private func attachCommonHeaders(_ request: inout URLRequest, skipAuth: Bool) async throws {
        if skipAuth { return }

        // 1. Authorization
        let token = try await AuthService.shared.currentAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // 2. App Attest assertion (リクエストボディに対する)
        let bodyForAssertion = request.httpBody ?? Data()
        let (keyId, assertion) = try await AppAttestService.shared.assertion(for: bodyForAssertion)
        request.setValue(keyId, forHTTPHeaderField: "X-AppAttest-KeyID")
        request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-AppAttest-Assertion")
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await attachCommonHeaders(&request, skipAuth: shouldSkipAuth(for: path))

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, expectedStatus: nil)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(
        path: String,
        expectedStatus: Int? = nil,
        idempotencyKey: String? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        try await attachCommonHeaders(&request, skipAuth: shouldSkipAuth(for: path))

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, expectedStatus: expectedStatus)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(
        path: String,
        body: Body,
        expectedStatus: Int? = nil,
        idempotencyKey: String? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        try await attachCommonHeaders(&request, skipAuth: shouldSkipAuth(for: path))

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, expectedStatus: expectedStatus)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// レスポンス検証。`expectedStatus` 指定時はその値と一致すること。
    /// 不一致または非 2xx の場合は `APIError.serverError` を投げる(本文はログ専用、UI 非露出)。
    private func validateResponse(_ response: URLResponse, data: Data, expectedStatus: Int?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: -1, internalBody: nil)
        }
        let bodyString = String(data: data, encoding: .utf8)

        if let expected = expectedStatus, httpResponse.statusCode != expected {
            Log.api.error("Unexpected status: got=\(httpResponse.statusCode) expected=\(expected)")
            throw APIError.serverError(statusCode: httpResponse.statusCode, internalBody: bodyString)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            Log.api.error("Server error: status=\(httpResponse.statusCode)")
            throw APIError.serverError(statusCode: httpResponse.statusCode, internalBody: bodyString)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidImage
    case untrustedUploadURL
    case uploadFailed(statusCode: Int)
    case serverError(statusCode: Int, internalBody: String?)
    case processingFailed
    case timeout

    /// ユーザー向けメッセージ。サーバー本文は絶対に出さない。
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "無効なURLです")
        case .invalidImage:
            return String(localized: "画像の変換に失敗しました")
        case .untrustedUploadURL:
            return String(localized: "アップロード先のURLが信頼できません")
        case .uploadFailed(let code):
            return String(localized: "アップロードに失敗しました (コード: \(code))")
        case .serverError(let code, _):
            return String(localized: "サーバーエラーが発生しました (コード: \(code))")
        case .processingFailed:
            return String(localized: "画像の処理に失敗しました")
        case .timeout:
            return String(localized: "処理がタイムアウトしました")
        }
    }

    /// ログ専用の詳細表現。UI には出さないこと。
    var internalDebugDescription: String {
        switch self {
        case .invalidURL: return "invalidURL"
        case .invalidImage: return "invalidImage"
        case .untrustedUploadURL: return "untrustedUploadURL"
        case .uploadFailed(let code): return "uploadFailed(\(code))"
        case .serverError(let code, let body):
            return "serverError(\(code)): \(body ?? "nil")"
        case .processingFailed: return "processingFailed"
        case .timeout: return "timeout"
        }
    }
}
