import SwiftUI
import EventKit

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

// MARK: - Init from EKEvent

extension ScheduleItem {
    init(from event: EKEvent, accent: ScheduleAccent = .blue) {
        let cal = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "ja_JP")
        timeFmt.dateFormat = "HH:mm"

        let startTime = event.isAllDay ? "" : timeFmt.string(from: event.startDate)
        let hour = cal.component(.hour, from: event.startDate)
        let period = hour < 12 ? "AM" : "PM"

        var detailParts: [String] = []
        if let loc = event.location, !loc.isEmpty { detailParts.append(loc) }
        if event.isAllDay {
            detailParts.append("終日")
        } else {
            let mins = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
            if mins > 0 {
                if mins >= 60 {
                    let h = mins / 60
                    let m = mins % 60
                    detailParts.append(m > 0 ? "\(h)時間\(m)分" : "\(h)時間")
                } else {
                    detailParts.append("\(mins)分")
                }
            }
        }
        let detail = detailParts.isEmpty ? "予定" : detailParts.joined(separator: "・")

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "ja_JP")
        dateFmt.dateFormat = "M/d（E）"
        var fullDateParts: [String] = [dateFmt.string(from: event.startDate)]
        if event.isAllDay {
            fullDateParts.append("終日")
        } else {
            let endTime = timeFmt.string(from: event.endDate)
            fullDateParts.append("\(startTime) – \(endTime)")
        }
        if let loc = event.location, !loc.isEmpty { fullDateParts.append(loc) }

        self.init(
            title: (event.title?.isEmpty == false ? event.title! : "(無題)"),
            detail: detail,
            time: startTime,
            period: period,
            fullDate: fullDateParts.joined(separator: " ・ "),
            accentColor: accent
        )
    }
}
