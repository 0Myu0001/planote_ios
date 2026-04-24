import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary Blues
    static let planoteBlue = Color("PlanoteBlue", bundle: nil)
    static let planoteBlueLight = Color("PlanoteBlueLight", bundle: nil)
    static let planoteBlueDeep = Color("PlanoteBlueDeep", bundle: nil)

    // Convenience initializers with hex
    static let bluePrimary = Color(light: .init(hex: 0x007AFF), dark: .init(hex: 0x3478F6))
    static let blueLight = Color(light: .init(hex: 0x409CFF), dark: .init(hex: 0x5CA0FF))
    static let blueDeep = Color(light: .init(hex: 0x0055D4), dark: .init(hex: 0x1A56DB))

    // Accents
    static let accentPurple = Color(hex: 0x8B5CF6)
    static let accentTeal = Color(hex: 0x06B6D4)

    // Backgrounds
    static let bgDeep = Color(light: .init(hex: 0xE8F0FE), dark: .init(hex: 0x0A1628))
    static let bgGradientStart = Color(light: .init(hex: 0xC8DBFA), dark: .init(hex: 0x162D55))
    static let bgGradientEnd = Color(light: .init(hex: 0xF0F5FF), dark: .init(hex: 0x091322))

    // Glass
    static let glassBg = Color(light: .white.opacity(0.55), dark: .init(hex: 0xB4D2FF).opacity(0.18))
    static let glassBgStrong = Color(light: .white.opacity(0.72), dark: .init(hex: 0x8CB9FF).opacity(0.28))
    static let glassBorder = Color(light: .white.opacity(0.6), dark: .white.opacity(0.18))
    static let glassBorderStrong = Color(light: .white.opacity(0.8), dark: .white.opacity(0.35))

    // Text
    static let textPrimary = Color(light: .init(hex: 0x1C1C1E), dark: .init(hex: 0xF0F4FF))
    static let textSecondary = Color(light: .init(hex: 0x3C3C43).opacity(0.7), dark: .init(hex: 0xDCE6FF).opacity(0.7))
    static let textTertiary = Color(light: .init(hex: 0x3C3C43).opacity(0.4), dark: .init(hex: 0xC8D7FF).opacity(0.5))
}

// MARK: - Color Helpers

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Adaptive color for light/dark mode
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Background Gradient

struct PlanoteBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.bgGradientStart, .bgDeep, .bgGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient orbs
            Circle()
                .fill(Color.bluePrimary.opacity(colorScheme == .dark ? 0.4 : 0.25))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: -80, y: -300)

            Circle()
                .fill(Color.accentPurple.opacity(colorScheme == .dark ? 0.35 : 0.2))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: 100, y: 200)

            Circle()
                .fill(Color.accentTeal.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .frame(width: 180, height: 180)
                .blur(radius: 80)
                .offset(x: -20, y: 0)
        }
    }
}

// MARK: - Glass Effect Modifier

struct GlassBackgroundLegacy: ViewModifier {
    var strong: Bool = false
    var cornerRadius: CGFloat = 22
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(strong ? Color.glassBgStrong : Color.glassBg)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                strong ? Color.glassBorderStrong : Color.glassBorder,
                                lineWidth: 1
                            )
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(colorScheme == .dark ? 0.3 : 0.6), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: strong ? 20 : 16, y: 8)
            }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 22, strong: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            return self.glassEffect(.regular)
        } else {
            return self.modifier(GlassBackgroundLegacy(strong: strong, cornerRadius: cornerRadius))
        }
    }
}

