import Foundation
import AuthenticationServices
import UIKit
import Security

// MARK: - Auth Service (Sign in with Apple)

/// Sign in with Apple → サーバー(/v1/auth/apple)で自前 JWT に交換し、
/// access/refresh token を Keychain に永続化する。
@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var userId: String?

    private let tokenStore = TokenStore()
    private let refreshCoordinator = RefreshCoordinator()
    /// Apple Sign-In delegate を生存させておくための参照。
    private var pendingDelegate: AppleSignInDelegate?

    private static var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "PLANOTE_BASE_URL") as? String) ?? ""
    }

    private let bootstrapSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private override init() {
        super.init()
        // 起動時に保存済みトークンを読み込んで状態を復元
        if let saved = tokenStore.read() {
            self.isSignedIn = true
            self.userId = saved.userId
        }
    }

    // MARK: - Sign In

    func signIn() async throws {
        let credential = try await requestAppleCredential()
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.noIdentityToken
        }
        let appleUserId = credential.user

        let response = try await exchangeAppleToken(identityToken: identityToken, userId: appleUserId)

        let stored = StoredTokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in)),
            userId: appleUserId
        )
        tokenStore.write(stored)

        self.userId = appleUserId
        self.isSignedIn = true
        Log.auth.info("Apple sign-in succeeded")
    }

    func signOut() {
        tokenStore.clear()
        self.userId = nil
        self.isSignedIn = false
        Log.auth.info("Signed out")
    }

    /// 期限内の access token を返す。期限切れならリフレッシュ。
    /// 並行呼び出しはアクター内でシリアライズされる。
    func currentAccessToken() async throws -> String {
        guard let tokens = tokenStore.read() else {
            throw AuthError.notSignedIn
        }
        // 60 秒の余裕で期限判定
        if tokens.expiresAt > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }
        return try await refreshCoordinator.refresh { [weak self] in
            guard let self else { throw AuthError.tokenRefreshFailed }
            return try await self.performRefresh(refreshToken: tokens.refreshToken)
        }
    }

    // MARK: - Apple Credential

    private func requestAppleCredential() async throws -> ASAuthorizationAppleIDCredential {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: cont)
            self.pendingDelegate = delegate
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    // MARK: - Server Exchange

    private struct AppleAuthRequest: Encodable {
        let identity_token: String
        let user_id: String
    }

    private struct AuthResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
    }

    private struct RefreshRequest: Encodable {
        let refresh_token: String
    }

    private func exchangeAppleToken(identityToken: String, userId: String) async throws -> AuthResponse {
        guard let url = URL(string: Self.baseURL + "/v1/auth/apple") else {
            throw AuthError.serverRejected(statusCode: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(
            AppleAuthRequest(identity_token: identityToken, user_id: userId)
        )

        let (data, response) = try await bootstrapSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.serverRejected(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            Log.auth.error("Apple token exchange rejected: status=\(http.statusCode)")
            throw AuthError.serverRejected(statusCode: http.statusCode)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    fileprivate func performRefresh(refreshToken: String) async throws -> String {
        guard let url = URL(string: Self.baseURL + "/v1/auth/refresh") else {
            throw AuthError.tokenRefreshFailed
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(RefreshRequest(refresh_token: refreshToken))

        let (data, response) = try await bootstrapSession.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.auth.error("Token refresh failed")
            // リフレッシュ不能ならサインアウト扱い
            tokenStore.clear()
            self.isSignedIn = false
            self.userId = nil
            throw AuthError.tokenRefreshFailed
        }
        let resp = try JSONDecoder().decode(AuthResponse.self, from: data)
        if let existing = tokenStore.read() {
            tokenStore.write(StoredTokens(
                accessToken: resp.access_token,
                refreshToken: resp.refresh_token,
                expiresAt: Date().addingTimeInterval(TimeInterval(resp.expires_in)),
                userId: existing.userId
            ))
        }
        return resp.access_token
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case cancelled
    case noIdentityToken
    case serverRejected(statusCode: Int)
    case notSignedIn
    case tokenRefreshFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return String(localized: "サインインがキャンセルされました")
        case .noIdentityToken:
            return String(localized: "Apple ID トークンが取得できませんでした")
        case .serverRejected(let code):
            return String(localized: "サーバーがサインインを拒否しました (コード: \(code))")
        case .notSignedIn:
            return String(localized: "サインインしていません")
        case .tokenRefreshFailed:
            return String(localized: "セッションの更新に失敗しました。再度サインインしてください")
        }
    }
}

// MARK: - Token Storage (Keychain)

private struct StoredTokens {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String
}

private struct TokenStore {
    private let service = "com.planote.app.auth"
    private let account = "session"

    private struct Encoded: Codable {
        let access_token: String
        let refresh_token: String
        let expires_at: Date
        let user_id: String
    }

    func read() -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(Encoded.self, from: data) else { return nil }
        return StoredTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: decoded.expires_at,
            userId: decoded.user_id
        )
    }

    func write(_ tokens: StoredTokens) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Encoded(
            access_token: tokens.accessToken,
            refresh_token: tokens.refreshToken,
            expires_at: tokens.expiresAt,
            user_id: tokens.userId
        )) else { return }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Log.auth.error("Token Keychain write failed: status=\(status)")
        }
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Refresh Coordinator (並行リフレッシュをシリアライズ)

private actor RefreshCoordinator {
    private var inflight: Task<String, Error>?

    func refresh(_ operation: @Sendable @escaping () async throws -> String) async throws -> String {
        if let inflight {
            return try await inflight.value
        }
        let task = Task<String, Error> { try await operation() }
        inflight = task
        defer { inflight = nil }
        return try await task.value
    }
}

// MARK: - Apple Sign-In Delegate

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    private var didResume = false

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !didResume else { return }
        didResume = true
        if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: cred)
        } else {
            continuation.resume(throwing: AuthError.noIdentityToken)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !didResume else { return }
        didResume = true
        if let err = error as? ASAuthorizationError, err.code == .canceled {
            continuation.resume(throwing: AuthError.cancelled)
        } else {
            continuation.resume(throwing: error)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
