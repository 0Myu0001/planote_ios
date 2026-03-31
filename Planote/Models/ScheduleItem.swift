import SwiftUI

// MARK: - Schedule Item

struct ScheduleItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let time: String
    let period: String
    let fullDate: String
    let accentColor: ScheduleAccent
    var isSelected: Bool = true
}

enum ScheduleAccent {
    case blue, purple, teal

    var gradient: LinearGradient {
        switch self {
        case .blue:
            return LinearGradient(colors: [.bluePrimary, .blueLight], startPoint: .top, endPoint: .bottom)
        case .purple:
            return LinearGradient(colors: [Color(hex: 0x8B5CF6), Color(hex: 0xA78BFA)], startPoint: .top, endPoint: .bottom)
        case .teal:
            return LinearGradient(colors: [Color(hex: 0x06B6D4), Color(hex: 0x67E8F9)], startPoint: .top, endPoint: .bottom)
        }
    }

    var glowColor: Color {
        switch self {
        case .blue: return .bluePrimary.opacity(0.35)
        case .purple: return Color(hex: 0x8B5CF6).opacity(0.35)
        case .teal: return Color(hex: 0x06B6D4).opacity(0.35)
        }
    }

    var dotColor: Color {
        switch self {
        case .blue: return .bluePrimary
        case .purple: return Color(hex: 0x8B5CF6)
        case .teal: return Color(hex: 0x06B6D4)
        }
    }

    var iconBgColor: Color {
        switch self {
        case .blue: return .bluePrimary.opacity(0.15)
        case .purple: return Color(hex: 0x8B5CF6).opacity(0.15)
        case .teal: return Color(hex: 0x06B6D4).opacity(0.15)
        }
    }

    var iconColor: Color {
        switch self {
        case .blue: return .bluePrimary
        case .purple: return Color(hex: 0x8B5CF6)
        case .teal: return Color(hex: 0x06B6D4)
        }
    }
}

// MARK: - Sample Data

extension ScheduleItem {
    static let sampleToday: [ScheduleItem] = [
        ScheduleItem(title: "チームミーティング", detail: "会議室A・60分", time: "10:00", period: "AM",
                     fullDate: "4/5（土）10:00 – 11:00 ・ 会議室A", accentColor: .blue),
        ScheduleItem(title: "ランチ（田中さん）", detail: "駅前カフェ・90分", time: "13:30", period: "PM",
                     fullDate: "4/5（土）13:30 – 15:00 ・ 駅前カフェ", accentColor: .purple),
        ScheduleItem(title: "歯医者", detail: "佐藤歯科・30分", time: "17:00", period: "PM",
                     fullDate: "4/8（火）17:00 – 17:30 ・ 佐藤歯科", accentColor: .teal),
    ]
}
