import UIKit

enum PasteboardImportBridge {
  private static let metadataKey = "com.oak.RecipeKeeper.pending"
  private static let videoKey = "com.oak.RecipeKeeper.video"

  static func publish(pending: SharePendingImport, videoSourceURL: URL?) throws {
    var pasteboardItems: [[String: Any]] = []

    let metadata = try JSONEncoder().encode(pending)
    pasteboardItems.append([metadataKey: metadata])

    if let videoSourceURL {
      let videoData = try Data(contentsOf: videoSourceURL)
      pasteboardItems.append([videoKey: videoData])
    }

    UIPasteboard.general.setItems(
      pasteboardItems,
      options: [
        .expirationDate: Date().addingTimeInterval(60 * 10),
        .localOnly: true
      ]
    )
  }

  static func consume() -> SharePendingImport? {
    let items = UIPasteboard.general.items
    guard !items.isEmpty else { return nil }

    var metadata: SharePendingImport?
    var videoData: Data?

    for item in items {
      if let raw = item[metadataKey] as? Data {
        metadata = try? JSONDecoder().decode(SharePendingImport.self, from: raw)
      }
      if let raw = item[videoKey] as? Data {
        videoData = raw
      }
    }

    guard var pending = metadata else { return nil }

    if pending.kind == .video, let videoData {
      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")
      do {
        try videoData.write(to: tempURL)
        pending = SharePendingImport(
          kind: .video,
          videoFileName: tempURL.path,
          linkURL: pending.linkURL,
          sharedText: pending.sharedText,
          createdAt: pending.createdAt
        )
      } catch {
        return nil
      }
    }

    clear()
    return pending
  }

  static func clear() {
    UIPasteboard.general.items = []
  }
}
