import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MealCalorieView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \MealMacroLog.createdAt, order: .reverse) private var allLogs: [MealMacroLog]
  @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
  @Query private var dayPlans: [WorkoutDayPlan]
  @Query(sort: \WaterLog.createdAt, order: .reverse) private var waterLogs: [WaterLog]

  @FocusState private var isCaptionFocused: Bool

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var showingCamera = false
  @State private var showingRecipePicker = false
  @State private var pendingImage: UIImage?
  @State private var selectedRecipeTitle: String?
  @State private var caption = ""
  @State private var isAnalyzing = false
  @State private var errorMessage: String?
  @State private var draftEstimate: MealCalorieEstimate?
  @State private var expandedMacro: MacroKind?
  @State private var showingWaterSheet = false

  private var todayLogs: [MealMacroLog] {
    allLogs.filter { Calendar.current.isDateInToday($0.date) }
  }

  private var isTrainingDay: Bool {
    dayPlans.contains { Calendar.current.isDateInToday($0.date) && !$0.exercises.isEmpty }
  }

  private var macroTargets: MacroDailyTargets.Values {
    isTrainingDay ? MacroDailyTargets.trainingDay : MacroDailyTargets.restDay
  }

  private var eatenCarbs: Double { todayLogs.reduce(0) { $0 + $1.carbsG } }
  private var eatenProtein: Double { todayLogs.reduce(0) { $0 + $1.proteinG } }
  private var eatenFat: Double { todayLogs.reduce(0) { $0 + $1.fatG } }
  private var eatenCalories: Double { todayLogs.reduce(0) { $0 + $1.calories } }

  private var calorieProgress: Double {
    eatenCalories / max(macroTargets.calories, 1)
  }

  private var calorieRingProgress: Double {
    min(max(calorieProgress, 0), 1)
  }

  private var todayWaterMl: Int {
    Int(
      waterLogs
        .filter { Calendar.current.isDateInToday($0.createdAt) }
        .reduce(0.0) { $0 + $1.amountMl }
        .rounded()
    )
  }

  private var canAnalyze: Bool {
    let hasText = !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    return (pendingImage != nil || hasText) && !isAnalyzing && AppSettings.hasAPIKey
  }

  private var macroRows: [MacroProgressRow] {
    MacroKind.allCases.map { kind in
      let eaten: Double
      switch kind {
      case .carbs: eaten = eatenCarbs
      case .protein: eaten = eatenProtein
      case .fat: eaten = eatenFat
      }
      let target = max(macroTargets.grams(for: kind), 1)
      return MacroProgressRow(kind: kind, eaten: eaten, target: target)
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        dailyProgressCard
        captureCard
        if let draftEstimate {
          confirmCard(draftEstimate)
        }
        if !todayLogs.isEmpty {
          todayMealsCard
        }
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
    .dismissKeyboardOnTap()
    .keyboardDoneToolbar()
    .appPageBackground()
    .navigationTitle(L10n.calorieLog)
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: selectedPhotoItem) { _, item in
      dismissCaptionKeyboard()
      Task { await loadPhoto(from: item) }
    }
    .fullScreenCover(isPresented: $showingCamera) {
      CameraPicker { image in
        showingCamera = false
        if let image {
          pendingImage = image
          draftEstimate = nil
          errorMessage = nil
        }
      }
      .ignoresSafeArea()
    }
    .sheet(isPresented: $showingRecipePicker) {
      RecipePickSheet(recipes: recipes) { recipe in
        applyRecipe(recipe)
      }
    }
    .sheet(isPresented: $showingWaterSheet) {
      WaterAddSheet()
    }
  }

  private var dailyProgressCard: some View {
    VStack(spacing: 18) {
      HStack(alignment: .firstTextBaseline) {
        Text(L10n.todayCalories)
          .font(.headline)
          .foregroundStyle(AppTheme.accent)
        Spacer()
        Text(macroTargets.dayLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .center, spacing: 16) {
        ZStack {
          Circle()
            .stroke(Color(.systemGray5), lineWidth: 16)
          Circle()
            .trim(from: 0, to: calorieRingProgress)
            .stroke(
              AppTheme.accent,
              style: StrokeStyle(lineWidth: 16, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.35), value: calorieRingProgress)

          VStack(spacing: 4) {
            Text("\(Int(eatenCalories.rounded()))")
              .font(.system(size: 30, weight: .bold, design: .rounded))
              .monospacedDigit()
            Text("/ \(Int(macroTargets.calories)) kcal")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            Text("\(Int((min(calorieProgress, 9.99) * 100).rounded()))%")
              .font(.caption2.weight(.bold))
              .foregroundStyle(AppTheme.accent)
          }
        }
        .frame(width: 176, height: 176)

        WaterVerticalBar(
          todayMl: todayWaterMl,
          targetMl: Int(AppSettings.dailyWaterTargetMl),
          action: { showingWaterSheet = true }
        )
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 14) {
        ForEach(macroRows) { row in
          macroProgressBar(row)
        }
      }
    }
    .padding(18)
    .appCardStyle()
  }

  private func macroProgressBar(_ row: MacroProgressRow) -> some View {
    let isExpanded = expandedMacro == row.kind
    return Button {
      dismissCaptionKeyboard()
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedMacro = isExpanded ? nil : row.kind
      }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(row.kind.title)
            .font(.subheadline.weight(.semibold))
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
          Spacer()
          Text("\(Int(row.eaten.rounded())) / \(Int(row.target.rounded())) g")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          Text("\(Int((min(row.progress, 9.99) * 100).rounded()))%")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(row.kind.chartColor)
            .frame(width: 40, alignment: .trailing)
        }

        GeometryReader { geo in
          let width = max(geo.size.width * min(row.progress, 1), row.eaten > 0 ? 4 : 0)
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color(.systemGray5))
            Capsule()
              .fill(row.kind.chartColor)
              .frame(width: width)
              .animation(.easeInOut(duration: 0.35), value: row.progress)
          }
        }
        .frame(height: 10)

        if isExpanded {
          macroFillHint(for: row)
        }
      }
    }
    .buttonStyle(.plain)
  }

  private func macroFillHint(for row: MacroProgressRow) -> some View {
    let remaining = row.target - row.eaten
    return VStack(alignment: .leading, spacing: 6) {
      if remaining <= 0 {
        Text(L10n.tf("%@ target met.", "%@已达标，不必再补。", row.kind.title))
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text(L10n.tf("Still need %dg %@. About:", "还差 %dg %@，大约吃：", Int(remaining.rounded()), row.kind.title))
          .font(.caption.weight(.semibold))
          .foregroundStyle(row.kind.chartColor)
        ForEach(MacroFillCatalog.foods(for: row.kind)) { food in
          Text("· \(food.line(for: remaining))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(row.kind.chartColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private var captureCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(L10n.logMeal)
        .font(.headline)
        .foregroundStyle(AppTheme.accent)

      if let image = pendingImage {
        ZStack(alignment: .topTrailing) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

          Button {
            pendingImage = nil
            selectedPhotoItem = nil
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title3)
              .symbolRenderingMode(.palette)
              .foregroundStyle(.white, .black.opacity(0.45))
          }
          .padding(10)
        }
      } else {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AppTheme.accentSoft)
          .frame(height: 120)
          .overlay {
            VStack(spacing: 8) {
              Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
              Text(L10n.logMealHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
          }
      }

      if let recipeTitle = selectedRecipeTitle {
        HStack(spacing: 8) {
          Image(systemName: "book.closed.fill")
            .foregroundStyle(AppTheme.accent)
          Text("\(L10n.selectedRecipe)\(recipeTitle)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
          Button(L10n.clear) {
            selectedRecipeTitle = nil
          }
          .font(.caption.weight(.semibold))
        }
      }

      TextField("例如：安慕希 200g + 大米饭 150g", text: $caption, axis: .vertical)
        .lineLimit(2...5)
        .textFieldStyle(.roundedBorder)
        .focused($isCaptionFocused)
        .submitLabel(.done)
        .onSubmit { dismissCaptionKeyboard() }

      Text(L10n.mealHint)
        .font(.caption2)
        .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        Button {
          dismissCaptionKeyboard()
          showingCamera = true
        } label: {
          Label("拍照", systemImage: "camera")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)

        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
          Label("相册", systemImage: "photo")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.accent)
      }

      Button {
        dismissCaptionKeyboard()
        showingRecipePicker = true
      } label: {
        Label("从菜谱选择", systemImage: "book")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(AppTheme.accent)

      Button {
        dismissCaptionKeyboard()
        Task { await analyzeMealInput() }
      } label: {
        if isAnalyzing {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else {
          Label(
            pendingImage == nil ? "按文字估算热量" : "识别本顿热量",
            systemImage: "sparkles"
          )
          .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(AppTheme.accent)
      .disabled(!canAnalyze)

      if !AppSettings.hasAPIKey {
        Text(L10n.addApiKeyFirst)
          .font(.caption)
          .foregroundStyle(.orange)
      }

      if let errorMessage {
        Text(errorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      }
    }
    .padding(18)
    .appCardStyle()
  }

  private func dismissCaptionKeyboard() {
    isCaptionFocused = false
    KeyboardDismiss.dismiss()
  }

  private func applyRecipe(_ recipe: Recipe) {
    selectedRecipeTitle = recipe.title
    draftEstimate = nil
    errorMessage = nil

    var lines: [String] = ["菜名：\(recipe.title)"]
    let ingredients = recipe.ingredientLines
    if !ingredients.isEmpty {
      lines.append("食材：")
      lines.append(contentsOf: ingredients.map { "- \($0)" })
    }
    lines.append("补充：一份家常分量")
    caption = lines.joined(separator: "\n")

    if let data = recipe.coverImageData, let image = UIImage(data: data) {
      pendingImage = image
    }
  }

  private func confirmCard(_ estimate: MealCalorieEstimate) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(L10n.recognitionResult)
        .font(.headline)
        .foregroundStyle(AppTheme.accent)
      Text(estimate.foodName)
        .font(.title3.weight(.semibold))
      HStack(spacing: 12) {
        metricChip("\(Int(estimate.calories)) kcal", color: AppTheme.accent)
        metricChip("碳 \(Int(estimate.carbsG))g", color: MacroKind.carbs.chartColor)
        metricChip("蛋 \(Int(estimate.proteinG))g", color: MacroKind.protein.chartColor)
        metricChip("脂 \(Int(estimate.fatG))g", color: MacroKind.fat.chartColor)
      }
      if estimate.note.contains("包装成分表") {
        Text(L10n.fromNutritionLabel)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(AppTheme.accent)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(AppTheme.accentSoft, in: Capsule())
      }
      if !estimate.note.isEmpty {
        Text(estimate.note)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Button {
        saveEstimate(estimate)
      } label: {
        Label("记入今日", systemImage: "checkmark.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.green)
    }
    .padding(18)
    .appCardStyle()
  }

  private var todayMealsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(L10n.todayLog)
        .font(.headline)
        .foregroundStyle(AppTheme.accent)

      ForEach(todayLogs) { log in
        HStack(spacing: 12) {
          if let data = log.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 52, height: 52)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(AppTheme.accentSoft)
              .frame(width: 52, height: 52)
              .overlay {
                Image(systemName: "fork.knife")
                  .foregroundStyle(AppTheme.accent)
              }
          }

          VStack(alignment: .leading, spacing: 4) {
            Text(log.foodName)
              .font(.subheadline.weight(.semibold))
            Text("\(Int(log.calories)) kcal · \(MacroKind.carbs.shortTitle)\(Int(log.carbsG)) \(MacroKind.protein.shortTitle)\(Int(log.proteinG)) \(MacroKind.fat.shortTitle)\(Int(log.fatG))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding(.vertical, 4)

        if log.id != todayLogs.last?.id {
          Divider()
        }
      }
    }
    .padding(18)
    .appCardStyle()
  }

  private func metricChip(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(color.opacity(0.12), in: Capsule())
  }

  private func loadPhoto(from item: PhotosPickerItem?) async {
    guard let item else { return }
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data) else {
        errorMessage = "无法读取图片"
        return
      }
      pendingImage = image
      draftEstimate = nil
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func analyzeMealInput() async {
    let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
    guard pendingImage != nil || !text.isEmpty else { return }
    isAnalyzing = true
    errorMessage = nil
    defer { isAnalyzing = false }

    do {
      let estimate = try await MealCalorieAnalysisClient().analyzeMeal(
        image: pendingImage,
        caption: caption
      )
      draftEstimate = estimate
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func saveEstimate(_ estimate: MealCalorieEstimate) {
    dismissCaptionKeyboard()
    let thumb = pendingImage?.jpegData(compressionQuality: 0.55)
    let log = MealMacroLog(
      foodName: estimate.foodName,
      calories: estimate.calories,
      carbsG: estimate.carbsG,
      proteinG: estimate.proteinG,
      fatG: estimate.fatG,
      note: estimate.note,
      imageData: thumb
    )
    modelContext.insert(log)
    try? modelContext.save()
    draftEstimate = nil
    pendingImage = nil
    selectedRecipeTitle = nil
    caption = ""
    selectedPhotoItem = nil
  }
}

private struct MacroProgressRow: Identifiable {
  let kind: MacroKind
  let eaten: Double
  let target: Double

  var id: String { kind.id }
  var progress: Double { eaten / max(target, 1) }
}

private struct RecipePickSheet: View {
  @Environment(\.dismiss) private var dismiss
  let recipes: [Recipe]
  let onSelect: (Recipe) -> Void
  @State private var searchText = ""

  private var filtered: [Recipe] {
    let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return recipes }
    return recipes.filter {
      $0.title.localizedCaseInsensitiveContains(q)
        || $0.ingredientNames.contains { $0.localizedCaseInsensitiveContains(q) }
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if recipes.isEmpty {
          ContentUnavailableView(
            "还没有菜谱",
            systemImage: "book.closed",
            description: Text(L10n.noRecipesForPicker)
          )
        } else {
          List(filtered) { recipe in
            Button {
              onSelect(recipe)
              dismiss()
            } label: {
              HStack(spacing: 12) {
                Group {
                  if let data = recipe.coverImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                      .resizable()
                      .scaledToFill()
                  } else {
                    ZStack {
                      AppTheme.accentSoft
                      Image(systemName: "fork.knife")
                        .foregroundStyle(AppTheme.accent)
                    }
                  }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                  Text(recipe.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                  Text(recipe.ingredientLines.prefix(3).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
              }
            }
          }
          .searchable(text: $searchText, prompt: "搜索菜谱")
        }
      }
      .navigationTitle(L10n.pickRecipe)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.cancel) { dismiss() }
        }
      }
    }
  }
}

private struct CameraPicker: UIViewControllerRepresentable {
  let onFinish: (UIImage?) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    picker.delegate = context.coordinator
    picker.allowsEditing = false
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onFinish: onFinish)
  }

  final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let onFinish: (UIImage?) -> Void

    init(onFinish: @escaping (UIImage?) -> Void) {
      self.onFinish = onFinish
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      onFinish(nil)
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      onFinish(info[.originalImage] as? UIImage)
    }
  }
}
