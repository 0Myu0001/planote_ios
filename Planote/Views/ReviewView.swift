import SwiftUI

struct ReviewView: View {
    let onBack: () -> Void
    let onAdd: () -> Void
    @State private var items: [ScheduleItem] = ScheduleItem.sampleToday
    @Environment(\.colorScheme) var colorScheme

    private var selectedCount: Int {
        items.filter(\.isSelected).count
    }

    var body: some View {
        ZStack {
            PlanoteBackground()

            VStack(spacing: 0) {
                // Nav Bar
                NavBar(title: "確認", onBack: onBack)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Image preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color.glassBg)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.glassBorder, lineWidth: 1)
                                )

                            // Mock handwriting
                            VStack(spacing: 4) {
                                Text("4/5 10:00 チームMTG 会議室A")
                                Text("4/5 13:30 ランチ 田中さん 駅前カフェ")
                                Text("4/8 17:00 歯医者 佐藤歯科")
                            }
                            .font(.system(size: 14))
                            .italic()
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)

                            // Badge
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("認識完了")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(hex: 0x34C759))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background {
                                            Capsule()
                                                .fill(Color(hex: 0x34C759).opacity(colorScheme == .dark ? 0.15 : 0.1))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color(hex: 0x34C759).opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                }
                                Spacer()
                            }
                            .padding(12)
                        }
                        .frame(height: 180)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // Section header
                        SectionHeader(title: "抽出された予定", trailing: "\(selectedCount)件選択中")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)

                        // Extracted items
                        VStack(spacing: 10) {
                            ForEach(items.indices, id: \.self) { index in
                                ExtractedItemRow(
                                    item: items[index],
                                    isChecked: items[index].isSelected,
                                    onToggle: {
                                        withAnimation(.spring(response: 0.25)) {
                                            items[index].isSelected.toggle()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Text("再スキャン")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().fill(Color.glassBg))
                                    .overlay(Capsule().stroke(Color.glassBorder, lineWidth: 1))
                            }
                    }

                    Button(action: onAdd) {
                        Text("カレンダーに追加")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.bluePrimary, .blueDeep],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.bluePrimary.opacity(0.4), radius: 12, y: 4)
                            }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
    }
}

#Preview {
    ReviewView(onBack: {}, onAdd: {})
}
