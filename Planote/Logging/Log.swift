import OSLog

// MARK: - Logger

/// アプリ全体の os.Logger を集約。エラー本文等の外部由来文字列は必ず `privacy: .private` を付ける。
enum Log {
    static let api = Logger(subsystem: "com.planote.app", category: "api")
    static let auth = Logger(subsystem: "com.planote.app", category: "auth")
    static let calendar = Logger(subsystem: "com.planote.app", category: "calendar")
    static let attest = Logger(subsystem: "com.planote.app", category: "attest")
    static let share = Logger(subsystem: "com.planote.app", category: "share")
}
