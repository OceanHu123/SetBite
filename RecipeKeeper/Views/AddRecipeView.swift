import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AddRecipeView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let sharedImport: SharePendingImport?
  let onFinished: () -> Void

  @StateObject private var extractionService = RecipeExtractionService()
  @State private var mode: AddRecipeMode = .text
  @State private var recipeText = ""
  @State private var videoCaptionText = ""
  @State private var selectedVideoItem: PhotosPickerItem?
  @State private var selectedRecipeImageItems: [PhotosPickerItem] = []
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var coverImageData: Data?
  @State private var coverEditorImage: UIImage?
  @State private var showCoverEditor = false
  @State private var sharedVideoURL: URL?
  @State private var errorMessage: String?
  @FocusState private var isTextFocused: Bool

  init(sharedImport: SharePendingImport? = nil, onFinished: @escaping () -> Void = {}) {
    self.sharedImport = sharedImport
    self.onFinished = onFinished
  }

  private var hasVideo: Bool {
    sharedVideoURL != nil || selectedVideoItem != nil
  }

  private var canSubmit: Bool {
    guard AppSettings.hasAPIKey, !extractionService.isProcessing else { return false }
    switch mode {
    case .text:
      return !recipeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .video:
      return hasVideo
    case .image:
      return !selectedRecipeImageItems.isEmpty
    }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Picker("添加方式", selection: $mode) {
          ForEach(AddRecipeMode.allCases, id: \.self) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)

        if mode == .text {
          textInputSection
        } else if mode == .video {
          videoInputSection
        } else {
          imageInputSection
        }

        coverPhotoSection

        if extractionService.isProcessing {
          VStack(spacing: 10) {
            ProgressView()
            Text(extractionService.progressMessage)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
        }

        if !AppSettings.hasAPIKey {
          Text("请先在「其他 → 设置」中填写 API Key")
            .font(.footnote)
            .foregroundStyle(.orange)
        }

        Spacer(minLength: 0)
      }
      .padding(20)
      .appPageBackground()
      .navigationTitle("🎬 新食谱")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            onFinished()
            dismiss()
          }
          .disabled(extractionService.isProcessing)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(mode == .text ? "生成" : "分析") {
            Task { await submit() }
          }
          .fontWeight(.semibold)
          .disabled(!canSubmit)
        }
      }
      .keyboardDoneToolbar()
      .onAppear { applySharedImport() }
      .onChange(of: selectedPhotoItem) { _, item in
        Task { await loadCoverPhoto(from: item) }
      }
      .sheet(isPresented: $showCoverEditor) {
        if let coverEditorImage {
          CoverImageEditorSheet(image: coverEditorImage) { data in
            coverImageData = data
          }
        }
      }
    }
  }

  private var textInputSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("粘贴文字食谱")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.accent)

      ZStack(alignment: .topLeading) {
        TextEditor(text: $recipeText)
          .focused($isTextFocused)
          .frame(minHeight: 220)
          .padding(10)
          .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          .scrollContentBackground(.hidden)

        if recipeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text("粘贴完整食谱，包含食材和步骤…")
            .foregroundStyle(.tertiary)
            .padding(18)
            .allowsHitTesting(false)
        }
      }
    }
  }

  private var videoInputSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
        VStack(spacing: 12) {
          Image(systemName: "video.badge.plus")
            .font(.system(size: 42))
            .foregroundStyle(AppTheme.accent)
          Text(hasVideo ? "已选择视频" : "选择相册视频")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      }
      .disabled(extractionService.isProcessing)

      VStack(alignment: .leading, spacing: 8) {
        Text("帖子文案（可选，建议粘贴）")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.accent)
        Text("小红书等视频的食材用量常在文案里，不在画面中")
          .font(.caption)
          .foregroundStyle(.secondary)
        TextEditor(text: $videoCaptionText)
          .frame(minHeight: 100)
          .padding(10)
          .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          .scrollContentBackground(.hidden)
      }
    }
  }

  private var imageInputSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      PhotosPicker(
        selection: $selectedRecipeImageItems,
        maxSelectionCount: 12,
        matching: .images
      ) {
        VStack(spacing: 12) {
          Image(systemName: "photo.on.rectangle.angled")
            .font(.system(size: 40))
            .foregroundStyle(AppTheme.accent)
          Text(selectedRecipeImageItems.isEmpty ? "选择多张图片" : "已选择 \(selectedRecipeImageItems.count) 张图片")
            .font(.headline)
          Text("会自动识别图片文字并合并整理成食谱")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      }
      .disabled(extractionService.isProcessing)
    }
  }

  private var coverPhotoSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("封面图片（可选）")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.accent)

      HStack(spacing: 12) {
        Group {
          if let coverImageData, let uiImage = UIImage(data: coverImageData) {
            Button {
              coverEditorImage = uiImage
              showCoverEditor = true
            } label: {
              Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(extractionService.isProcessing)
          } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
              VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                  .font(.title2)
                  .foregroundStyle(AppTheme.accent)
                Text("上传图片")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              .frame(width: 88, height: 88)
              .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(extractionService.isProcessing)
          }
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("文字和视频模式都可以上传封面")
            .font(.footnote)
            .foregroundStyle(.secondary)
          if coverImageData != nil {
            HStack(spacing: 12) {
              PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("更换")
                  .font(.footnote)
              }
              .disabled(extractionService.isProcessing)

              Button("编辑") {
                if let coverImageData, let uiImage = UIImage(data: coverImageData) {
                  coverEditorImage = uiImage
                  showCoverEditor = true
                }
              }
              .font(.footnote)
              .disabled(extractionService.isProcessing)

              Button("移除", role: .destructive) {
                coverImageData = nil
                selectedPhotoItem = nil
              }
              .font(.footnote)
            }
          }
        }

        Spacer(minLength: 0)
      }
    }
  }

  private func applySharedImport() {
    guard let sharedImport, sharedImport.kind == .video else { return }
    mode = .video
    sharedVideoURL = ShareImportStore.videoURL(for: sharedImport)
  }

  @MainActor
  private func loadCoverPhoto(from item: PhotosPickerItem?) async {
    guard let item else {
      coverImageData = nil
      return
    }
    do {
      if let data = try await item.loadTransferable(type: Data.self),
         let uiImage = UIImage(data: data) {
        coverEditorImage = uiImage
        showCoverEditor = true
      }
    } catch {
      errorMessage = "无法读取图片"
    }
  }

  private func submit() async {
    errorMessage = nil
    isTextFocused = false

    do {
      let recipe: Recipe
      switch mode {
      case .text:
        recipe = try await extractionService.extractRecipe(
          from: recipeText,
          coverImageData: coverImageData
        )
      case .video:
        let videoURL: URL
        if let sharedVideoURL {
          videoURL = sharedVideoURL
        } else if let selectedVideoItem,
                  let video = try await selectedVideoItem.loadTransferable(type: VideoFile.self) {
          videoURL = video.url
        } else {
          throw RecipeKeeperError.invalidVideo
        }

        let extracted = try await extractionService.extractRecipe(
          from: videoURL,
          sourceNote: "",
          supplementText: videoCaptionText
        )
        if let coverImageData {
          extracted.coverImageData = coverImageData
        }
        recipe = extracted
      case .image:
        let loadedImages = try await loadRecipeImages(from: selectedRecipeImageItems)
        let extracted = try await extractionService.extractRecipe(from: loadedImages)
        if let coverImageData {
          extracted.coverImageData = coverImageData
        }
        recipe = extracted
      }

      modelContext.insert(recipe)
      try modelContext.save()
      onFinished()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadRecipeImages(from items: [PhotosPickerItem]) async throws -> [UIImage] {
    var images: [UIImage] = []
    for item in items {
      if let data = try await item.loadTransferable(type: Data.self),
         let image = UIImage(data: data) {
        images.append(image)
      }
    }
    guard !images.isEmpty else { throw RecipeKeeperError.invalidImage }
    return images
  }
}

private enum AddRecipeMode: CaseIterable {
  case text
  case video
  case image

  var title: String {
    switch self {
    case .text: return "文字"
    case .video: return "视频"
    case .image: return "图片"
    }
  }
}

struct VideoFile: Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .movie) { video in
      SentTransferredFile(video.url)
    } importing: { received in
      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")
      try FileManager.default.copyItem(at: received.file, to: tempURL)
      return Self(url: tempURL)
    }
  }
}
