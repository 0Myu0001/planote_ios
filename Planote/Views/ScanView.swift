import SwiftUI
import PhotosUI
import UIKit

struct ScanView: View {
    let onBack: () -> Void
    let onScanned: (UIImage) -> Void

    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            NavBar(title: "スキャン", onBack: onBack)

            Spacer()

            // Instructions
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("撮影する準備ができましたか？")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("下のボタンをタップして「カメラで撮影」を選択してください。")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("すでに写真やスクリーンショット、PDFがありますか？")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("下のボタンをタップして「写真を選択」もしくは「ファイルを選択」を選択して、予定が書かれている写真を選択してください。")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Shutter button
            VStack(spacing: 16) {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showActionSheet = true
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

                Text("タップして写真を選択")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.bottom, 40)
        }
        .padding(.bottom, 16)
        .confirmationDialog("写真を追加", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("カメラで撮影") {
                showCamera = true
            }
            Button("写真を選択") {
                showPhotoPicker = true
            }
            Button("ファイルを選択") {
                showFilePicker = true
            }
            Button("キャンセル", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                onScanned(image)
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) {
            guard let item = selectedPhotoItem else { return }
            selectedPhotoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        onScanned(image)
                    }
                }
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { url in
                loadImageFromURL(url)
            }
        }
    }

    private func loadImageFromURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            onScanned(image)
        }
    }
}

// MARK: - Camera Picker (UIImagePickerController)

struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .pdf])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onDocumentPicked(url)
            }
        }
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
    let title: LocalizedStringKey
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
        ScanView(onBack: {}, onScanned: { _ in })
    }
}
