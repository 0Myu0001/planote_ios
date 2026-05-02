import SwiftUI

// MARK: - Tab Definition

enum PlanoteTab: String, CaseIterable {
    case home
    case scan

    var titleKey: LocalizedStringKey {
        switch self {
        case .home: return "ホーム"
        case .scan: return "スキャン"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .scan: return "qrcode.viewfinder"
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
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private static let appGroupID = "group.com.planote.app"
    private static let sharedFilePrefix = "shared-"

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    onScan: { selectedTab = .scan },
                    onCalendar: { openDeviceCalendar() },
                    onSettings: { showSettings = true }
                )
                .tabItem {
                    Label(PlanoteTab.home.titleKey, systemImage: PlanoteTab.home.icon)
                }
                .tag(PlanoteTab.home)

                ScanView(
                    onBack: { selectedTab = .home },
                    onScanned: { image in
                        scanItem = ScanImageItem(image: image)
                    }
                )
                .tabItem {
                    Label(PlanoteTab.scan.titleKey, systemImage: PlanoteTab.scan.icon)
                }
                .tag(PlanoteTab.scan)
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
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(onBack: { showSettings = false })
        }
        .fullScreenCover(item: $scanItem) { item in
            ReviewView(
                scannedImage: item.image,
                onBack: {
                    scanItem = nil
                },
                onAdd: { firstDate in
                    scanItem = nil
                    withAnimation { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showToast = false }
                        selectedTab = .home
                        openDeviceCalendar(at: firstDate)
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

    /// デバイスのカレンダーアプリを開く。日付指定があればその日付にジャンプ。
    private func openDeviceCalendar(at date: Date? = nil) {
        let urlString: String
        if let date {
            // calshow:<seconds since 2001-01-01> でその日付の日表示にジャンプ
            urlString = "calshow:\(date.timeIntervalSinceReferenceDate)"
        } else {
            urlString = "calshow://"
        }
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
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
            do {
                try fm.removeItem(at: url)
            } catch {
                Log.share.error("Failed to remove shared file: \(error.localizedDescription, privacy: .private)")
            }
        }

        if let image = picked {
            scanItem = ScanImageItem(image: image)
        }
    }
}


// MARK: - Toast

struct ToastView: View {
    let message: LocalizedStringKey

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
