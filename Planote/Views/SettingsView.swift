import SwiftUI
import GoogleSignIn

struct SettingsView: View {
    let onBack: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @State private var googleEmail: String? = GoogleCalendarService.shared.currentUserEmail
    @State private var microsoftEmail: String? = MicrosoftCalendarService.shared.currentUserEmail
    @State private var isSigningIn = false
    @State private var isSigningInMicrosoft = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PlanoteBackground()

            VStack(spacing: 0) {
                NavBar(title: "設定", onBack: onBack)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        defaultCalendarSection
                        googleAccountSection
                        microsoftAccountSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        Capsule().fill(Color(hex: 0xFF3B30))
                    }
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: errorMessage)
    }

    // MARK: - Default Calendar

    private var defaultCalendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "デフォルトカレンダー", trailing: nil)

            VStack(spacing: 8) {
                ForEach(CalendarProvider.allCases) { provider in
                    providerRow(provider)
                }
            }
            .padding(14)
            .glassBackground()

            Text("スキャンで抽出した予定を追加するときに既定で使うカレンダーです。")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    private func providerRow(_ provider: CalendarProvider) -> some View {
        let isSelected = settings.defaultCalendarProvider == provider
        let available = provider.isAvailable

        return Button {
            guard available else { return }
            withAnimation(.spring(response: 0.25)) {
                settings.defaultCalendarProvider = provider
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(provider.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    if !available {
                        Text("準備中")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.bluePrimary)
                } else if !available {
                    Text("近日対応")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.glassBg))
                        .overlay(Capsule().stroke(Color.glassBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.bluePrimary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.bluePrimary.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            }
            .opacity(available ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!available)
    }

    // MARK: - Google Account

    private var googleAccountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Google アカウント", trailing: nil)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: 0x4285F4))

                    VStack(alignment: .leading, spacing: 2) {
                        if let email = googleEmail {
                            Text("サインイン中")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                            Text(email)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("未サインイン")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)
                            Text("Google カレンダーに予定を追加するためサインインしてください")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()
                }

                if googleEmail == nil {
                    Button(action: { signInGoogle() }) {
                        HStack(spacing: 8) {
                            if isSigningIn {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "g.circle.fill").font(.system(size: 16))
                            }
                            Text(isSigningIn ? "サインイン中…" : "Google でサインイン")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: 0x4285F4), Color(hex: 0x1A73E8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningIn)
                } else {
                    Button(action: { signOutGoogle() }) {
                        Text("サインアウト")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFF3B30))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().fill(Color.glassBg))
                                    .overlay(Capsule().stroke(Color.glassBorder, lineWidth: 1))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .glassBackground()
        }
    }

    // MARK: - Microsoft Account

    private var microsoftAccountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Microsoft アカウント", trailing: nil)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: 0x0078D4))

                    VStack(alignment: .leading, spacing: 2) {
                        if let email = microsoftEmail {
                            Text("サインイン中")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                            Text(email)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("未サインイン")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)
                            Text("Microsoft Outlook に予定を追加するためサインインしてください")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()
                }

                if microsoftEmail == nil {
                    Button(action: { signInMicrosoft() }) {
                        HStack(spacing: 8) {
                            if isSigningInMicrosoft {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Image(systemName: "envelope.circle.fill").font(.system(size: 16))
                            }
                            Text(isSigningInMicrosoft ? "サインイン中…" : "Microsoft でサインイン")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: 0x0078D4), Color(hex: 0x004B87)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningInMicrosoft)
                } else {
                    Button(action: { signOutMicrosoft() }) {
                        Text("サインアウト")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xFF3B30))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().fill(Color.glassBg))
                                    .overlay(Capsule().stroke(Color.glassBorder, lineWidth: 1))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .glassBackground()
        }
    }

    // MARK: - Actions

    private func signInGoogle() {
        isSigningIn = true
        Task {
            do {
                try await GoogleCalendarService.shared.signIn()
                await MainActor.run {
                    googleEmail = GoogleCalendarService.shared.currentUserEmail
                    isSigningIn = false
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { errorMessage = nil }
            }
        }
    }

    private func signOutGoogle() {
        GoogleCalendarService.shared.signOut()
        googleEmail = nil
    }

    private func signInMicrosoft() {
        isSigningInMicrosoft = true
        Task {
            do {
                _ = try await MicrosoftCalendarService.shared.signIn()
                await MainActor.run {
                    microsoftEmail = MicrosoftCalendarService.shared.currentUserEmail
                    isSigningInMicrosoft = false
                }
            } catch {
                await MainActor.run {
                    isSigningInMicrosoft = false
                    errorMessage = error.localizedDescription
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { errorMessage = nil }
            }
        }
    }

    private func signOutMicrosoft() {
        MicrosoftCalendarService.shared.signOut()
        microsoftEmail = nil
    }
}

#Preview {
    SettingsView(onBack: {})
}
