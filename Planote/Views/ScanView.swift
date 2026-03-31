import SwiftUI

struct ScanView: View {
    let onBack: () -> Void
    let onScanned: () -> Void
    @State private var scanLineOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            NavBar(title: "スキャン", onBack: onBack)

            Spacer()

            // Viewfinder
            ZStack {
                // Glass background frame
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
                    .frame(width: 280, height: 380)

                // Corner markers
                ViewfinderCorners()
                    .frame(width: 280, height: 380)

                // Scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.blueLight, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 248, height: 2)
                    .shadow(color: Color.bluePrimary.opacity(0.5), radius: 10)
                    .shadow(color: Color.bluePrimary.opacity(0.3), radius: 30)
                    .offset(y: scanLineOffset)

                // Placeholder content
                VStack(spacing: 12) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.textSecondary.opacity(0.5))
                    Text("手書きメモを撮影してください")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    scanLineOffset = 160
                }
            }

            Spacer()

            // Shutter button
            VStack(spacing: 16) {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onScanned()
                }) {
                    ZStack {
                        // Outer ring
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.bluePrimary.opacity(0.3), Color.bluePrimary.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(Circle().stroke(Color.glassBorderStrong, lineWidth: 3))
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.bluePrimary.opacity(0.2), radius: 15)

                        // Inner circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.bluePrimary, .blueDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.bluePrimary.opacity(0.5), radius: 10)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .buttonStyle(ShutterButtonStyle())

                Text("タップして撮影 / ギャラリーから選択")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.bottom, 40)
        }
        .padding(.bottom, 60) // Space for tab bar
    }
}

// MARK: - Shutter Button Style

struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Viewfinder Corner Markers

struct ViewfinderCorners: View {
    var body: some View {
        ZStack {
            CornerMark().position(x: 16, y: 16)
            CornerMark().rotationEffect(.degrees(90)).position(x: 280 - 16, y: 16)
            CornerMark().rotationEffect(.degrees(-90)).position(x: 16, y: 380 - 16)
            CornerMark().rotationEffect(.degrees(180)).position(x: 280 - 16, y: 380 - 16)
        }
    }
}

struct CornerMark: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 4))
            path.addQuadCurve(to: CGPoint(x: 4, y: 0), control: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.blueLight, lineWidth: 3)
        .frame(width: 32, height: 32)
    }
}

// MARK: - Shared Nav Bar

struct NavBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("戻る")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(Color.blueLight)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

#Preview {
    ZStack {
        PlanoteBackground()
        ScanView(onBack: {}, onScanned: {})
    }
}
