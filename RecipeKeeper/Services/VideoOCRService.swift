import AVFoundation
import Foundation
import Vision

struct OCRProgress {
  let processedFrames: Int
  let totalFrames: Int
  let message: String
}

actor VideoOCRService {
  func extractText(
    from videoURL: URL,
    onProgress: @escaping @Sendable (OCRProgress) -> Void
  ) async throws -> String {
    let asset = AVURLAsset(url: videoURL)
    let duration = try await asset.load(.duration)
    let durationSeconds = CMTimeGetSeconds(duration)

    guard durationSeconds > 0 else {
      throw RecipeKeeperError.invalidVideo
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1920, height: 1920)

    let interval = samplingInterval(for: durationSeconds)
    let timestamps = stride(from: 0.0, through: durationSeconds, by: interval).map {
      CMTime(seconds: $0, preferredTimescale: 600)
    }

    var collectedLines: [String] = []
    var lastSeenAt: [String: Double] = [:]
    let reshowGap: Double = 4.0

    for (index, time) in timestamps.enumerated() {
      onProgress(
        OCRProgress(
          processedFrames: index + 1,
          totalFrames: timestamps.count,
          message: "正在识别画面文字 \(index + 1)/\(timestamps.count)"
        )
      )

      guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
        continue
      }

      let currentSeconds = CMTimeGetSeconds(time)
      let lines = try await recognizeText(in: cgImage)
      for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isNoiseLine(trimmed) else { continue }
        let normalized = normalize(trimmed)
        guard normalized.count >= 2 else { continue }

        // 同一字幕多帧重复：间隔内只保留一次；间隔足够长后再次出现则保留（前后两次调酱等）
        if let lastTime = lastSeenAt[normalized], currentSeconds - lastTime < reshowGap {
          continue
        }
        lastSeenAt[normalized] = currentSeconds

        let stamp = formatTimestamp(currentSeconds)
        collectedLines.append("[\(stamp)] \(trimmed)")
      }
    }

    let combined = collectedLines.joined(separator: "\n")
    guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw RecipeKeeperError.noTextFound
    }

    return combined
  }

  private func samplingInterval(for duration: Double) -> Double {
    switch duration {
    case ..<60: return 0.5
    case ..<180: return 0.8
    default: return 1.2
    }
  }

  private func isNoiseLine(_ text: String) -> Bool {
    let lower = text.lowercased()
    let noiseKeywords = [
      "小红书", "抖音", "b站", "bilibili", "关注", "点赞", "收藏",
      "她研社", "卫生巾", "mm×", "240mm", "超薄", "棉柔",
      "巨满足", "巨香", "我滴娘", "姐妹们", "能吸", "新换的",
      "百词", "best", "herlab", "学做菜"
    ]
    if noiseKeywords.contains(where: { lower.contains($0) }) { return true }
    if text.count <= 3 && text.rangeOfCharacter(from: .letters) == nil { return true }
    return false
  }

  private func normalize(_ text: String) -> String {
    text
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
  }

  private func formatTimestamp(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    let minutes = total / 60
    let secs = total % 60
    return String(format: "%d:%02d", minutes, secs)
  }

  private func recognizeText(in image: CGImage) async throws -> [String] {
    try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let lines = observations.compactMap { observation -> String? in
          let candidates = observation.topCandidates(3).map(\.string)
          if let withDigit = candidates.first(where: { $0.rangeOfCharacter(from: .decimalDigits) != nil }) {
            return withDigit
          }
          return candidates.first
        }
        continuation.resume(returning: lines)
      }

      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

      let handler = VNImageRequestHandler(cgImage: image, options: [:])
      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
