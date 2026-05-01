import Foundation
import SwiftUI

/// アプリの永続設定。UserDefaults をバッキングストアにして @AppStorage 互換にする。
enum CalendarProvider: String, CaseIterable, Identifiable {
    case apple
    case google
    case outlook

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .apple: return "Apple カレンダー"
        case .google: return "Google カレンダー"
        case .outlook: return "Microsoft Outlook"
        }
    }

    var iconName: String {
        switch self {
        case .apple: return "calendar"
        case .google: return "g.circle.fill"
        case .outlook: return "envelope.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .apple: return .bluePrimary
        case .google: return Color(hex: 0x4285F4)
        case .outlook: return Color(hex: 0x0078D4)
        }
    }

    /// 現状で利用可能か
    var isAvailable: Bool {
        switch self {
        case .apple, .google, .outlook: return true
        }
    }
}

enum AppSettingsKey {
    static let defaultCalendarProvider = "defaultCalendarProvider"
}

/// 設定をまとめた ObservableObject。SwiftUI 側からは @StateObject / @ObservedObject で利用。
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var defaultCalendarProvider: CalendarProvider {
        didSet {
            UserDefaults.standard.set(
                defaultCalendarProvider.rawValue,
                forKey: AppSettingsKey.defaultCalendarProvider
            )
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKey.defaultCalendarProvider)
        self.defaultCalendarProvider = raw.flatMap(CalendarProvider.init(rawValue:)) ?? .apple
    }
}
