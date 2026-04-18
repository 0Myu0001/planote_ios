import EventKit

actor CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return (try? await store.requestAccess(to: .event)) ?? false
        }
    }

    func addEvent(from candidate: ExtractionCandidate) -> Bool {
        let event = EKEvent(eventStore: store)
        event.title = candidate.title
        event.notes = candidate.description
        event.location = candidate.location
        event.calendar = store.defaultCalendarForNewEvents

        let tz = TimeZone(identifier: candidate.timezone ?? "Asia/Tokyo") ?? TimeZone(identifier: "Asia/Tokyo")!

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = tz

        if let dateStr = candidate.date, let startStr = candidate.start_time {
            // start_time は "HH:mm:ss" または "HH:mm" の両方に対応
            let normalizedStart = normalizeTime(startStr)
            dateFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            guard let startDate = dateFmt.date(from: "\(dateStr) \(normalizedStart)") else { return false }
            event.startDate = startDate

            if let endStr = candidate.end_time {
                let normalizedEnd = normalizeTime(endStr)
                if let endDate = dateFmt.date(from: "\(dateStr) \(normalizedEnd)") {
                    event.endDate = endDate
                } else {
                    event.endDate = startDate.addingTimeInterval(3600)
                }
            } else {
                event.endDate = startDate.addingTimeInterval(3600)
            }
        } else if let dateStr = candidate.date {
            dateFmt.dateFormat = "yyyy-MM-dd"
            guard let dayDate = dateFmt.date(from: dateStr) else { return false }
            event.startDate = dayDate
            event.endDate = dayDate
            event.isAllDay = true
        } else {
            return false
        }

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            print("CalendarService save error: \(error.localizedDescription)")
            return false
        }
    }

    /// "HH:mm" → "HH:mm:00", "HH:mm:ss" → そのまま
    private func normalizeTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        if parts.count == 2 {
            return "\(time):00"
        }
        return time
    }
}
