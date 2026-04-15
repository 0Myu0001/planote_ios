import Foundation
import UIKit

actor PlanoteAPIClient {
    static let shared = PlanoteAPIClient()

    private let baseURL = "https://planote-api-709346610161.asia-northeast1.run.app"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Full Scan Flow

    /// Executes the complete scan flow: upload → create note → process → return candidates
    func scanAndProcess(image: UIImage) async throws -> (noteId: String, candidates: [ExtractionCandidate]) {
        // 1. Get JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError.invalidImage
        }

        let fileName = "scan_\(Int(Date().timeIntervalSince1970)).jpg"

        // 2. Request a signed upload URL
        let uploadInfo = try await createUpload(contentType: "image/jpeg", fileName: fileName)

        // 3. Upload the image to the signed URL
        try await uploadImage(data: imageData, to: uploadInfo.upload_url, contentType: "image/jpeg")

        // 4. Create a note from the upload
        let note = try await createNote(uploadId: uploadInfo.upload_id, objectPath: uploadInfo.object_path)

        // 5. Process the note (OCR + extraction)
        let processResult = try await processNote(noteId: note.note_id)

        // 6. If extraction is still processing, poll for candidates
        if processResult.extraction_status == "completed" && !processResult.candidates.isEmpty {
            return (note.note_id, processResult.candidates)
        }

        // Poll for candidates
        let candidates = try await pollForCandidates(noteId: note.note_id)
        return (note.note_id, candidates)
    }

    /// Confirm selected candidates
    func confirmCandidates(noteId: String, candidateIds: [String]) async throws -> NoteConfirmResponse {
        let request = NoteConfirmRequest(candidate_ids: candidateIds)
        return try await post(path: "/v1/notes/\(noteId)/confirm", body: request)
    }

    // MARK: - Individual API Calls

    private func createUpload(contentType: String, fileName: String) async throws -> CreateUploadResponse {
        let request = CreateUploadRequest(content_type: contentType, file_name: fileName)
        return try await post(path: "/v1/uploads", body: request, expectedStatus: 201)
    }

    private func uploadImage(data: Data, to urlString: String, contentType: String) async throws {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.uploadFailed(statusCode: statusCode)
        }
    }

    private func createNote(uploadId: String, objectPath: String) async throws -> NoteCreateResponse {
        let request = NoteCreateRequest(upload_id: uploadId, object_path: objectPath)
        return try await post(path: "/v1/notes", body: request, expectedStatus: 201)
    }

    private func processNote(noteId: String) async throws -> ProcessResponseV1 {
        return try await post(path: "/v1/notes/\(noteId)/process")
    }

    private func getCandidates(noteId: String) async throws -> ExtractionsResponse {
        return try await get(path: "/v1/notes/\(noteId)/candidates")
    }

    private func pollForCandidates(noteId: String, maxAttempts: Int = 30, intervalSeconds: UInt64 = 2) async throws -> [ExtractionCandidate] {
        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)

            let result = try await getCandidates(noteId: noteId)

            switch result.status {
            case "completed":
                return result.candidates
            case "failed":
                throw APIError.processingFailed
            default:
                continue
            }
        }
        throw APIError.timeout
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError(statusCode: statusCode, body: String(data: data, encoding: .utf8))
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(path: String, expectedStatus: Int? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError(statusCode: statusCode, body: String(data: data, encoding: .utf8))
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(path: String, body: Body, expectedStatus: Int? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError(statusCode: statusCode, body: String(data: data, encoding: .utf8))
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidImage
    case uploadFailed(statusCode: Int)
    case serverError(statusCode: Int, body: String?)
    case processingFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidImage:
            return "画像の変換に失敗しました"
        case .uploadFailed(let code):
            return "アップロードに失敗しました (コード: \(code))"
        case .serverError(let code, let body):
            return "サーバーエラー (コード: \(code))\(body.map { ": \($0)" } ?? "")"
        case .processingFailed:
            return "画像の処理に失敗しました"
        case .timeout:
            return "処理がタイムアウトしました"
        }
    }
}
