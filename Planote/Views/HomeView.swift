import SwiftUI

struct HomeView: View {
    let onScan: () -> Void
    let onCalendar: () -> Void

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

                    Text("今日の予定は3件です")
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
                SectionHeader(title: "今日の予定", trailing: "すべて表示")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                VStack(spacing: 10) {
                    ForEach(ScheduleItem.sampleToday) { item in
                        ScheduleCard(item: item)
                    }
                }
                .padding(.horizontal, 20)

                // Week Stat
                WeekStatCard(count: 12)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
            }
            .padding(.bottom, 110) // Space for tab bar
        }
    }
}

#Preview {
    ZStack {
        PlanoteBackground()
        HomeView(onScan: {}, onCalendar: {})
    }
}
