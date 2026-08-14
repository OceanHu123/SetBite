import Foundation
import UIKit
import Vision

actor ImageOCRService {
  func extractText(
    from images: [UIImage],
    progress: @escaping (_ current: Int, _ total: Int) async -> Void
  ) async throws -> String {
    guard !images.isEmpty else { throw RecipeKeeperError.invalidImage }

    var sections: [String] = []
    let total = images.count

    for (index, image) in images.enumerated() {
      await progress(index + 1, total)
      let text = try recognizeText(from: image)
      if !text.isEmpty {
        sections.append("【第\(index + 1)张】\n\(text)")
      }
    }

    let merged = sections.joined(separator: "\n\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !merged.isEmpty else { throw RecipeKeeperError.noTextFound }
    return merged
  }

  private func recognizeText(from image: UIImage) throws -> String {
    guard let cgImage = image.cgImage else { return "" }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["zh-Hans", "en-US"]

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    let lines = (request.results ?? [])
      .compactMap { $0.topCandidates(1).first?.string }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return lines.joined(separator: "\n")
  }
}
