import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {

    private static let appGroupID = "group.com.planote.app"
    private static let urlScheme = "planote"

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = NSLocalizedString("Scanote AIに送信中…", comment: "")
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .label
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            await fail()
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if let data = await loadImageData(from: provider) {
                    if let id = saveToSharedContainer(data: data) {
                        await open(id: id)
                        return
                    }
                }
            }
        }
        await fail()
    }

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        let types = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.heic.identifier,
        ]
        for type in types where provider.hasItemConformingToTypeIdentifier(type) {
            if let data = await loadItemData(provider: provider, type: type) {
                return data
            }
        }
        return nil
    }

    private func loadItemData(provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { value, _ in
                if let data = value as? Data {
                    continuation.resume(returning: data)
                    return
                }
                if let url = value as? URL, let data = try? Data(contentsOf: url) {
                    continuation.resume(returning: data)
                    return
                }
                if let image = value as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                    continuation.resume(returning: data)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private func saveToSharedContainer(data: Data) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) else { return nil }
        let id = UUID().uuidString
        let fileURL = containerURL.appendingPathComponent("shared-\(id).jpg")
        do {
            try data.write(to: fileURL, options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    @MainActor
    private func open(id: String) async {
        guard let url = URL(string: "\(Self.urlScheme)://scan?id=\(id)") else {
            await fail()
            return
        }

        guard let extensionContext else {
            await fail()
            return
        }

        extensionContext.completeRequest(returningItems: nil) { [weak self] _ in
            if Thread.isMainThread {
                self?.launchHostApp(url: url)
            } else {
                DispatchQueue.main.async {
                    self?.launchHostApp(url: url)
                }
            }
        }
    }

    @MainActor
    private func fail() async {
        statusLabel.text = NSLocalizedString("送信できませんでした", comment: "")
        activityIndicator.stopAnimating()
        try? await Task.sleep(nanoseconds: 800_000_000)
        extensionContext?.cancelRequest(withError: NSError(domain: "PlanoteShare", code: -1))
    }

    /// Share Extension の完了後に responder chain を遡って `openURL:` に応答する
    /// 最初の responder を探し、host app を起動する。
    private func launchHostApp(url: URL) {
        let selector = NSSelectorFromString("openURL:")
        let startingResponders: [UIResponder?] = [self, view, view.window]
        var visited = Set<ObjectIdentifier>()

        for start in startingResponders {
            var responder = start
            while let current = responder {
                let id = ObjectIdentifier(current)
                guard !visited.contains(id) else { break }
                visited.insert(id)

                if current.responds(to: selector) {
                    _ = current.perform(selector, with: url)
                    return
                }
                responder = current.next
            }
        }
    }
}
