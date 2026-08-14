import Foundation

struct GeneratedWorkoutPlan: Codable, Equatable {
  struct UncertainName: Codable, Equatable, Identifiable {
    let rawName: String
    let candidates: [String]
    let reason: String?

    var id: String { rawName }
  }

  struct Exercise: Codable, Equatable {
    let name: String
    let bodyPart: String?
    let bodySubpart: String?
    let restSeconds: Int?
    let notes: String?
    let targetSets: Int?
    let minReps: Int?
    let maxReps: Int?
  }

  struct Day: Codable, Equatable {
    let weekdayIndex: Int
    let exercises: [Exercise]

    var exerciseNames: [String] { exercises.map(\.name) }

    enum CodingKeys: String, CodingKey {
      case weekdayIndex
      case exercises
      case exerciseNames
    }

    init(weekdayIndex: Int, exercises: [Exercise]) {
      self.weekdayIndex = weekdayIndex
      self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      weekdayIndex = try container.decode(Int.self, forKey: .weekdayIndex)
      if let exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) {
        self.exercises = exercises
      } else if let names = try container.decodeIfPresent([String].self, forKey: .exerciseNames) {
        self.exercises = names.map {
          Exercise(
            name: $0,
            bodyPart: nil,
            bodySubpart: nil,
            restSeconds: nil,
            notes: nil,
            targetSets: nil,
            minReps: nil,
            maxReps: nil
          )
        }
      } else {
        self.exercises = []
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(weekdayIndex, forKey: .weekdayIndex)
      try container.encode(exercises, forKey: .exercises)
    }
  }

  let summary: String?
  let days: [Day]
  let uncertainties: [UncertainName]?

  init(summary: String?, days: [Day], uncertainties: [UncertainName]? = nil) {
    self.summary = summary
    self.days = days
    self.uncertainties = uncertainties
  }

  var resolvedUncertainties: [UncertainName] {
    uncertainties ?? []
  }

  func applyingNameSelections(
    _ selections: [NameResolutionItem],
    existingTemplateNames: Set<String> = []
  ) -> GeneratedWorkoutPlan {
    let selectionByRaw = Dictionary(uniqueKeysWithValues: selections.map { ($0.rawName, $0) })
    let mappedDays = days.map { day in
      Day(
        weekdayIndex: day.weekdayIndex,
        exercises: day.exercises.map { exercise in
          let resolved = selectionByRaw[exercise.name]?.selected.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
          let bracketNote = selectionByRaw[exercise.name].flatMap { Self.bracketNote(from: $0.rawName) }
          let mergedNotes: String?
          if existingTemplateNames.contains(resolved), let bracketNote {
            mergedNotes = Self.mergeNotes(exercise.notes, extra: bracketNote)
          } else {
            mergedNotes = exercise.notes
          }
          return Exercise(
            name: resolved,
            bodyPart: exercise.bodyPart,
            bodySubpart: exercise.bodySubpart,
            restSeconds: exercise.restSeconds,
            notes: mergedNotes,
            targetSets: exercise.targetSets,
            minReps: exercise.minReps,
            maxReps: exercise.maxReps
          )
        }
      )
    }
    return GeneratedWorkoutPlan(summary: summary, days: mappedDays, uncertainties: nil)
  }

  private static func bracketNote(from rawName: String) -> String? {
    let pattern = "[（(]([^（）()]+)[）)]"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let source = rawName as NSString
    let matches = regex.matches(in: rawName, range: NSRange(location: 0, length: source.length))
    let notes = matches.compactMap { match -> String? in
      guard match.numberOfRanges > 1 else { return nil }
      return source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }.filter { !$0.isEmpty }
    guard !notes.isEmpty else { return nil }
    return notes.joined(separator: "，")
  }

  private static func mergeNotes(_ base: String?, extra: String) -> String {
    let baseTrimmed = base?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !baseTrimmed.isEmpty else { return extra }
    if baseTrimmed.contains(extra) {
      return baseTrimmed
    }
    return "\(baseTrimmed)，\(extra)"
  }
}

struct NameResolutionItem: Identifiable {
  static let customOptionKey = "__custom_name__"

  let rawName: String
  let reason: String?
  var candidates: [String]
  var selectedOption: String
  var customName: String

  var selected: String {
    if selectedOption == Self.customOptionKey {
      let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? rawName : trimmed
    }
    return selectedOption
  }

