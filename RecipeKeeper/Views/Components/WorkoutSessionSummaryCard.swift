import SwiftUI

struct WorkoutSessionSummaryCard: View {
  let summary: WorkoutSessionSummaryData
  var aiText: String?
  var showCelebration: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      headerRow
      HStack(alignment: .top, spacing: 8) {
        BodyMuscleDiagramView(highlights: summary.muscleHighlights)
          .frame(maxWidth: .infinity)
          .layoutPriority(1)
        metricsColumn
      }

      if let aiText, !aiText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Label("AI 复盘", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
          Text(aiText)
            .font(.footnote)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var headerRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      if showCelebration {
        Text("🎉 今日训练已完成")
          .font(.headline)
          .foregroundStyle(AppTheme.accent)
      } else {
        Text("训练复盘")
          .font(.headline)
          .foregroundStyle(AppTheme.accent)
      }
      Text(summary.date.formatted(.dateTime.month(.wide).day().weekday(.wide)))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var metricsColumn: some View {
    VStack(alignment: .leading, spacing: 14) {
      metricBlock(value: summary.caloriesLabel, title: "消耗 (大卡)")
      metricBlock(value: summary.capacityLabel, title: "总容量 (kg)")
      metricBlock(value: summary.durationLabel, title: "总耗时")
    }
    .frame(width: 108, alignment: .leading)
  }

  private func metricBlock(value: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value)
        .font(.title2.weight(.bold))
        .foregroundStyle(.primary)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

struct WorkoutDayCompletionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @Bindable var dayPlan: WorkoutDayPlan
  let summary: WorkoutSessionSummaryData

  @State private var aiText: String?
  @State private var isLoadingAI = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          WorkoutSessionSummaryCard(
            summary: summary,
            aiText: aiText,
            showCelebration: true
          )

          if isLoadingAI {
            HStack(spacing: 8) {
              ProgressView()
              Text("AI 正在分析本次训练…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
          }

          Button {
            dismiss()
          } label: {
            Text("太棒了，完成")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .buttonStyle(.borderedProminent)
          .tint(AppTheme.accent)
        }
        .padding(16)
      }
      .appPageBackground()
      .navigationTitle("训练完成")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        await loadAIAnalysis()
      }
    }
  }

  private func loadAIAnalysis() async {
    if let cached = dayPlan.aiSessionSummary, !cached.isEmpty {
      aiText = cached
      return
    }

    isLoadingAI = true
    defer { isLoadingAI = false }

    let lines = WorkoutSessionAnalysisFormatter.exerciseLines(dayPlan: dayPlan, in: modelContext)
    let client = WorkoutSessionAnalysisClient()

    do {
      let result = try await client.analyze(summary: summary, exercises: lines)
      let formatted = WorkoutSessionAnalysisFormatter.formattedText(result)
      aiText = formatted
      dayPlan.aiSessionSummary = formatted
      try? modelContext.save()
    } catch {
      let fallback = WorkoutSessionAnalysisClient.localFallback(summary: summary, exercises: lines)
      let formatted = WorkoutSessionAnalysisFormatter.formattedText(fallback)
      aiText = formatted
      dayPlan.aiSessionSummary = formatted
      try? modelContext.save()
    }
  }
}
