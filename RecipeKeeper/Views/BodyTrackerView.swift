import Charts
import SwiftData
import SwiftUI

struct BodyTrackerView: View {
  @State private var section = 0
  @State private var toolbarRoute: BodyToolbarRoute?
  @State private var showingPlanImport = false
  @State private var showingTools = false
  @State private var pendingToolAction: TrainToolAction?

  var body: some View {
    NavigationStack {
      Group {
        if section == 0 {
          WorkoutHomeContent()
        } else {
          BodyRecordsContent()
        }
      }
      .appPageBackground()
      .navigationTitle(section == 0 ? "💪 \(L10n.train)" : "💪 \(L10n.body)")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showingTools = true
          } label: {
            Image(systemName: "ellipsis.circle")
              .foregroundStyle(AppTheme.accent)
          }
          .accessibilityLabel(L10n.more)
        }
      }
      .sheet(isPresented: $showingTools, onDismiss: {
        guard let action = pendingToolAction else { return }
        pendingToolAction = nil
        handleToolAction(action)
      }) {
        TrainToolsSheet(isOnBodySection: section == 1) { action in
          pendingToolAction = action
          showingTools = false
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
      }
      .navigationDestination(item: $toolbarRoute) { route in
        switch route {
        case .exerciseLibrary:
          ExerciseLibraryManageView(embedded: true)
        case .progression:
          ExerciseProgressionView()
        }
      }
      .sheet(isPresented: $showingPlanImport) {
        WorkoutPlanImportSheet()
      }
    }
  }

  private func handleToolAction(_ action: TrainToolAction) {
    switch action {
    case .importPlan:
      showingPlanImport = true
    case .progression:
      toolbarRoute = .progression
    case .bodyRecords:
      section = 1
    case .workoutHome:
      section = 0
    case .exerciseLibrary:
      toolbarRoute = .exerciseLibrary
    }
  }
}

private enum BodyToolbarRoute: Hashable {
  case exerciseLibrary
  case progression
}

private enum TrainToolAction {
  case importPlan
  case progression
  case bodyRecords
  case workoutHome
  case exerciseLibrary
}

private struct TrainToolsSheet: View {
  @Environment(\.dismiss) private var dismiss

  let isOnBodySection: Bool
  let onSelect: (TrainToolAction) -> Void

  var body: some View {
    NavigationStack {
      List {
        Section {
          toolRow(
            title: L10n.importPlan,
            subtitle: L10n.importPlanSubtitle,
            systemImage: "sparkles",
            action: .importPlan
          )
          toolRow(
            title: L10n.progression,
            subtitle: L10n.progressionSubtitle,
            systemImage: "chart.xyaxis.line",
            action: .progression
          )
          if isOnBodySection {
            toolRow(
              title: L10n.workoutPlan,
              subtitle: L10n.workoutPlanSubtitle,
              systemImage: "dumbbell.fill",
              action: .workoutHome
            )
          } else {
            toolRow(
              title: L10n.bodyRecords,
              subtitle: L10n.bodyRecordsSubtitle,
              systemImage: "ruler",
              action: .bodyRecords
            )
          }
          toolRow(
            title: L10n.exerciseLibrary,
            subtitle: L10n.exerciseLibrarySubtitle,
            systemImage: "shippingbox",
            action: .exerciseLibrary
          )
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .appPageBackground()
      .navigationTitle(L10n.trainFeatures)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.close) { dismiss() }
        }
      }
    }
  }

  private func toolRow(
    title: String,
    subtitle: String,
    systemImage: String,
    action: TrainToolAction
  ) -> some View {
    Button {
      onSelect(action)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: systemImage)
          .font(.title3)
          .foregroundStyle(AppTheme.accent)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 4)
    }
  }
}

