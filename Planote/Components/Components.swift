import SwiftUI

// MARK: - Schedule Card (Home Screen)

struct ScheduleCard: View {
    let item: ScheduleItem

    var body: some View {
        HStack(spacing: 14) {
            // Time badge
            VStack(spacing: 2) {
                Text(item.time)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text(item.period)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .textCase(.uppercase)
            }
            .frame(minWidth: 52)

            // Color divider
            RoundedRectangle(cornerRadius: 2)
                .fill(item.accentColor.gradient)
                .frame(width: 3, height: 40)
                .shadow(color: item.accentColor.glowColor, radius: 4)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(item.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassBackground()
    }
}

// MARK: - Event Row (Calendar Screen)

struct EventRow: View {
    let item: ScheduleItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.accentColor.dotColor)
                .frame(width: 8, height: 8)
                .shadow(color: item.accentColor.glowColor, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(item.fullDate)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassBackground()
    }
}

// MARK: - Extracted Item (Review Screen)

struct ExtractedItemRow: View {
    let item: ScheduleItem
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.accentColor.iconBgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(item.accentColor.iconColor.opacity(0.25), lineWidth: 1)
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: iconName(for: item.accentColor))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(item.accentColor.iconColor)
                }

            // Detail
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(item.fullDate)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Check button
            Button(action: onToggle) {
                Circle()
                    .fill(isChecked ? Color.bluePrimary : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(isChecked ? Color.bluePrimary : Color.glassBorder, lineWidth: 2)
                    )
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: isChecked ? Color.bluePrimary.opacity(0.3) : .clear, radius: 6)
            }
        }
        .padding(16)
        .glassBackground()
    }

    private func iconName(for accent: ScheduleAccent) -> String {
        switch accent {
        case .blue: return "calendar.badge.checkmark"
        case .purple: return "fork.knife"
        case .teal: return "checkmark.circle"
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            isPrimary
                            ? LinearGradient(colors: [.bluePrimary, .blueDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.bluePrimary.opacity(0.15), Color.bluePrimary.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(
                                isPrimary ? Color.white.opacity(0.2) : Color.bluePrimary.opacity(0.25),
                                lineWidth: 1
                            )
                        )
                        .shadow(color: isPrimary ? Color.bluePrimary.opacity(0.4) : .clear, radius: 10)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isPrimary ? .white : Color.bluePrimary)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassBackground()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if let trailing {
                Button(action: { action?() }) {
                    Text(trailing)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.blueLight)
                }
            }
        }
    }
}

// MARK: - Week Stat Card

struct WeekStatCard: View {
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Text("\(count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color.textPrimary, .blueLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("今週の予定")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("先週より2件多いです")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(18)
        .glassBackground()
    }
}
