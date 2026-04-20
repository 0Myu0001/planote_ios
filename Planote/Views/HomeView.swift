import SwiftUI

struct HomeView: View {
    let onScan: () -> Void
    let onCalendar: () -> Void

    @State private var isTodayExpanded = true
    @State private var todayEvents: [ScheduleItem] = []
    @State private var weekCount: Int = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("GOOD MORNING")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                        .tracking(0.5)

                    Text("Planote")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.textPrimary, .blueLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("今日の予定は\(todayEvents.count)件です")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Quick Actions
                HStack(spacing: 12) {
                    QuickActionButton(title: "スキャン", icon: "qrcode.viewfinder", isPrimary: true, action: onScan)
                    QuickActionButton(title: "カレンダー", icon: "calendar", isPrimary: false, action: onCalendar)
                    QuickActionButton(title: "設定", icon: "gearshape", isPrimary: false, action: {})
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                // Today's Schedule
                TodayScheduleCard(
                    items: todayEvents,
                    isExpanded: $isTodayExpanded
                )
                .padding(.horizontal, 20)

                // Week Stat
                WeekStatCard(count: weekCount)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
            .padding(.bottom, 16)
        }
        .task {
            await loadEvents()
        }
    }

    private func loadEvents() async {
        let granted = await CalendarService.shared.requestAccess()
        guard granted else { return }

        let cal = Calendar.current
        let now = Date()

        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let today = await CalendarService.shared.fetchEvents(start: todayStart, end: todayEnd)

        let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: todayStart, end: todayEnd)
        let week = await CalendarService.shared.fetchEvents(start: weekInterval.start, end: weekInterval.end)

        self.todayEvents = today.sorted { $0.startDate < $1.startDate }.map { $0.item }
        self.weekCount = week.count
    }
}

#Preview {
    ZStack {
        PlanoteBackground()
        HomeView(onScan: {}, onCalendar: {})
    }
}
