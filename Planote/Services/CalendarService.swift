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

        var dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = tz

        if let dateStr = candidate.date, let startStr = candidate.start_time {
            dateFmt.dateFormat = "yyyy-MM-dd HH:mm"
            guard let startDate = dateFmt.date(from: "\(dateStr) \(startStr)") else { return false }
            event.startDate = startDate

            if let endStr = candidate.end_time,
               let endDate = dateFmt.date(from: "\(dateStr) \(endStr)") {
                event.endDate = endDate
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
}
