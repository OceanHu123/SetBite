import Foundation
import UIKit

@MainActor
final class RecipeExtractionService: ObservableObject {
  @Published var progressMessage = ""
  @Published var isProcessing = false

  private let ocrService = VideoOCRService()
  private let imageOCRService = ImageOCRService()
  private let deepSeekClient = DeepSeekClient()

  func extractRecipe(from videoURL: URL, sourceNote: String, supplementText: String = "") async throws -> Recipe {
    isProcessing = true
    defer { isProcessing = false }

    progressMessage = "正在提取封面…"
    let coverImageData = try? await VideoCoverExtractor.extractCoverData(from: videoURL)

    progressMessage = "正在识别画面文字…"

    let ocrText = try await ocrService.extractText(from: videoURL) { [weak self] progress in
      Task { @MainActor in
        self?.progressMessage = progress.message
      }
    }

    progressMessage = "正在整理食谱…"

    let parsed = try await deepSeekClient.parseRecipe(from: ocrText, supplementText: supplementText)

    return Recipe(
      title: parsed.title.isEmpty ? "未命名食谱" : parsed.title,
      ingredients: parsed.ingredients,
      steps: parsed.steps,
      rawOCRText: ocrText,
      sourceNote: sourceNote,
      coverImageData: coverImageData,
      categories: Self.resolvedCategories(from: parsed)
    )
  }

  func extractRecipe(from text: String, coverImageData: Data?, sourceNote: String = "") async throws -> Recipe {
    isProcessing = true
    defer { isProcessing = false }

    progressMessage = "正在整理食谱…"

    let parsed = try await deepSeekClient.parseRecipeFromText(text)

    return Recipe(
      title: parsed.title.isEmpty ? "未命名食谱" : parsed.title,
      ingredients: parsed.ingredients,
      steps: parsed.steps,
      rawOCRText: text,
      sourceNote: sourceNote,
      coverImageData: coverImageData,
      categories: Self.resolvedCategories(from: parsed)
    )
  }

  func extractRecipe(from images: [UIImage], sourceNote: String = "") async throws -> Recipe {
    isProcessing = true
    defer { isProcessing = false }

    progressMessage = "正在识别图片文字…"
    let ocrText = try await imageOCRService.extractText(from: images) { [weak self] current, total in
      await MainActor.run {
        self?.progressMessage = "正在识别图片文字（\(current)/\(total)）…"
      }
    }

    progressMessage = "正在整理食谱…"
    let parsed = try await deepSeekClient.parseRecipe(from: ocrText)
    let coverData = images.first?.jpegData(compressionQuality: 0.82)

    return Recipe(
      title: parsed.title.isEmpty ? "未命名食谱" : parsed.title,
      ingredients: parsed.ingredients,
      steps: parsed.steps,
      rawOCRText: ocrText,
      sourceNote: sourceNote,
      coverImageData: coverData,
      categories: Self.resolvedCategories(from: parsed)
    )
  }

  private static func resolvedCategories(from parsed: ParsedRecipe) -> [String] {
    let fromAI = parsed.resolvedCategories.filter { RecipeCategoryCatalog.all.contains($0) }
    if !fromAI.isEmpty { return fromAI }
    return RecipeCategoryCatalog.infer(title: parsed.title, ingredients: parsed.ingredients)
  }
}
