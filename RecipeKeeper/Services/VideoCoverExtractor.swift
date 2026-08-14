import AVFoundation
import Foundation
import UIKit

enum VideoCoverExtractor {
  static func extractCoverData(from videoURL: URL) async throws -> Data? {
    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 900, height: 900)

    let time = CMTime(seconds: 0.3, preferredTimescale: 600)
    guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
      return nil
    }

    return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.82)
  }
}
