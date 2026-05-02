import Foundation
import UIKit
import GoogleSignIn

/// Google Calendar との連携を担当するサービス。
/// - GoogleSignIn でユーザー認証 + Calendar スコープ取得
/// - Calendar v3 REST API を直接叩いて予定を追加
@MainActor
final class GoogleCalendarService {
    static let shared = GoogleCalendarService()

    private let calendarScope = "https://www.googleapis.com/auth/calendar.events"
    private let eventsEndpoint = "https://www.googleapis.com/calendar/v3/calendars/primary/events"

    /// Google Calendar API 専用セッション。`URLSession.shared` は使用しない。
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Sign In

    var isSignedIn: Bool {
        GIDSignIn.sharedInstance.currentUser != nil
    }

    var currentUserEmail: String? {
        GIDSignIn.sharedInstance.currentUser?.profile?.email
    }

    /// サインインし、Calendar スコープを取得する。
    /// 既にサインイン済みでもスコープが付いていなければ追加要求する。
    func signIn() async throws {
        guard let presenter = topViewController() else {
            throw GoogleCalendarError.noPresenter
        }

        // 既存ユーザーがいればスコープ追加、なければ新規サインイン
        if let user = GIDSignIn.sharedInstance.currentUser {
            if hasCalendarScope(user: user) {
                return
            }
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                user.addScopes([calendarScope], presenting: presenter) { _, error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume() }
                }
            }
        } else {
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<GIDSignInResult, Error>) in
                GIDSignIn.sharedInstance.signIn(
                    withPresenting: presenter,
                    hint: nil,
                    additionalScopes: [calendarScope]
                ) { result, error in
                    if let error { cont.resume(throwing: error); return }
                    guard let result else {
                        cont.resume(throwing: GoogleCalendarError.signInFailed); return
                    }
                    cont.resume(returning: result)
                }
            }
            if !hasCalendarScope(user: result.user) {
                // ユーザーがスコープを許可しなかった場合
                throw GoogleCalendarError.scopeNotGranted
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    private func hasCalendarScope(user: GIDGoogleUser) -> Bool {
        user.grantedScopes?.contains(calendarScope) == true
    }

    // MARK: - Add Event

    /// 候補から Google Calendar にイベントを追加。成功時は開始日を返す。
    func addEvent(from candidate: ExtractionCandidate) async throws -> Date {
        try await signIn()

        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleCalendarError.notSignedIn
        }

        // 最新のアクセストークンを取得
        let accessToken = try await freshAccessToken(for: user)

        // 予定リクエストボディを構築
        let (body, startDate) = try makeRequestBody(from: candidate)
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let url = URL(string: eventsEndpoint) else {
            throw GoogleCalendarError.unexpectedResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleCalendarError.unexpectedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GoogleCalendarError.apiError(status: http.statusCode, message: msg)
        }
        return startDate
    }

    private func freshAccessToken(for user: GIDGoogleUser) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            user.refreshTokensIfNeeded { refreshed, error in
                if let error { cont.resume(throwing: error); return }
                let token = (refreshed ?? user).accessToken.tokenString
                cont.resume(returning: token)
            }
        }
    }

    /// candidate から Google Calendar API のリクエスト Body と開始日を作る。
    private func makeRequestBody(from candidate: ExtractionCandidate) throws -> ([String: Any], Date) {
        let tzId = candidate.timezone ?? "Asia/Tokyo"
        let tz = TimeZone(identifier: tzId) ?? TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = tz

        var body: [String: Any] = [
            "summary": candidate.title
        ]
        if let desc = candidate.description, !desc.isEmpty {
            body["description"] = desc
        }
        if let loc = candidate.location, !loc.isEmpty {
            body["location"] = loc
        }

        let startDate: Date

        if let dateStr = candidate.date, let startStr = candidate.start_time {
            let normalizedStart = normalizeTime(startStr)
            dateFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            guard let s = dateFmt.date(from: "\(dateStr) \(normalizedStart)") else {
                throw GoogleCalendarError.invalidDate
            }
            startDate = s

            let endDate: Date
            if let endStr = candidate.end_time,
               let e = dateFmt.date(from: "\(dateStr) \(normalizeTime(endStr))") {
                endDate = e
            } else {
                endDate = s.addingTimeInterval(3600)
            }

            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withInternetDateTime]
            isoFmt.timeZone = tz

            body["start"] = ["dateTime": isoFmt.string(from: startDate), "timeZone": tzId]
            body["end"] = ["dateTime": isoFmt.string(from: endDate), "timeZone": tzId]
        } else if let dateStr = candidate.date {
            // 終日イベント
            dateFmt.dateFormat = "yyyy-MM-dd"
            guard let day = dateFmt.date(from: dateStr) else {
                throw GoogleCalendarError.invalidDate
            }
            startDate = day
            let nextDay = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: day) ?? day
            body["start"] = ["date": dateStr]
            body["end"] = ["date": dateFmt.string(from: nextDay)]
        } else {
            throw GoogleCalendarError.invalidDate
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

enum GoogleCalendarError: LocalizedError {
    case noPresenter
    case signInFailed
    case scopeNotGranted
    case notSignedIn
    case invalidDate
    case unexpectedResponse
    case apiError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noPresenter: return String(localized: "サインイン画面を表示できませんでした")
        case .signInFailed: return String(localized: "Google サインインに失敗しました")
        case .scopeNotGranted: return String(localized: "カレンダーの権限が許可されませんでした")
        case .notSignedIn: return String(localized: "Google アカウントにサインインしていません")
        case .invalidDate: return String(localized: "予定の日付を解析できませんでした")
        case .unexpectedResponse: return String(localized: "予期しないレスポンスを受け取りました")
        case .apiError(let status, let message):
            return String(localized: "Google Calendar API エラー (\(status)): \(message)")
        }
    }
}
