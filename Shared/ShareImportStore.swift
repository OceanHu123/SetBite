import Foundation

struct SharePendingImport: Codable, Equatable {
  enum Kind: String, Codable {
    case video
    case link
  }

  let kind: Kind
  let videoFileName: String?
  let linkURL: String?
  let sharedText: String?
  let createdAt: Date
}

enum ShareImportStore {
  static func handoffFromExtension(pending: SharePendingImport, videoSourceURL: URL?) throws {
    try PasteboardImportBridge.publish(pending: pending, videoSourceURL: videoSourceURL)
  }

  static func loadPendingImport() -> SharePendingImport? {
    PasteboardImportBridge.consume()
  }

  static func videoURL(for pending: SharePendingImport) -> URL? {
    guard pending.kind == .video, let path = pending.videoFileName else { return nil }
    let url = URL(fileURLWithPath: path)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  static func clearPendingImport() {
    PasteboardImportBridge.clear()
  }

  static func defaultSourceNote(for pending: SharePendingImport) -> String {
    if let linkURL = pending.linkURL, !linkURL.isEmpty {
      return linkURL
    }
    if let sharedText = pending.sharedText, !sharedText.isEmpty {
      return sharedText
    }
    return "来自分享"
  }
}

enum ShareImportError: LocalizedError {
  case noSupportedContent
  case videoCopyFailed

  var errorDescription: String? {
    switch self {
    case .noSupportedContent:
      return "未识别到可分享的视频或链接"
    case .videoCopyFailed:
      return "视频保存失败，请重试"
    }
  }
}