struct BodyRecordsContent: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \BodyRecord.date, order: .forward) private var records: [BodyRecord]

  @State private var weightText = ""
  @State private var waistText = ""
  @State private var armText = ""
  @State private var heightText = ""
  @State private var weightUnit: WeightUnit = AppSettings.weightUnit
  @State private var analysis: BodyAnalysisResult?
  @State private var isAnalyzing = false
  @State private var errorMessage: String?
  @State private var successMessage: String?
  @State private var selectedMetric: BodyMetric = .weight

  private var recentRecords: [BodyRecord] {
    Array(records.suffix(14))
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        inputCard
        chartCard
        if let analysis {
          analysisCard(analysis)
        }
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
    .keyboardDoneToolbar()
    .onAppear { refreshForm() }
    .onChange(of: records.count) { _, _ in refreshForm() }
  }

  private var inputCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("今日记录")
          .font(.headline)
          .foregroundStyle(AppTheme.accent)
        Spacer()
        Text("共 \(records.count) 天")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let successMessage {
        Text(successMessage)
          .font(.footnote.weight(.medium))
          .foregroundStyle(.green)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      }

      if let errorMessage {
        Text(errorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      }

      HStack(spacing: 12) {
        metricField("身高 cm", text: $heightText)
          .onChange(of: heightText) { _, newValue in
            if let height = DecimalInput.parse(newValue), height > 0 {
              AppSettings.userHeightCm = height
            }
          }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("体重单位")
          .font(.caption)
          .foregroundStyle(.secondary)
        Picker("体重单位", selection: $weightUnit) {
          ForEach(WeightUnit.allCases) { unit in
            Text(unit.label).tag(unit)
          }
        }
        .pickerStyle(.segmented)
        .onChange(of: weightUnit) { _, newValue in
          AppSettings.weightUnit = newValue
          refreshForm()
        }
      }

      HStack(spacing: 12) {
        metricField("体重 \(weightUnit.label)", text: $weightText)
        metricField("腰围 cm", text: $waistText)
        metricField("臂围 cm", text: $armText)
      }

      HStack(spacing: 12) {
        Button {
          saveToday()
        } label: {
          Text("保存今日")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)

        Button {
          Task { await runAnalysis() }
        } label: {
          Group {
            if isAnalyzing {
              ProgressView()
            } else {
              Text("AI 分析")
            }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.accent)
        .disabled(isAnalyzing || records.isEmpty || !AppSettings.hasAPIKey)
      }

      if !AppSettings.hasAPIKey {
        Text("AI 分析需先在「其他 → 设置」填写 API Key")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var chartCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("每日对比")
        .font(.headline)
        .foregroundStyle(AppTheme.accent)

      Picker("指标", selection: $selectedMetric) {
        ForEach(BodyMetric.allCases) { metric in
          Text(metric.title).tag(metric)
        }
      }
      .pickerStyle(.segmented)

      if recentRecords.isEmpty {
        Text("还没有记录，填写上方三项后点「保存今日」")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 160)
      } else {
        Chart(recentRecords, id: \.id) { record in
          let value = selectedMetric.displayValue(from: record, weightUnit: weightUnit)
          BarMark(
            x: .value("日期", record.date, unit: .day),
            y: .value(chartYLabel, value)
          )
          .foregroundStyle(selectedMetric.color.gradient)
          .cornerRadius(6)
          .annotation(position: .top, spacing: 4) {
            Text(formatChartValue(value))
              .font(.caption2.weight(.bold))
              .foregroundStyle(selectedMetric.color)
          }
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day)) { value in
            if let date = value.as(Date.self) {
              AxisValueLabel {
                Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                  .font(.caption2)
              }
            }
          }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 3600 * 24 * 7)
        .frame(height: 220)
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var chartYLabel: String {
    if selectedMetric == .weight {
      return "体重(\(weightUnit.label))"
    }
    return selectedMetric.title
  }

  private func formatChartValue(_ value: Double) -> String {
    String(format: "%.1f", value)
  }

  private func analysisCard(_ result: BodyAnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(result.trend)
          .font(.subheadline.weight(.bold))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(AppTheme.accentSoft, in: Capsule())
        Spacer()
      }

      HStack(spacing: 10) {
        metricBadge(title: "估算体脂", value: result.bodyFatPercent, color: AppTheme.accent)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("离目标还有多远")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.accent)
        Text(result.goalDistance)
          .font(.body)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.accentSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

      VStack(alignment: .leading, spacing: 6) {
        Text("清晰线条参考")
          .font(.subheadline.weight(.semibold))
        Text(result.targetDescription)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Text(result.summary)
        .font(.body)

      Text(result.encouragement)
        .font(.body.weight(.medium))
        .foregroundStyle(AppTheme.accent)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))

      if !result.tips.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("小建议")
            .font(.subheadline.weight(.semibold))
          ForEach(result.tips, id: \.self) { tip in
            Label(tip, systemImage: "sparkles")
              .font(.footnote)
          }
        }
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func metricBadge(title: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
  }

  private func metricField(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField("0", text: text)
        .keyboardType(.decimalPad)
        .padding(10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
  }

  private func refreshForm() {
    if heightText.isEmpty {
      heightText = String(format: "%.0f", AppSettings.userHeightCm)
    }
    guard let record = todayRecord else { return }
    weightText = formatDecimal(weightUnit.fromKilograms(record.weight))
    waistText = formatDecimal(record.waist)
    armText = formatDecimal(record.arm)
  }

  private var todayRecord: BodyRecord? {
    let today = Calendar.current.startOfDay(for: Date())
    return records.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
  }

  private func saveToday() {
    errorMessage = nil
    successMessage = nil
    KeyboardDismiss.dismiss()

    var missing: [String] = []
    let weightInput = DecimalInput.parse(weightText)
    let waist = DecimalInput.parse(waistText)
    let arm = DecimalInput.parse(armText)

    if weightInput == nil || (weightInput ?? 0) <= 0 { missing.append("体重") }
    if waist == nil || (waist ?? 0) <= 0 { missing.append("腰围") }
    if arm == nil || (arm ?? 0) <= 0 { missing.append("臂围") }

    guard missing.isEmpty,
          let weightInput,
          let waist,
          let arm else {
      errorMessage = "请填写：\(missing.joined(separator: "、"))"
      return
    }

    if let height = DecimalInput.parse(heightText), height > 0 {
      AppSettings.userHeightCm = height
    }

    let weightKg = weightUnit.toKilograms(weightInput)
    let today = Calendar.current.startOfDay(for: Date())

    do {
      if let existing = todayRecord {
        existing.weight = weightKg
        existing.waist = waist
        existing.arm = arm
      } else {
        modelContext.insert(BodyRecord(date: today, weight: weightKg, waist: waist, arm: arm))
      }
      try modelContext.save()

      // 验证确实写入
      let verify = FetchDescriptor<BodyRecord>()
      let saved = try modelContext.fetch(verify)
      guard saved.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
        errorMessage = "保存后未读到数据，请重启 App 后再试"
        return
      }

      successMessage = "已保存今日记录（\(saved.count) 天）"
      refreshForm()
    } catch {
      errorMessage = "保存失败：\(error.localizedDescription)"
    }
  }

  private func formatDecimal(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
      return String(format: "%.0f", value)
    }
    return String(format: "%.1f", value)
  }

  private func runAnalysis() async {
    errorMessage = nil
    isAnalyzing = true
    defer { isAnalyzing = false }

    let height = DecimalInput.parse(heightText) ?? AppSettings.userHeightCm

    do {
      analysis = try await BodyAnalysisClient().analyze(records: records, heightCm: height)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

enum BodyMetric: String, CaseIterable, Identifiable {
  case weight
  case waist
  case arm

  var id: String { rawValue }

  var title: String {
    switch self {
    case .weight: return "体重"
    case .waist: return "腰围"
    case .arm: return "臂围"
    }
  }

  var color: Color {
    switch self {
    case .weight: return Color(red: 0.92, green: 0.38, blue: 0.18)
    case .waist: return Color(red: 0.22, green: 0.62, blue: 0.42)
    case .arm: return Color(red: 0.35, green: 0.45, blue: 0.85)
    }
  }

  func displayValue(from record: BodyRecord, weightUnit: WeightUnit) -> Double {
    switch self {
    case .weight: return weightUnit.fromKilograms(record.weight)
    case .waist: return record.waist
    case .arm: return record.arm
    }
  }
}
