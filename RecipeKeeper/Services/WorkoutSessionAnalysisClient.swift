import Foundation
import SwiftData

struct WorkoutSessionAnalysisResult: Codable, Equatable {
  let headline: String
  let summary: String
  let highlights: [String]
  let tips: [String]
}

actor WorkoutSessionAnalysisClient {

  func analyze(summary: WorkoutSessionSummaryData, exercises: [ExerciseLine]) async throws -> WorkoutSessionAnalysisResult {
    let apiKey = AppSettings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else {
      throw RecipeKeeperError.missingAPIKey
    }

    let exerciseLines = exercises.map(\.description).joined(separator: "\n")
    let muscleLabels = summary.muscleHighlights
      .filter(\.isPrimary)
      .map(\.label)
      .joined(separator: "、")

    let systemPrompt = """
    你是专业又亲切的健身教练。用户刚完成一次力量训练，请根据数据给出简短复盘。只输出 JSON：
    {
      "headline": "一句祝贺或亮点标题，10字以内",
      "summary": "2-3句客观总结本次训练强度与肌群覆盖",
      "highlights": ["亮点1", "亮点2"],
      "tips": ["下次建议1", "下次建议2"]
    }
    语气积极、具体，用中文；不要夸大；若数据不全就基于已有信息分析。
    """

    let userContent = """
    日期：\(summary.date.formatted(date: .abbreviated, time: .omitted))
    总容量：\(Int(summary.totalCapacityKg))kg（重量×次数×组数）
    耗时：\(summary.durationLabel)
    消耗：\(summary.caloriesLabel)大卡
    主要肌群：\(muscleLabels.isEmpty ? "综合" : muscleLabels)
    动作明细：
    \(exerciseLines)
    """

    let requestBody = DeepSeekChatRequest(
      messages: [
        .init(role: "system", content: systemPrompt),
        .init(role: "user", content: userContent)
      ]
    )

    let data = try await DeepSeekHTTP.post(
      apiKey: apiKey,
      body: try JSONEncoder().encode(requestBody)
    )

    let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
    guard let content = chatResponse.firstContent,
          let jsonData = content.data(using: .utf8) else {
      throw RecipeKeeperError.parseError
    }

    return try JSONDecoder().decode(WorkoutSessionAnalysisResult.self, from: jsonData)
  }

  struct ExerciseLine {
    let description: String
  }

  static func localFallback(summary: WorkoutSessionSummaryData, exercises: [ExerciseLine]) -> WorkoutSessionAnalysisResult {
    let primary = summary.muscleHighlights.filter(\.isPrimary).map(\.label)
    let muscleText = primary.isEmpty ? "综合训练" : primary.joined(separator: "、")
    return WorkoutSessionAnalysisResult(
      headline: "训练完成！",
      summary: "今天完成了 \(summary.exerciseCount) 个动作，主要练到 \(muscleText)。总容量约 \(Int(summary.totalCapacityKg)) kg，继续保持节奏。",
      highlights: exercises.prefix(2).map { "✓ \($0.description)" },
      tips: ["下次可在主项上尝试小幅加重", "注意练后拉伸与蛋白质摄入"]
    )
  }
}

enum WorkoutSessionAnalysisFormatter {
  static func exerciseLines(
    dayPlan: WorkoutDayPlan,
    in context: ModelContext
  ) -> [WorkoutSessionAnalysisClient.ExerciseLine] {
    dayPlan.sortedExercises.compactMap { exercise in
      guard let log = WorkoutStore.sessionLog(for: exercise.templateID, on: dayPlan.date, in: context) else {
        return nil
      }
      let reps = WorkoutFormat.sessionRepsLabel(
        sets: log.sets,
        maxReps: log.reps,
        setRepsLog: log.setRepsLog
      )
      return WorkoutSessionAnalysisClient.ExerciseLine(
        description: "\(exercise.name) \(WorkoutFormat.weight(log.weightKg)) \(reps)"
      )
    }
  }

  static func formattedText(_ result: WorkoutSessionAnalysisResult) -> String {
    var lines = [result.headline, "", result.summary]
    if !result.highlights.isEmpty {
      lines.append("")
      lines.append("亮点")
      lines.append(contentsOf: result.highlights.map { "· \($0)" })
    }
    if !result.tips.isEmpty {
      lines.append("")
      lines.append("建议")
      lines.append(contentsOf: result.tips.map { "· \($0)" })
    }
    return lines.joined(separator: "\n")
  }
}
