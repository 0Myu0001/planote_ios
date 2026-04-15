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
    var candidateId: String? = nil
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

// MARK: - Init from API Candidate

extension ScheduleItem {
    init(from candidate: ExtractionCandidate, accent: ScheduleAccent = .blue) {
        let time = candidate.start_time ?? ""
        let hour = Int(time.prefix(2)) ?? 0
        let period = hour < 12 ? "AM" : "PM"

        var detailParts: [String] = []
        if let loc = candidate.location { detailParts.append(loc) }
        if let start = candidate.start_time, let end = candidate.end_time {
            let duration = Self.durationString(from: start, to: end)
            if !duration.isEmpty { detailParts.append(duration) }
        }
        let detail = detailParts.isEmpty ? candidate.type : detailParts.joined(separator: "・")

        var fullDateParts: [String] = []
        if let date = candidate.date { fullDateParts.append(date) }
        if let start = candidate.start_time, let end = candidate.end_time {
            fullDateParts.append("\(start) – \(end)")
        } else if let start = candidate.start_time {
            fullDateParts.append(start)
        }
        if let loc = candidate.location { fullDateParts.append(loc) }
        let fullDate = fullDateParts.joined(separator: " ・ ")

        self.init(
            title: candidate.title,
            detail: detail,
            time: time,
            period: period,
            fullDate: fullDate,
            accentColor: accent,
            candidateId: candidate.candidate_id
        )
    }

    private static func durationString(from start: String, to end: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        guard let s = fmt.date(from: start), let e = fmt.date(from: end) else { return "" }
        let mins = Int(e.timeIntervalSince(s) / 60)
        guard mins > 0 else { return "" }
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)時間\(m)分" : "\(h)時間"
        }
        return "\(mins)分"
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
