import SwiftUI

struct CalendarView: View {
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    // April 2026: starts on Wednesday (index 3), 30 days
    private let previousMonthDays = [29, 30, 31] // Sun, Mon, Tue
    private let daysInMonth = Array(1...30)
    private let nextMonthDays = [1, 2] // Fri, Sat
    private let eventDays: Set<Int> = [5, 8]

    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: "カレンダー", onBack: onBack)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Month header
                    HStack {
                        Text("2026年 4月")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        HStack(spacing: 8) {
                            MonthNavButton(icon: "chevron.left")
                            MonthNavButton(icon: "chevron.right")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Calendar grid
                    VStack(spacing: 0) {
                        // Weekday header
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                            ForEach(weekdays, id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 8)
                            }
                        }

                        // Days grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                            // Previous month
                            ForEach(previousMonthDays, id: \.self) { day in
                                DayCell(day: day, isOtherMonth: true, isToday: false, hasEvent: false)
                            }
                            // Current month
                            ForEach(daysInMonth, id: \.self) { day in
                                DayCell(day: day, isOtherMonth: false, isToday: false, hasEvent: eventDays.contains(day))
                            }
                            // Next month
                            ForEach(nextMonthDays, id: \.self) { day in
                                DayCell(day: day, isOtherMonth: true, isToday: false, hasEvent: false)
                            }
                        }
                    }
                    .padding(16)
                    .glassBackground()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Upcoming events
                    HStack {
                        Text("予定一覧")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                    VStack(spacing: 10) {
                        ForEach(ScheduleItem.sampleToday) { item in
                            EventRow(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 110) // Tab bar space
            }
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
