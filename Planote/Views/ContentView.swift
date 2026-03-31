import SwiftUI

// MARK: - Tab Definition

enum PlanoteTab: String, CaseIterable {
    case home = "ホーム"
    case scan = "スキャン"
    case calendar = "カレンダー"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .scan: return "qrcode.viewfinder"
        case .calendar: return "calendar"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var selectedTab: PlanoteTab = .home
    @State private var isReviewPresented = false
    @State private var showToast = false

    var body: some View {
        ZStack {
            PlanoteBackground()

            // Screen content
            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        onScan: { selectedTab = .scan },
                        onCalendar: { selectedTab = .calendar }
                    )
                case .scan:
                    ScanView(
                        onBack: { selectedTab = .home },
                        onScanned: { isReviewPresented = true }
                    )
                case .calendar:
                    CalendarView(onBack: { selectedTab = .home })
                }
            }
            .animation(.easeInOut(duration: 0.35), value: selectedTab)

            // Floating Tab Bar
            if !isReviewPresented {
                VStack {
                    Spacer()
                    FloatingTabBar(selectedTab: $selectedTab)
                        .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Toast
            if showToast {
                VStack {
                    ToastView(message: "✓ カレンダーに追加しました")
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $isReviewPresented) {
            ReviewView(
                onBack: { isReviewPresented = false },
                onAdd: {
                    isReviewPresented = false
                    withAnimation { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showToast = false }
                        selectedTab = .calendar
                    }
                }
            )
        }
    }
}

// MARK: - Floating Tab Bar (Liquid Glass)

struct FloatingTabBar: View {
    @Binding var selectedTab: PlanoteTab
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlanoteTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.bluePrimary : Color.textSecondary)
                    .fontWeight(selectedTab == tab ? .semibold : .medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Color.bluePrimary.opacity(0.15) : Color.clear)
                            .shadow(color: selectedTab == tab ? Color.bluePrimary.opacity(0.15) : .clear, radius: 10)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.glassBgStrong)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.glassBorderStrong, lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(colorScheme == .dark ? 0.25 : 0.5), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 20, y: 8)
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(hex: 0x34C759))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color(hex: 0x34C759).opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: 0x34C759).opacity(0.3), lineWidth: 1)
                    )
            }
    }
}

#Preview {
    ContentView()
}
