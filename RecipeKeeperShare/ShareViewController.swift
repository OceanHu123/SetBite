import Social
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
  private let statusLabel = UILabel()
  private let spinner = UIActivityIndicatorView(style: .medium)

  override func viewDidLoad() {
    super.viewDidLoad()
    placeholder = "可选备注"
    navigationItem.title = "分享到食谱本"
  }

  override func isContentValid() -> Bool {
    true
  }

  override func didSelectPost() {
    textView.isEditable = false
    navigationItem.rightBarButtonItem?.isEnabled = false
    processSharedItems()
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private func processSharedItems() {
    guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
      finishWithError(ShareImportError.noSupportedContent)
      return
    }

    Task {
      do {
        let note = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await ShareItemProcessor.process(extensionItems: extensionItems, note: note)
        await openMainApp()
        await MainActor.run {
          extensionContext?.completeRequest(returningItems: nil)
        }
        _ = result
      } catch {
        await MainActor.run {
          finishWithError(error)
        }
      }
    }
  }

  private func finishWithError(_ error: Error) {
    let alert = UIAlertController(
      title: "分享失败",
      message: error.localizedDescription,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "好", style: .default) { _ in
      self.extensionContext?.cancelRequest(withError: error)
    })
    present(alert, animated: true)
  }

  @MainActor
  private func openMainApp() async {
    guard let url = URL(string: "recipekeeper://import") else { return }
    _ = await withCheckedContinuation { continuation in
      extensionContext?.open(url) { _ in
        continuation.resume()
      }
    }
  }
}

enum ShareItemProcessor {
  static func process(extensionItems: [NSExtensionItem], note: String) async throws -> SharePendingImport {
    var foundVideoURL: URL?
    var foundLink: String?
    var foundText: String?

    for item in extensionItems {
      guard let attachments = item.attachments else { continue }

      for provider in attachments {
        if foundVideoURL == nil, let videoURL = try await loadVideo(from: provider) {
          foundVideoURL = videoURL
          continue
        }

        if foundLink == nil, let url = try await loadURL(from: provider) {
          foundLink = url.absoluteString
          continue
        }

        if foundText == nil, let text = try await loadText(from: provider) {
          foundText = text
          if foundLink == nil, let url = extractURL(from: text) {
            foundLink = url
          }
        }
      }

      if let title = item.attributedContentText?.string, !title.isEmpty {
        foundText = [foundText, title].compactMap { $0 }.joined(separator: "\n")
        if foundLink == nil, let url = extractURL(from: title) {
          foundLink = url
        }
      }
    }

    let sharedText = [note, foundText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")

    if let videoURL = foundVideoURL {
      let pending = SharePendingImport(
        kind: .video,
        videoFileName: nil,
        linkURL: foundLink,
        sharedText: sharedText.isEmpty ? nil : sharedText,
        createdAt: Date()
      )
      try ShareImportStore.handoffFromExtension(pending: pending, videoSourceURL: videoURL)
      return pending
    }

    if let foundLink {
      let pending = SharePendingImport(
        kind: .link,
        videoFileName: nil,
        linkURL: foundLink,
        sharedText: sharedText.isEmpty ? nil : sharedText,
        createdAt: Date()
      )
      try ShareImportStore.handoffFromExtension(pending: pending, videoSourceURL: nil)
      return pending
    }

    throw ShareImportError.noSupportedContent
  }

  private static func loadVideo(from provider: NSItemProvider) async throws -> URL? {
    let videoTypes = [
      UTType.movie.identifier,
      UTType.video.identifier,
      UTType.mpeg4Movie.identifier,
      UTType.quickTimeMovie.identifier,
      "public.mpeg-4"
    ]

    for type in videoTypes where provider.hasItemConformingToTypeIdentifier(type) {
      if let fileURL = try await loadFileRepresentation(provider: provider, type: type) {
        return fileURL
      }
      if let data = try await loadDataRepresentation(provider: provider, type: type) {
        return try writeTemporaryVideo(data: data, extension: "mp4")
      }
    }
    return nil
  }

  private static func loadURL(from provider: NSItemProvider) async throws -> URL? {
    guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return nil }

    return try await withCheckedThrowingContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        if let url = item as? URL {
          continuation.resume(returning: url)
        } else if let urlString = item as? String, let url = URL(string: urlString) {
          continuation.resume(returning: url)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private static func loadText(from provider: NSItemProvider) async throws -> String? {
    guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { return nil }

    return try await withCheckedThrowingContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        if let text = item as? String, !text.isEmpty {
          continuation.resume(returning: text)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private static func loadFileRepresentation(provider: NSItemProvider, type: String) async throws -> URL? {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let url else {
          continuation.resume(returning: nil)
          return
        }

        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension(url.pathExtension.isEmpty ? "mp4" : url.pathExtension)

        do {
          if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
          }
          try FileManager.default.copyItem(at: url, to: tempURL)
          continuation.resume(returning: tempURL)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private static func loadDataRepresentation(provider: NSItemProvider, type: String) async throws -> Data? {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: data)
      }
    }
  }

  private static func writeTemporaryVideo(data: Data, extension ext: String) throws -> URL {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(ext)
    try data.write(to: tempURL)
    return tempURL
  }

  private static func extractURL(from text: String) -> String? {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let match = detector?.firstMatch(in: text, options: [], range: range)
    guard let match, let url = match.url else { return nil }
    return url.absoluteString
  }
}
