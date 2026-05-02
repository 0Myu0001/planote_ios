import Foundation
import UIKit
import MSAL

/// Microsoft Outlook (Microsoft 365 / Microsoft Graph) との連携を担当するサービス。
/// - MSAL でユーザー認証 + Calendars.ReadWrite スコープ取得
/// - Microsoft Graph v1.0 を直接叩いて予定を追加
@MainActor
final class MicrosoftCalendarService {
    static let shared = MicrosoftCalendarService()

    // Azure App Registration の Application (client) ID
    private let clientId = "0ea91c91-f784-411a-b484-43cea5e03354"
    // 個人 + 組織アカウント両対応のため "common"
    private let authority = "https://login.microsoftonline.com/common"
    private let redirectUri = "msauth.com.planote.app://auth"
    private let scopes = ["https://graph.microsoft.com/Calendars.ReadWrite"]
    private let eventsEndpoint = "https://graph.microsoft.com/v1.0/me/events"

    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?

    /// Microsoft Graph 専用セッション。`URLSession.shared` は使用しない。
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private init() {
        configureApplication()
    }

    private func configureApplication() {
        do {
            guard let authorityURL = URL(string: authority) else {
                Log.calendar.error("Invalid MSAL authority URL")
                return
            }
            let msalAuthority = try MSALAuthority(url: authorityURL)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: redirectUri,
                authority: msalAuthority
            )
            self.application = try MSALPublicClientApplication(configuration: config)

            // 既存のキャッシュからアカウントを復元
            if let app = self.application {
                let accounts = (try? app.allAccounts()) ?? []
                self.currentAccount = accounts.first
            }
        } catch {
            Log.calendar.error("MSAL configure error: \(error.localizedDescription, privacy: .private)")
        }
    }

    // MARK: - Sign In

    var isSignedIn: Bool { currentAccount != nil }

    var currentUserEmail: String? {
        currentAccount?.username
    }

    /// サインインしてアクセストークンを取得する。既にサインイン済みならサイレント取得を試みる。
    @discardableResult
    func signIn() async throws -> String {
        guard let app = application else {
            throw MicrosoftCalendarError.notConfigured
        }

        // 既存アカウントがあればサイレント取得を試行
        if let account = currentAccount {
            do {
                let token = try await acquireTokenSilent(app: app, account: account)
                return token
            } catch {
                // サイレント失敗時は対話的に再取得
                return try await acquireTokenInteractive(app: app)
            }
        } else {
            return try await acquireTokenInteractive(app: app)
        }
    }

    func signOut() {
        guard let app = application, let account = currentAccount else { return }
        try? app.remove(account)
        currentAccount = nil
    }

    private func acquireTokenSilent(
        app: MSALPublicClientApplication,
        account: MSALAccount
    ) async throws -> String {
        let params = MSALSilentTokenParameters(scopes: scopes, account: account)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            app.acquireTokenSilent(with: params) { [weak self] result, error in
                if let error { cont.resume(throwing: error); return }
                guard let result else {
                    cont.resume(throwing: MicrosoftCalendarError.signInFailed); return
                }
                Task { @MainActor in
                    self?.currentAccount = result.account
                }
                cont.resume(returning: result.accessToken)
            }
        }
    }

    private func acquireTokenInteractive(
        app: MSALPublicClientApplication
    ) async throws -> String {
        guard let presenter = topViewController() else {
            throw MicrosoftCalendarError.noPresenter
        }
        let webParams = MSALWebviewParameters(authPresentationViewController: presenter)
        let params = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webParams)
        params.promptType = .selectAccount

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            app.acquireToken(with: params) { [weak self] result, error in
                if let error { cont.resume(throwing: error); return }
                guard let result else {
                    cont.resume(throwing: MicrosoftCalendarError.signInFailed); return
                }
                Task { @MainActor in
                    self?.currentAccount = result.account
                }
                cont.resume(returning: result.accessToken)
            }
        }
    }

    // MARK: - URL handling

    /// PlanoteApp の onOpenURL から呼ぶ。MSAL のリダイレクト URL を処理する。
    /// 戻り値が true なら MSAL が消費した URL（GoogleSignIn 等にチェーンしないでよい）。
    @discardableResult
    static func handleURL(_ url: URL) -> Bool {
        return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    }

    // MARK: - Add Event

    /// candidate から Microsoft Graph に予定を追加。成功時は開始日を返す。
    func addEvent(from candidate: ExtractionCandidate) async throws -> Date {
        let token = try await signIn()
        let (body, startDate) = try makeRequestBody(from: candidate)
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let url = URL(string: eventsEndpoint) else {
            throw MicrosoftCalendarError.unexpectedResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw MicrosoftCalendarError.unexpectedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw MicrosoftCalendarError.apiError(status: http.statusCode, message: msg)
        }
        return startDate
    }

    /// candidate から Microsoft Graph リクエスト Body と開始日を構築。
    private func makeRequestBody(from candidate: ExtractionCandidate) throws -> ([String: Any], Date) {
        let tzId = candidate.timezone ?? "Asia/Tokyo"
        let tz = TimeZone(identifier: tzId) ?? TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = tz

        var body: [String: Any] = [
            "subject": candidate.title
        ]
        if let desc = candidate.description, !desc.isEmpty {
            body["body"] = ["contentType": "text", "content": desc]
        }
        if let loc = candidate.location, !loc.isEmpty {
            body["location"] = ["displayName": loc]
        }

        let startDate: Date

        // Graph では dateTime はタイムゾーンなしの ISO8601 文字列 + 別フィールドで timeZone 指定
        let isoNoTzFmt = DateFormatter()
        isoNoTzFmt.locale = Locale(identifier: "en_US_POSIX")
        isoNoTzFmt.timeZone = tz
        isoNoTzFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let dateStr = candidate.date, let startStr = candidate.start_time {
            let normalizedStart = normalizeTime(startStr)
            dateFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            guard let s = dateFmt.date(from: "\(dateStr) \(normalizedStart)") else {
                throw MicrosoftCalendarError.invalidDate
            }
            startDate = s

            let endDate: Date
            if let endStr = candidate.end_time,
               let e = dateFmt.date(from: "\(dateStr) \(normalizeTime(endStr))") {
                endDate = e
            } else {
                endDate = s.addingTimeInterval(3600)
            }

            body["start"] = ["dateTime": isoNoTzFmt.string(from: startDate), "timeZone": tzId]
            body["end"] = ["dateTime": isoNoTzFmt.string(from: endDate), "timeZone": tzId]
        } else if let dateStr = candidate.date {
            // 終日イベント
            dateFmt.dateFormat = "yyyy-MM-dd"
            guard let day = dateFmt.date(from: dateStr) else {
                throw MicrosoftCalendarError.invalidDate
            }
            startDate = day
            let nextDay = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: day) ?? day
            body["isAllDay"] = true
            body["start"] = ["dateTime": "\(dateStr)T00:00:00", "timeZone": tzId]
            body["end"] = ["dateTime": "\(dateFmt.string(from: nextDay))T00:00:00", "timeZone": tzId]
        } else {
            throw MicrosoftCalendarError.invalidDate
        }

        return (body, startDate)
    }

    private func normalizeTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        if parts.count == 2 { return "\(time):00" }
        return time
    }

    // MARK: - Helpers

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}

enum MicrosoftCalendarError: LocalizedError {
    case notConfigured
    case noPresenter
    case signInFailed
    case invalidDate
    case unexpectedResponse
    case apiError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return String(localized: "Microsoft 認証の初期化に失敗しました")
        case .noPresenter: return String(localized: "サインイン画面を表示できませんでした")
        case .signInFailed: return String(localized: "Microsoft サインインに失敗しました")
        case .invalidDate: return String(localized: "予定の日付を解析できませんでした")
        case .unexpectedResponse: return String(localized: "予期しないレスポンスを受け取りました")
        case .apiError(let status, let message):
            return String(localized: "Microsoft Graph API エラー (\(status)): \(message)")
        }
    }
}