  var id: String { rawName }
}

actor WorkoutPlanAIClient {

  func parsePastedPlan(
    pastedText: String,
    templates: [ExerciseTemplate],
    weekRangeLabel: String
  ) async throws -> GeneratedWorkoutPlan {
    let apiKey = AppSettings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else {
      throw RecipeKeeperError.missingAPIKey
    }

    let trimmedText = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
      throw WorkoutPlanError.emptyRequest
    }

    let libraryLines = templates.map { template in
      "- \(template.name)（\(template.bodyPart)/\(template.bodySubpart)）"
    }.joined(separator: "\n")

    let bodyCatalog = ExerciseBodyCatalog.parts.map { part in
      "\(part.name)（\(part.subparts.joined(separator: "/"))）"
    }.joined(separator: "、")

    let systemPrompt = """
    你是训练计划解析助手。用户会粘贴从其他 AI 或文档复制的训练计划，请解析并排入指定周。
    只输出 JSON，不要 markdown，不要额外说明。
    JSON 格式：
    {
      "summary": "可选，一句概括",
      "days": [
        {
          "weekdayIndex": 0,
          "exercises": [
            { "name": "哑铃侧平举", "targetSets": 4, "minReps": 4, "maxReps": 6, "restSeconds": 60, "notes": "力竭" },
            { "name": "面拉", "bodyPart": "肩", "bodySubpart": "后束", "targetSets": 4, "minReps": 8, "maxReps": 10, "restSeconds": 90 }
          ]
        }
      ]
    }
    规则：
    - 目标周：\(weekRangeLabel)，weekdayIndex 0=周一 … 6=周日
    - 从粘贴文本识别每天练什么；休息/恢复日不要放进 days
    - name 必须与粘贴原文中的动作名完全一致，禁止擅自改写、合并或猜测成动作库名称
    - 库中没有的新动作需填 bodyPart、bodySubpart
    - 可用部位：\(bodyCatalog)
    - 若文本写「周几」「Monday」或具体日期，映射到该周 weekdayIndex
    - 同一天多个动作全部保留，顺序与原文一致
    - restSeconds：从原文提取该动作的组间间歇时间（秒整数）；如写「间歇90s」「rest 2min」「休息1分30秒」则换算为秒；没有写明则不输出 restSeconds
    - targetSets、minReps、maxReps：从组数次数提取。如「4组×4-6次」「4组 × 4-6次」「4×4-6」→ targetSets=4, minReps=4, maxReps=6；固定次数「4×6」「4组6次」→ targetSets=4, minReps=6, maxReps=6。maxReps 是进阶做满上限（次数区间取上限）
    - 力竭类写法：如「2组×接近力竭」「2组 × 力竭」「3组力竭」→ targetSets=2/3，notes=接近力竭/力竭，× 后面是强度要求不是次数，不要输出 minReps/maxReps
    - notes：提取该动作本次的特殊要求，写入 notes 字段。包括括号内说明（如「侧平举（力竭）」→ name=哑铃侧平举, notes=力竭）、力竭、接近力竭、RPE、节奏、停顿、离心/向心要求、单侧/交替、递减组等；不要重复组数次数重量和间歇；没有额外要求则不输出 notes
    - name 只写动作名，不要把括号内容放进 name
    - 不要输出 uncertainties；客户端会根据动作库自动询问用户确认名称
    """

    let userContent = """
    目标周：\(weekRangeLabel)

    动作库（名称尽量一致）：
    \(libraryLines.isEmpty ? "（暂无，按文本提取新动作并标注部位）" : libraryLines)

    粘贴的训练计划：
    \(trimmedText)
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
    guard let content = chatResponse.firstContent else {
      throw WorkoutPlanError.parseFailed
    }

    return normalizePlan(try decodePlanJSON(from: content), templates: templates, pastedText: trimmedText)
  }

  private func normalizePlan(
    _ plan: GeneratedWorkoutPlan,
    templates: [ExerciseTemplate],
    pastedText: String
  ) -> GeneratedWorkoutPlan {
    let days = plan.days.map { day in
      GeneratedWorkoutPlan.Day(
        weekdayIndex: day.weekdayIndex,
        exercises: day.exercises.map { normalizeExerciseScheme($0) }
      )
    }

    return GeneratedWorkoutPlan(
      summary: plan.summary,
      days: days,
      uncertainties: buildUncertainties(
        days: days,
        aiUncertainties: plan.uncertainties,
        templates: templates,
        pastedText: pastedText
      )
    )
  }

  private func buildUncertainties(
    days: [GeneratedWorkoutPlan.Day],
    aiUncertainties: [GeneratedWorkoutPlan.UncertainName]?,
    templates: [ExerciseTemplate],
    pastedText: String
  ) -> [GeneratedWorkoutPlan.UncertainName] {
    let aiByKey = Dictionary(
      uniqueKeysWithValues: (aiUncertainties ?? []).map {
        (ExerciseTemplate.normalize($0.rawName), $0)
      }
    )

    var result: [GeneratedWorkoutPlan.UncertainName] = []
    var seenKeys = Set<String>()

    for name in days.flatMap({ $0.exercises.map(\.name) }) {
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      let key = ExerciseTemplate.normalize(trimmed)
      guard !seenKeys.contains(key) else { continue }
      seenKeys.insert(key)

      if ExerciseNameCatalog.hasExactTemplateName(trimmed, in: templates),
         appearsInSource(trimmed, source: pastedText) {
        continue
      }

      let aiItem = aiByKey[key]
      let candidates = ExerciseNameCatalog.resolutionCandidates(
        for: trimmed,
        in: templates,
        extra: aiItem?.candidates ?? []
      )
      let reason: String
      if !appearsInSource(trimmed, source: pastedText) {
        reason = aiItem?.reason ?? "名称与原文不一致，请确认"
      } else {
        reason = aiItem?.reason ?? "动作名与动作库不一致，请确认使用哪个名称"
      }
      result.append(
        GeneratedWorkoutPlan.UncertainName(
          rawName: trimmed,
          candidates: candidates,
          reason: reason
        )
      )
    }

    return result
  }

  private func normalizeExerciseScheme(
    _ exercise: GeneratedWorkoutPlan.Exercise
  ) -> GeneratedWorkoutPlan.Exercise {
    let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let notes = exercise.notes?.trimmingCharacters(in: .whitespacesAndNewlines)

    if let failureNote = Self.failureIntensityNote(in: notes) {
      return GeneratedWorkoutPlan.Exercise(
        name: name,
        bodyPart: exercise.bodyPart,
        bodySubpart: exercise.bodySubpart,
        restSeconds: exercise.restSeconds,
        notes: failureNote,
        targetSets: exercise.targetSets,
        minReps: nil,
        maxReps: nil
      )
    }

    return GeneratedWorkoutPlan.Exercise(
      name: name,
      bodyPart: exercise.bodyPart,
      bodySubpart: exercise.bodySubpart,
      restSeconds: exercise.restSeconds,
      notes: notes,
      targetSets: exercise.targetSets,
      minReps: exercise.minReps,
      maxReps: exercise.maxReps
    )
  }

  private static func failureIntensityNote(in notes: String?) -> String? {
    guard let notes, !notes.isEmpty else { return nil }
    if notes.contains("接近力竭") { return "接近力竭" }
    if notes.localizedCaseInsensitiveContains("力竭") { return "力竭" }
    if notes.localizedCaseInsensitiveContains("rpe") { return notes }
    return nil
  }

  private func appearsInSource(_ name: String, source: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    if source.isEmpty { return true }
    return source.localizedCaseInsensitiveContains(trimmed)
  }

  private func decodePlanJSON(from content: String) throws -> GeneratedWorkoutPlan {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmed.data(using: .utf8) else {
      throw WorkoutPlanError.parseFailed
    }

    do {
      return try JSONDecoder().decode(GeneratedWorkoutPlan.self, from: data)
    } catch {
      if let start = trimmed.firstIndex(of: "{"),
         let end = trimmed.lastIndex(of: "}") {
        let jsonSlice = String(trimmed[start...end])
        if let sliceData = jsonSlice.data(using: .utf8) {
          return try JSONDecoder().decode(GeneratedWorkoutPlan.self, from: sliceData)
        }
      }
      throw WorkoutPlanError.parseFailed
    }
  }
}

enum WorkoutPlanError: LocalizedError {
  case emptyRequest
  case parseFailed

  var errorDescription: String? {
    switch self {
    case .emptyRequest:
      return "请先粘贴训练计划"
    case .parseFailed:
      return "无法解析训练计划，请检查格式或 API Key"
    }
  }
}
