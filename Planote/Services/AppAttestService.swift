import Foundation
import DeviceCheck
import CryptoKit
import Security

// MARK: - App Attest Service

/// DCAppAttestService を使った attestation / assertion を担当。
/// - 初回起動時にキー生成 → サーバーで attestation 検証
/// - 以降の API 呼び出しごとに assertion を生成して `X-AppAttest-*` ヘッダに添付
/// - keyId は Keychain に永続化(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)
actor AppAttestService {
    static let shared = AppAttestService()

    private let service = DCAppAttestService.shared
    private let keychainService = "com.planote.app.appattest"
    private let keychainAccount = "keyId"

    /// メモリキャッシュ。Keychain と同期。
    private var cachedKeyId: String?
    /// 当該キーの attestation 検証がサーバーで成功済みか。
    private var hasAttested: Bool = false
    /// 並行 setup を1回にまとめる。
    private var setupTask: Task<Void, Error>?

    private let bootstrapSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private init() {
        cachedKeyId = readKeyIdFromKeychain()
    }

    private static var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "PLANOTE_BASE_URL") as? String) ?? ""
    }

    // MARK: - Public API

    /// 必要なら attestation までを実行。既に完了していれば即 return。
    /// 並行呼び出しは 1 タスクに集約される。
    func setupIfNeeded() async throws {
        if hasAttested { return }

        // Simulator + DEBUG はバイパス(App Attest 非対応)
        #if targetEnvironment(simulator)
        #if DEBUG
        Log.attest.info("App Attest skipped (simulator + DEBUG)")
        hasAttested = true
        return
        #endif
        #endif

        guard service.isSupported else {
            #if DEBUG
            Log.attest.info("App Attest unsupported on this device (DEBUG bypass)")
            hasAttested = true
            return
            #else
            throw AppAttestError.unsupported
            #endif
        }

        if let task = setupTask {
            return try await task.value
        }
        let task = Task<Void, Error> { [weak self] in
            try await self?.performSetup()
        }
        setupTask = task
        defer { setupTask = nil }
        try await task.value
    }

    /// リクエストデータを SHA256 でハッシュして assertion を返す。
    /// サーバー側は同じ計算で検証する。
    func assertion(for requestData: Data) async throws -> (keyId: String, assertion: Data) {
        try await setupIfNeeded()

        guard let keyId = cachedKeyId else {
            #if DEBUG
            // バイパス時のダミー
            return ("debug-bypass", Data())
            #else
            throw AppAttestError.assertionFailed
            #endif
        }

        let clientDataHash = Data(SHA256.hash(data: requestData))
        do {
            let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
            return (keyId, assertion)
        } catch {
            Log.attest.error("Assertion generation failed: \(error.localizedDescription, privacy: .private)")
            throw AppAttestError.assertionFailed
        }
    }

    /// テストや問題発生時にキーを破棄して次回再生成させる。
    func resetForTesting() {
        deleteKeyIdFromKeychain()
        cachedKeyId = nil
        hasAttested = false
    }

    // MARK: - Internal Setup

    private func performSetup() async throws {
        // 1. キー未生成なら生成
        if cachedKeyId == nil {
            cachedKeyId = try await generateAndStoreKey()
        }

        // 2. attestation 未済みならサーバーと検証
        if !hasAttested, let keyId = cachedKeyId {
            try await attestKey(keyId: keyId)
            hasAttested = true
        }
    }

    private func generateAndStoreKey() async throws -> String {
        do {
            let keyId = try await service.generateKey()
            try writeKeyIdToKeychain(keyId)
            Log.attest.info("Generated new App Attest key")
            return keyId
        } catch {
            Log.attest.error("Key generation failed: \(error.localizedDescription, privacy: .private)")
            throw AppAttestError.keyGenerationFailed
        }
    }

    private func attestKey(keyId: String) async throws {
        // 1. サーバーから challenge 取得
        let challenge = try await fetchChallenge()
        let challengeHash = Data(SHA256.hash(data: Data(challenge.utf8)))

        // 2. attestation 生成
        let attestation: Data
        do {
            attestation = try await service.attestKey(keyId, clientDataHash: challengeHash)
        } catch {
            Log.attest.error("attestKey failed: \(error.localizedDescription, privacy: .private)")
            throw AppAttestError.attestationFailed
        }

        // 3. サーバーで検証
        try await verifyAttestation(keyId: keyId, attestation: attestation, challenge: challenge)
    }

    // MARK: - Network (bootstrap only)

    private struct ChallengeResponse: Decodable {
        let challenge: String
    }

    private func fetchChallenge() async throws -> String {
        guard let url = URL(string: Self.baseURL + "/v1/attest/challenge") else {
            throw AppAttestError.serverRejected
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await bootstrapSession.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.attest.error("Challenge request failed")
            throw AppAttestError.serverRejected
        }
        let decoded = try JSONDecoder().decode(ChallengeResponse.self, from: data)
        return decoded.challenge
    }

    private func verifyAttestation(keyId: String, attestation: Data, challenge: String) async throws {
        guard let url = URL(string: Self.baseURL + "/v1/attest/verify") else {
            throw AppAttestError.serverRejected
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "key_id": keyId,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await bootstrapSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AppAttestError.serverRejected
        }
        guard (200..<300).contains(http.statusCode) else {
            // 失敗時はキーを破棄して次回再生成
            deleteKeyIdFromKeychain()
            cachedKeyId = nil
            hasAttested = false
            Log.attest.error("Attestation verification rejected: status=\(http.statusCode)")
            throw AppAttestError.serverRejected
        }
    }

    // MARK: - Keychain

    private func readKeyIdFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func writeKeyIdToKeychain(_ keyId: String) throws {
        let data = Data(keyId.utf8)

        // 既存削除
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            Log.attest.error("Keychain write failed: status=\(status)")
            throw AppAttestError.keyGenerationFailed
        }
    }

    private func deleteKeyIdFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum AppAttestError: LocalizedError {
    case unsupported
    case keyGenerationFailed
    case attestationFailed
    case assertionFailed
    case serverRejected

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return String(localized: "このデバイスはApp Attestをサポートしていません")
        case .keyGenerationFailed:
            return String(localized: "認証キーの生成に失敗しました")
        case .attestationFailed:
            return String(localized: "デバイス認証に失敗しました")
        case .assertionFailed:
            return String(localized: "リクエスト署名に失敗しました")
        case .serverRejected:
            return String(localized: "サーバーがデバイス認証を拒否しました")
        }
    }
}
