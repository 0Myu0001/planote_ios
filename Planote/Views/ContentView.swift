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
    @State private var scannedImage: UIImage? = nil

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    onScan: { selectedTab = .scan },
                    onCalendar: { selectedTab = .calendar }
                )
                .tabItem {
                    Label(PlanoteTab.home.rawValue, systemImage: PlanoteTab.home.icon)
                }
                .tag(PlanoteTab.home)

                ScanView(
                    onBack: { selectedTab = .home },
                    onScanned: { image in
                        scannedImage = image
                        DispatchQueue.main.async {
                            isReviewPresented = true
                        }
                    }
                )
                .tabItem {
                    Label(PlanoteTab.scan.rawValue, systemImage: PlanoteTab.scan.icon)
                }
                .tag(PlanoteTab.scan)

                CalendarView(onBack: { selectedTab = .home })
                    .tabItem {
                        Label(PlanoteTab.calendar.rawValue, systemImage: PlanoteTab.calendar.icon)
                    }
                    .tag(PlanoteTab.calendar)
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
                scannedImage: scannedImage,
                onBack: {
                    isReviewPresented = false
                    scannedImage = nil
                },
                onAdd: {
                    isReviewPresented = false
                    scannedImage = nil
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
