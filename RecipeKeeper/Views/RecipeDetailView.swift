import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private struct EditableIngredient: Identifiable {
  let id = UUID()
  var name: String
  var amount: String
}

private struct CoverEditorPayload: Identifiable {
  let id = UUID()
  let image: UIImage
}

struct RecipeDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query private var shoppingItems: [ShoppingItem]
  @Bindable var recipe: Recipe

  @State private var toastMessage: String?
  @State private var editingStepIndex: Int?
  @State private var isAddingNewStep = false
  @State private var editingStepText = ""
  @State private var isEditingIngredients = false
  @State private var editableIngredients: [EditableIngredient] = []
  @State private var isEditingCategories = false
  @State private var selectedCategories: Set<String> = []
  @State private var isEditingTitle = false
  @State private var editingTitleText = ""
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var coverEditorPayload: CoverEditorPayload?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        coverSection

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(recipe.title)
              .font(.title.bold())
            Button {
              editingTitleText = recipe.title
              isEditingTitle = true
            } label: {
              Image(systemName: "pencil.circle.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
          }
          HStack(spacing: 12) {
            Label("\(recipe.ingredientNames.count) 种食材", systemImage: "basket.fill")
            Label("\(recipe.steps.count) 步", systemImage: "list.bullet")
          }
          .font(.caption)
          .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            ForEach(recipe.effectiveCategories, id: \.self) { category in
              Text(category)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accentSoft, in: Capsule())
            }
            Button {
              selectedCategories = Set(recipe.effectiveCategories)
              isEditingCategories = true
            } label: {
              Image(systemName: "pencil.circle.fill")
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 16)

        ingredientSection
        stepSection
      }
      .padding(.bottom, 24)
    }
    .background(AppTheme.pageBackground)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(role: .destructive) { deleteRecipe() } label: {
          Image(systemName: "trash")
        }
      }
    }
    .overlay(alignment: .bottom) {
      if let toastMessage {
        ToastBanner(message: toastMessage)
          .padding(.bottom, 24)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeInOut, value: toastMessage)
    .sheet(isPresented: Binding(
      get: { editingStepIndex != nil || isAddingNewStep },
      set: { if !$0 { cancelStepEditing() } }
    )) {
      stepEditorSheet
    }
    .sheet(isPresented: $isEditingIngredients) {
      ingredientEditorSheet
    }
    .sheet(isPresented: $isEditingCategories) {
      categoryEditorSheet
    }
    .sheet(isPresented: $isEditingTitle) {
      titleEditorSheet
    }
    .sheet(item: $coverEditorPayload) { payload in
      CoverImageEditorSheet(image: payload.image) { data in
        saveCoverImage(data)
      }
    }
    .onChange(of: selectedPhotoItem) { _, item in
      Task { await loadCoverPhoto(from: item) }
    }
  }

  private var coverSection: some View {
    ZStack(alignment: .bottom) {
      RecipeCoverImage(data: recipe.coverImageData, height: 240, cornerRadius: 0)

      HStack(spacing: 20) {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
          Label(recipe.coverImageData == nil ? "添加封面" : "更换", systemImage: "photo")
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.22))

        if recipe.coverImageData != nil {
          Button {
            openCoverEditor()
          } label: {
            Label("编辑", systemImage: "crop.rotate")
          }
          .buttonStyle(.borderedProminent)
          .tint(.white.opacity(0.22))

          Button(role: .destructive) {
            removeCoverImage()
          } label: {
            Label("移除", systemImage: "trash")
          }
          .buttonStyle(.borderedProminent)
          .tint(.red.opacity(0.7))
        }
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(.black.opacity(0.45))
    }
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .padding(.horizontal, 16)
  }

  @MainActor
  private func loadCoverPhoto(from item: PhotosPickerItem?) async {
    guard let item else { return }
    do {
      if let data = try await item.loadTransferable(type: Data.self),
         let uiImage = UIImage(data: data) {
        coverEditorPayload = CoverEditorPayload(image: uiImage)
        selectedPhotoItem = nil
      }
    } catch {
      showToast("无法读取图片")
    }
  }

  private func openCoverEditor() {
    guard let data = recipe.coverImageData, let uiImage = UIImage(data: data) else { return }
    coverEditorPayload = CoverEditorPayload(image: uiImage)
  }

  private func saveCoverImage(_ data: Data) {
    recipe.coverImageData = data
    try? modelContext.save()
    selectedPhotoItem = nil
    showToast("封面已更新")
  }

  private func removeCoverImage() {
    recipe.coverImageData = nil
    selectedPhotoItem = nil
    try? modelContext.save()
    showToast("已移除封面")
  }

  private var titleEditorSheet: some View {
    NavigationStack {
      TextField("菜名", text: $editingTitleText)
        .padding(16)
        .navigationTitle("修改菜名")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("取消") { isEditingTitle = false }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("保存") { saveTitle() }
              .disabled(editingTitleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }
    .presentationDetents([.medium])
  }

  private func saveTitle() {
    let trimmed = editingTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    recipe.title = trimmed
    for item in shoppingItems where item.recipeID == recipe.id {
      item.recipeTitle = trimmed
    }
    try? modelContext.save()
    isEditingTitle = false
    showToast("已改为 \(trimmed)")
  }

  private var categoryEditorSheet: some View {
    NavigationStack {
      List {
        ForEach(RecipeCategoryCatalog.all, id: \.self) { category in
          Button {
            toggleCategory(category)
          } label: {
            HStack {
              Text(category)
                .foregroundStyle(.primary)
              Spacer()
              if selectedCategories.contains(category) {
                Image(systemName: "checkmark")
                  .foregroundStyle(AppTheme.accent)
              }
            }
          }
        }
      }
      .navigationTitle("选择标签")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { isEditingCategories = false }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") { saveCategories() }
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func toggleCategory(_ category: String) {
    if selectedCategories.contains(category) {
      selectedCategories.remove(category)
    } else {
      selectedCategories.insert(category)
    }
  }

  private func saveCategories() {
    recipe.categories = RecipeCategoryCatalog.all.filter { selectedCategories.contains($0) }
    try? modelContext.save()
    isEditingCategories = false
    let label = recipe.categories.joined(separator: "、")
    showToast(label.isEmpty ? "已清除标签" : "已改为 \(label)")
  }

  private var stepEditorSheet: some View {
    NavigationStack {
      TextEditor(text: $editingStepText)
        .padding(12)
        .navigationTitle(isAddingNewStep ? "添加步骤" : "编辑步骤")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("取消") { cancelStepEditing() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("保存") { saveEditedStep() }
          }
        }
    }
    .presentationDetents([.medium, .large])
  }

  private var ingredientEditorSheet: some View {
    NavigationStack {
      List {
        ForEach($editableIngredients) { $item in
          HStack(spacing: 10) {
            TextField("食材名", text: $item.name)
            TextField("用量", text: $item.amount)
              .frame(width: 90)
          }
        }
        .onDelete { indexSet in
          editableIngredients.remove(atOffsets: indexSet)
        }

        Button {
          editableIngredients.append(EditableIngredient(name: "", amount: ""))
        } label: {
          Label("添加食材", systemImage: "plus.circle.fill")
        }
      }
      .navigationTitle("编辑食材")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { isEditingIngredients = false }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") { saveIngredients() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var ingredientSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionHeader("食材", icon: "basket.fill")
        Spacer()
        Button {
          beginEditingIngredients()
        } label: {
          Image(systemName: "pencil.circle.fill")
            .foregroundStyle(AppTheme.accent)
        }
      }
      .padding(.horizontal, 16)

      if recipe.parsedIngredients.isEmpty {
        Text("暂无食材")
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(recipe.parsedIngredients.enumerated()), id: \.offset) { index, item in
            HStack {
              Text(item.name)
                .font(.body.weight(.medium))
              Spacer()
              Text(item.amount.isEmpty ? "适量" : item.amount)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if index < recipe.parsedIngredients.count - 1 {
              Divider().padding(.leading, 16)
            }
          }
        }
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
      }
    }
  }

  private var stepSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionHeader("步骤", icon: "list.number")
        Spacer()
        Button {
          isAddingNewStep = true
          editingStepText = ""
        } label: {
          Image(systemName: "plus.circle.fill")
            .foregroundStyle(AppTheme.accent)
        }
      }
      .padding(.horizontal, 16)

      if recipe.steps.isEmpty {
        Text("暂无步骤")
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
      } else {
        VStack(spacing: 12) {
          ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 12) {
              Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(AppTheme.accent, in: Circle())
              Text(step)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
            }
            .padding(14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contextMenu {
              Button("编辑") { beginEditingStep(at: index) }
              if index > 0 {
                Button("上移") { moveStep(from: index, to: index - 1) }
              }
              if index < recipe.steps.count - 1 {
                Button("下移") { moveStep(from: index, to: index + 1) }
              }
              Button("删除", role: .destructive) { deleteStep(at: index) }
            }
          }
        }
        .padding(.horizontal, 16)
      }
    }
  }

  private func beginEditingIngredients() {
    editableIngredients = recipe.parsedIngredients.map {
      EditableIngredient(name: $0.name, amount: $0.amount)
    }
    isEditingIngredients = true
  }

  private func saveIngredients() {
    let cleaned = editableIngredients
      .map {
        (
          name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
          amount: $0.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        )
      }
      .filter { !$0.name.isEmpty }

    recipe.ingredientNames = cleaned.map(\.name)
    recipe.ingredientAmounts = cleaned.map(\.amount)
    try? modelContext.save()
    isEditingIngredients = false
  }

  private func beginEditingStep(at index: Int) {
    isAddingNewStep = false
    editingStepIndex = index
    editingStepText = recipe.steps[index]
  }

  private func cancelStepEditing() {
    editingStepIndex = nil
    isAddingNewStep = false
    editingStepText = ""
  }

  private func saveEditedStep() {
    let trimmed = editingStepText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    var steps = recipe.steps
    if isAddingNewStep {
      steps.append(trimmed)
    } else if let index = editingStepIndex, index < steps.count {
      steps[index] = trimmed
    }
    recipe.steps = steps
    try? modelContext.save()
    cancelStepEditing()
  }

  private func moveStep(from source: Int, to destination: Int) {
    var steps = recipe.steps
    guard source >= 0, source < steps.count,
          destination >= 0, destination < steps.count,
          source != destination else { return }
    let item = steps.remove(at: source)
    steps.insert(item, at: destination)
    recipe.steps = steps
    try? modelContext.save()
  }

  private func deleteStep(at index: Int) {
    var steps = recipe.steps
    guard index < steps.count else { return }
    steps.remove(at: index)
    recipe.steps = steps
    try? modelContext.save()
  }

  private func sectionHeader(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
      .font(.headline)
      .foregroundStyle(AppTheme.accent)
  }

  private func showToast(_ message: String) {
    toastMessage = message
    Task {
      try? await Task.sleep(for: .seconds(2.2))
      await MainActor.run { toastMessage = nil }
    }
  }

  private func deleteRecipe() {
    RecipeShoppingHelper.deleteShoppingItems(
      for: recipe.id,
      in: shoppingItems,
      context: modelContext
    )
    CookingStore.deleteLogs(for: recipe.id, in: modelContext)
    modelContext.delete(recipe)
    try? modelContext.save()
    dismiss()
  }
}
