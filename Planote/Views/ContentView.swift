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

struct ScanImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ContentView: View {
    @State private var selectedTab: PlanoteTab = .home
    @State private var showToast = false
    @State private var scanItem: ScanImageItem? = nil
    @Environment(\.scenePhase) private var scenePhase

    private static let appGroupID = "group.com.planote.app"
    private static let sharedFilePrefix = "shared-"

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
                        scanItem = ScanImageItem(image: image)
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
        .fullScreenCover(item: $scanItem) { item in
            ReviewView(
                scannedImage: item.image,
                onBack: {
                    scanItem = nil
                },
                onAdd: {
                    scanItem = nil
                    withAnimation { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showToast = false }
                        selectedTab = .calendar
                    }
                }
            )
        }
        .onOpenURL { _ in
            consumePendingShare()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumePendingShare()
            }
        }
        .task {
            consumePendingShare()
        }
    }

    /// Share Extension が App Group に書き込んだ画像があれば、最新の1件を取り出して
    /// ReviewView を起動し、ファイルは消費する。URL スキーム経由でも手動起動でも同じ入口。
    private func consumePendingShare() {
        guard scanItem == nil else { return }
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) else { return }

        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.creationDateKey]
        guard let contents = try? fm.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: resourceKeys
        ) else { return }

        let sharedFiles = contents.filter { $0.lastPathComponent.hasPrefix(Self.sharedFilePrefix) }
        guard !sharedFiles.isEmpty else { return }

        let sorted = sharedFiles.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: Set(resourceKeys)).creationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: Set(resourceKeys)).creationDate) ?? .distantPast
            return l > r
        }

        var picked: UIImage?
        for url in sorted {
            if picked == nil,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                picked = image
            }
            try? fm.removeItem(at: url)
        }

        if let image = picked {
            scanItem = ScanImageItem(image: image)
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
