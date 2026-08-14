import SwiftUI
import UIKit

struct CoverImageEditorSheet: View {
  let image: UIImage
  let onSave: (Data) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var scale: CGFloat = 1
  @State private var lastScale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var cropSize: CGSize = .zero

  private let cropAspect: CGFloat = 4 / 3
  private let minScale: CGFloat = 1
  private let maxScale: CGFloat = 4

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        GeometryReader { geo in
          let size = fittedCropSize(in: geo.size)
          ZStack {
            Color.black.opacity(0.85)
              .ignoresSafeArea()

            ZStack {
              Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
                .offset(offset)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay {
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 2)
            }
            .gesture(dragGesture(cropSize: size))
            .simultaneousGesture(magnificationGesture(cropSize: size))
            .onAppear { cropSize = size }
            .onChange(of: size) { _, newSize in cropSize = newSize }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        VStack(spacing: 8) {
          HStack {
            Image(systemName: "minus.magnifyingglass")
              .foregroundStyle(.secondary)
            Slider(
              value: Binding(
                get: { scale },
                set: { newValue in
                  scale = min(max(newValue, minScale), maxScale)
                  offset = constrainedOffset(offset, scale: scale, cropSize: cropSize)
                  lastScale = scale
                  lastOffset = offset
                }
              ),
              in: minScale...maxScale
            )
            Image(systemName: "plus.magnifyingglass")
              .foregroundStyle(.secondary)
          }

          Text("双指缩放、拖动调整位置")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
      }
      .navigationTitle("编辑封面")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            if let data = CoverImageCropper.exportJPEG(
              from: image,
              scale: scale,
              offset: offset,
              cropSize: cropSize
            ) {
              onSave(data)
            }
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
  }

  private func fittedCropSize(in container: CGSize) -> CGSize {
    let maxWidth = container.width - 32
    let maxHeight = container.height - 16
    var width = maxWidth
    var height = width / cropAspect
    if height > maxHeight {
      height = maxHeight
      width = height * cropAspect
    }
    return CGSize(width: max(width, 1), height: max(height, 1))
  }

  private func magnificationGesture(cropSize: CGSize) -> some Gesture {
    MagnificationGesture()
      .onChanged { value in
        scale = min(max(lastScale * value, minScale), maxScale)
      }
      .onEnded { _ in
        lastScale = scale
        offset = constrainedOffset(offset, scale: scale, cropSize: cropSize)
        lastOffset = offset
      }
  }

  private func dragGesture(cropSize: CGSize) -> some Gesture {
    DragGesture()
      .onChanged { value in
        offset = CGSize(
          width: lastOffset.width + value.translation.width,
          height: lastOffset.height + value.translation.height
        )
      }
      .onEnded { _ in
        offset = constrainedOffset(offset, scale: scale, cropSize: cropSize)
        lastOffset = offset
      }
  }

  private func constrainedOffset(_ offset: CGSize, scale: CGFloat, cropSize: CGSize) -> CGSize {
    guard cropSize.width > 0, cropSize.height > 0 else { return offset }

    let imageSize = image.size
    let fillScale = max(cropSize.width / imageSize.width, cropSize.height / imageSize.height)
    let scaledWidth = imageSize.width * fillScale * scale
    let scaledHeight = imageSize.height * fillScale * scale

    let maxX = max((scaledWidth - cropSize.width) / 2, 0)
    let maxY = max((scaledHeight - cropSize.height) / 2, 0)

    return CGSize(
      width: min(max(offset.width, -maxX), maxX),
      height: min(max(offset.height, -maxY), maxY)
    )
  }
}

enum CoverImageCropper {
  static func exportJPEG(
    from image: UIImage,
    scale: CGFloat,
    offset: CGSize,
    cropSize: CGSize,
    maxPixelWidth: CGFloat = 1200,
    compressionQuality: CGFloat = 0.82
  ) -> Data? {
    guard cropSize.width > 0, cropSize.height > 0 else { return nil }

    let normalized = image.normalizedOrientation()
    let imageSize = normalized.size

    let fillScale = max(cropSize.width / imageSize.width, cropSize.height / imageSize.height)
    let totalScale = fillScale * scale
    let scaledWidth = imageSize.width * totalScale
    let scaledHeight = imageSize.height * totalScale

    let centerX = cropSize.width / 2 + offset.width
    let centerY = cropSize.height / 2 + offset.height
    let imageOriginX = centerX - scaledWidth / 2
    let imageOriginY = centerY - scaledHeight / 2

    var cropRect = CGRect(
      x: -imageOriginX / totalScale,
      y: -imageOriginY / totalScale,
      width: cropSize.width / totalScale,
      height: cropSize.height / totalScale
    )
    cropRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))
    guard cropRect.width > 1, cropRect.height > 1 else { return nil }

    guard let cgImage = normalized.cgImage else { return nil }
    let pixelScale = normalized.scale
    let pixelRect = CGRect(
      x: cropRect.origin.x * pixelScale,
      y: cropRect.origin.y * pixelScale,
      width: cropRect.width * pixelScale,
      height: cropRect.height * pixelScale
    ).integral
    guard let croppedCG = cgImage.cropping(to: pixelRect) else { return nil }
    var result = UIImage(cgImage: croppedCG, scale: 1, orientation: .up)

    if result.size.width > maxPixelWidth {
      let targetHeight = result.size.height * maxPixelWidth / result.size.width
      result = result.resized(to: CGSize(width: maxPixelWidth, height: targetHeight))
    }

    return result.jpegData(compressionQuality: compressionQuality)
  }
}

private extension UIImage {
  func normalizedOrientation() -> UIImage {
    guard imageOrientation != .up else { return self }
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }

  func resized(to size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
