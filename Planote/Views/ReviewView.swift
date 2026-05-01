import SwiftUI

// MARK: - Review State

enum ReviewState {
    case loading
    case loaded(noteId: String, items: [ScheduleItem])
    case error(String)
}

struct ReviewView: View {
    let scannedImage: UIImage?
    let onBack: () -> Void
    let onAdd: (Date?) -> Void
    @State private var reviewState: ReviewState = .loading
    @State private var items: [ScheduleItem] = []
    @State private var noteId: String = ""
    @State private var candidates: [ExtractionCandidate] = []
    @State private var calendarResultMessage: String?
    @State private var calendarResultIsError: Bool = false
    @State private var isAdding: Bool = false
    @ObservedObject private var settings = AppSettings.shared
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

                switch reviewState {
                case .loading:
                    loadingView
                case .loaded:
                    loadedView
                case .error(let message):
                    errorView(message: message)
                }
            }
        }
        .overlay(alignment: .top) {
            if let message = calendarResultMessage {
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(
                                calendarResultIsError
                                ? Color(hex: 0xFF3B30)
                                : Color(hex: 0x34C759)
                            )
                    }
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: calendarResultMessage)
        .task {
            await processImage()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Show scanned image thumbnail
            if let image = scannedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.glassBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
            }

            ProgressView()
                .controlSize(.large)
                .tint(.bluePrimary)

            Text("画像を解析中...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Text("手書きメモからスケジュールを抽出しています")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)

            Spacer()
        }
    }

    // MARK: - Loaded View

    private var loadedView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Image preview
                    if let image = scannedImage {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.glassBorder, lineWidth: 1)
                                )

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
                        .frame(maxHeight: 220)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    // Section header
                    SectionHeader(title: "抽出された予定", trailing: "\(selectedCount)件選択中")
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.textTertiary)
                            Text("予定が見つかりませんでした")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
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

                Button(action: { addToDefaultCalendar() }) {
                    HStack(spacing: 8) {
                        if isAdding {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: settings.defaultCalendarProvider.iconName)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(isAdding ? "追加中…" : "カレンダーに追加")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: providerGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: settings.defaultCalendarProvider.accentColor.opacity(0.4), radius: 12, y: 4)
                    }
                }
                .disabled(selectedCount == 0 || isAdding)
                .opacity((selectedCount == 0 || isAdding) ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    private var providerGradient: [Color] {
        switch settings.defaultCalendarProvider {
        case .apple: return [.bluePrimary, .blueDeep]
        case .google: return [Color(hex: 0x4285F4), Color(hex: 0x1A73E8)]
        case .outlook: return [Color(hex: 0x0078D4), Color(hex: 0x004B87)]
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: 0xFF3B30))

            Text("エラーが発生しました")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                reviewState = .loading
                Task { await processImage() }
            }) {
                Text("再試行")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.bluePrimary, .blueDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }

            Button(action: onBack) {
                Text("戻る")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.blueLight)
            }

            Spacer()
        }
    }

    // MARK: - API Calls

    private func processImage() async {
        guard let image = scannedImage else {
            reviewState = .error(String(localized: "画像が選択されていません"))
            return
        }

        do {
            let (noteId, candidates) = try await PlanoteAPIClient.shared.scanAndProcess(image: image)
            let accents: [ScheduleAccent] = [.blue, .purple, .teal]
            let scheduleItems = candidates.enumerated().map { index, candidate in
                ScheduleItem(from: candidate, accent: accents[index % accents.count])
            }

            self.noteId = noteId
            self.items = scheduleItems
            self.candidates = candidates
            self.reviewState = .loaded(noteId: noteId, items: scheduleItems)
        } catch {
            self.reviewState = .error(error.localizedDescription)
        }
    }

    /// 設定で選ばれているデフォルトカレンダーに予定を追加する。
    private func addToDefaultCalendar() {
        let selectedIds = items.filter(\.isSelected).compactMap(\.candidateId)
        guard !selectedIds.isEmpty else {
            onAdd(nil)
            return
        }
        let selectedCandidates = candidates.filter { selectedIds.contains($0.candidate_id) }

        switch settings.defaultCalendarProvider {
        case .apple:
            addToAppleCalendar(selectedCandidates: selectedCandidates, selectedIds: selectedIds)
        case .google:
            addToGoogleCalendar(selectedCandidates: selectedCandidates, selectedIds: selectedIds)
        case .outlook:
            addToOutlook(selectedCandidates: selectedCandidates, selectedIds: selectedIds)
        }
    }

    private func addToAppleCalendar(selectedCandidates: [ExtractionCandidate], selectedIds: [String]) {
        isAdding = true
        Task {
            let granted = await CalendarService.shared.requestAccess()
            var firstAddedDate: Date? = nil
            if granted {
                var successCount = 0
                for candidate in selectedCandidates {
                    if let addedDate = await CalendarService.shared.addEvent(from: candidate) {
                        successCount += 1
                        if firstAddedDate == nil { firstAddedDate = addedDate }
                    }
                }
                let total = selectedCandidates.count
                await MainActor.run {
                    calendarResultIsError = false
                    if successCount == total {
                        calendarResultMessage = String(localized: "\(successCount)件の予定をカレンダーに追加しました")
                    } else {
                        calendarResultMessage = String(localized: "\(total)件中\(successCount)件をカレンダーに追加しました")
                    }
                }
            } else {
                await MainActor.run {
                    calendarResultIsError = true
                    calendarResultMessage = String(localized: "カレンダーへのアクセスが許可されていません")
                }
            }

            do {
                _ = try await PlanoteAPIClient.shared.confirmCandidates(
                    noteId: noteId,
                    candidateIds: selectedIds
                )
            } catch {
                print("Confirm error: \(error.localizedDescription)")
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isAdding = false
                onAdd(firstAddedDate)
            }
        }
    }

    private func addToGoogleCalendar(selectedCandidates: [ExtractionCandidate], selectedIds: [String]) {
        isAdding = true
        Task {
            // 認証 + Calendar スコープ取得
            do {
                try await GoogleCalendarService.shared.signIn()
            } catch {
                await MainActor.run {
                    isAdding = false
                    calendarResultIsError = true
                    calendarResultMessage = error.localizedDescription
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { calendarResultMessage = nil }
                return
            }

            var successCount = 0
            var firstAddedDate: Date? = nil
            var lastError: Error?
            for candidate in selectedCandidates {
                do {
                    let date = try await GoogleCalendarService.shared.addEvent(from: candidate)
                    successCount += 1
                    if firstAddedDate == nil { firstAddedDate = date }
                } catch {
                    lastError = error
                }
            }

            let total = selectedCandidates.count
            await MainActor.run {
                if successCount == total {
                    calendarResultIsError = false
                    calendarResultMessage = String(localized: "Google カレンダーに\(successCount)件追加しました")
                } else if successCount == 0 {
                    calendarResultIsError = true
                    calendarResultMessage = lastError?.localizedDescription
                        ?? String(localized: "Google カレンダーへの追加に失敗しました")
                } else {
                    calendarResultIsError = false
                    calendarResultMessage = String(localized: "Google カレンダーに\(total)件中\(successCount)件追加しました")
                }
            }

            do {
                _ = try await PlanoteAPIClient.shared.confirmCandidates(
                    noteId: noteId,
                    candidateIds: selectedIds
                )
            } catch {
                print("Confirm error: \(error.localizedDescription)")
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isAdding = false
                // Google 成功時はデバイスカレンダーアプリ起動はスキップ（onAdd に nil 渡す）
                onAdd(nil)
            }
        }
    }

    private func addToOutlook(selectedCandidates: [ExtractionCandidate], selectedIds: [String]) {
        isAdding = true
        Task {
            // 認証 + スコープ取得
            do {
                _ = try await MicrosoftCalendarService.shared.signIn()
            } catch {
                await MainActor.run {
                    isAdding = false
                    calendarResultIsError = true
                    calendarResultMessage = error.localizedDescription
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { calendarResultMessage = nil }
                return
            }

            var successCount = 0
            var lastError: Error?
            for candidate in selectedCandidates {
                do {
                    _ = try await MicrosoftCalendarService.shared.addEvent(from: candidate)
                    successCount += 1
                } catch {
                    lastError = error
                }
            }

            let total = selectedCandidates.count
            await MainActor.run {
                if successCount == total {
                    calendarResultIsError = false
                    calendarResultMessage = String(localized: "Outlook に\(successCount)件追加しました")
                } else if successCount == 0 {
                    calendarResultIsError = true
                    calendarResultMessage = lastError?.localizedDescription
                        ?? String(localized: "Outlook への追加に失敗しました")
                } else {
                    calendarResultIsError = false
                    calendarResultMessage = String(localized: "Outlook に\(total)件中\(successCount)件追加しました")
                }
            }

            do {
                _ = try await PlanoteAPIClient.shared.confirmCandidates(
                    noteId: noteId,
                    candidateIds: selectedIds
                )
            } catch {
                print("Confirm error: \(error.localizedDescription)")
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isAdding = false
                onAdd(nil)
            }
        }
    }
}

#Preview {
    ReviewView(scannedImage: nil, onBack: {}, onAdd: { _ in })
}
