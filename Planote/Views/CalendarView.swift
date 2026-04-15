import SwiftUI

// MARK: - Calendar View

struct CalendarView: View {
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @State private var visibleMonths: [MonthData] = []
    @State private var showEventList = false
    @State private var visibleMonthIDs: Set<String> = []

    private static let calendar = Calendar.current
    private static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen scrollable calendar
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(visibleMonths) { month in
                        MonthView(month: month)
                            .id(month.id)
                            .onAppear { visibleMonthIDs.insert(month.id) }
                            .onDisappear { visibleMonthIDs.remove(month.id) }
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 100)
            }
            .onAppear { loadInitialMonths() }

            // Status bar blur + floating title
            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)

                    Text("カレンダー")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .frame(height: 44)

                Spacer()
            }

            // Floating event list button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showEventList = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 15, weight: .semibold))
                            Text("予定一覧")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassBackground(strong: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .sheet(isPresented: $showEventList) {
            EventListSheet(months: visibleMonths.filter { visibleMonthIDs.contains($0.id) })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func loadInitialMonths() {
        guard visibleMonths.isEmpty else { return }
        let today = Date()
        var months: [MonthData] = []
        for offset in -12...12 {
            if let date = Self.calendar.date(byAdding: .month, value: offset, to: today) {
                months.append(MonthData.from(date: date))
            }
        }
        visibleMonths = months
    }
}

// MARK: - Month Data

struct MonthData: Identifiable {
    let id: String
    let year: Int
    let month: Int
    let title: String
    let days: [DayData]
    let leadingEmptyCount: Int

    static func from(date: Date) -> MonthData {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        let year = comps.year!
        let month = comps.month!

        let firstOfMonth = cal.date(from: comps)!
        let weekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun
        let leadingEmpty = weekday - 1
        let range = cal.range(of: .day, in: .month, for: firstOfMonth)!

        let today = cal.dateComponents([.year, .month, .day], from: Date())
        let isCurrentMonth = today.year == year && today.month == month
        let todayDay = isCurrentMonth ? today.day! : -1

        let sampleEvents = sampleEventsFor(year: year, month: month)

        let days = range.map { day in
            DayData(
                day: day,
                isToday: day == todayDay,
                events: sampleEvents.filter { $0.day == day }
            )
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        let title = formatter.string(from: firstOfMonth)

        return MonthData(
            id: "\(year)-\(month)",
            year: year,
            month: month,
            title: title,
            days: days,
            leadingEmptyCount: leadingEmpty
        )
    }

    var eventsInMonth: [ScheduleItem] {
        days.flatMap { $0.events.map { $0.item } }
    }

    private static func sampleEventsFor(year: Int, month: Int) -> [(day: Int, item: ScheduleItem)] {
        let cal = Calendar.current
        let today = Date()
        let todayComps = cal.dateComponents([.year, .month, .day], from: today)

        guard todayComps.year == year && todayComps.month == month else { return [] }

        let todayDay = todayComps.day!
        return ScheduleItem.sampleToday.enumerated().map { (index, item) in
            let day = min(todayDay + index * 3, 28)
            return (day: day, item: item)
        }
    }
}

struct DayData {
    let day: Int
    let isToday: Bool
    let events: [(day: Int, item: ScheduleItem)]

    var hasEvent: Bool { !events.isEmpty }
}

// MARK: - Month View

private struct MonthView: View {
    let month: MonthData
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(spacing: 0) {
            // Month title
            HStack {
                Text(month.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)

            // Weekday header
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16)

            // Days grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<month.leadingEmptyCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                ForEach(month.days, id: \.day) { dayData in
                    DayCell(
                        day: dayData.day,
                        isOtherMonth: false,
                        isToday: dayData.isToday,
                        hasEvent: dayData.hasEvent
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()
                .foregroundStyle(Color.glassBorder)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Event List Sheet

struct EventListSheet: View {
    let months: [MonthData]

    private var events: [ScheduleItem] {
        months.sorted(by: { $0.id < $1.id }).flatMap { $0.eventsInMonth }
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text("表示中の期間に予定はありません")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(events) { item in
                                EventRow(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("予定一覧")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let day: Int
    let isOtherMonth: Bool
    let isToday: Bool
    let hasEvent: Bool

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.bluePrimary, .blueDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.bluePrimary.opacity(0.35), radius: 6)
            }

            VStack(spacing: 0) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundStyle(
                        isToday ? .white :
                        isOtherMonth ? Color.textTertiary.opacity(0.4) :
                        Color.textSecondary
                    )

                if hasEvent && !isToday {
                    Circle()
                        .fill(Color.blueLight)
                        .frame(width: 4, height: 4)
                        .offset(y: 1)
                } else {
                    Spacer().frame(height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Month Navigation Button

struct MonthNavButton: View {
    let icon: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.glassBg))
                        .overlay(Circle().stroke(Color.glassBorder, lineWidth: 1))
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        PlanoteBackground()
        CalendarView(onBack: {})
    }
}
