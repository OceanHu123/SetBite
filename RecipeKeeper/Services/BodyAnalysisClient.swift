import Foundation

actor BodyAnalysisClient {

  func analyze(records: [BodyRecord], heightCm: Double) async throws -> BodyAnalysisResult {
    let apiKey = AppSettings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else {
      throw RecipeKeeperError.missingAPIKey
    }

    guard !records.isEmpty else {
      throw BodyTrackerError.noRecords
    }

    let sorted = records.sorted { $0.date < $1.date }
    let lines = sorted.map { record in
      let day = record.date.formatted(date: .abbreviated, time: .omitted)
      return "\(day): 体重\(String(format: "%.1f", record.weight))kg, 腰围\(String(format: "%.1f", record.waist))cm, 臂围\(String(format: "%.1f", record.arm))cm"
    }.joined(separator: "\n")

    let latest = sorted.last!
    let localBodyFat = BodyFatEstimator.estimatePercent(
      weightKg: latest.weight,
      waistCm: latest.waist,
      heightCm: heightCm
    )

    let systemPrompt = """
    你是温暖专业的健身塑形教练。用户是女生，身高\(String(format: "%.0f", heightCm))cm，目标是宽肩窄腰、清晰肌肉线条（体脂适中、腰腹紧致、肩臂有线条感）。
    根据用户每日体重、腰围、臂围记录分析趋势。只输出 JSON：
    {
      "trend": "减脂中/增肌中/塑形中/保持稳定",
      "summary": "2-3句客观分析变化",
      "bodyFatPercent": "如 约23.5%",
      "goalDistance": "距离清晰线条目标还有多远，具体写差距（如体脂还需降X%、腰围还需减Xcm、臂围建议维持或+Xm）",
      "targetDescription": "清晰线条的参考目标（体脂区间、腰围臂围参考值）",
      "encouragement": "2-3句热情鼓励",
      "tips": ["建议1", "建议2"]
    }
    规则：可参考本地估算体脂约\(String(format: "%.1f", localBodyFat))%；女生175cm清晰线条常见参考体脂约20-22%、腰围约62-66cm；语气积极亲切；用中文。
    """

    let userContent = """
    我的记录：
    \(lines)

    最新一天：体重\(String(format: "%.1f", latest.weight))kg，腰围\(String(format: "%.1f", latest.waist))cm，臂围\(String(format: "%.1f", latest.arm))cm
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

    return try JSONDecoder().decode(BodyAnalysisResult.self, from: jsonData)
  }
}

enum BodyFatEstimator {
  /// 基于身高、体重、腰围的简化估算（女生）
  static func estimatePercent(weightKg: Double, waistCm: Double, heightCm: Double) -> Double {
    let heightM = heightCm / 100
    let bmi = weightKg / (heightM * heightM)
    let whtr = waistCm / heightCm
    let fromBMI = 1.2 * bmi + 0.23 * 25 - 10.8 * 0 - 5.4
    let fromWaist = (whtr - 0.35) * 100 + 18
    let blended = fromBMI * 0.45 + fromWaist * 0.55
    return min(max(blended, 12), 45)
  }
}

enum BodyTrackerError: LocalizedError {
  case noRecords
  case invalidInput

  var errorDescription: String? {
    switch self {
    case .noRecords: return "先记录至少一天的数据"
    case .invalidInput: return "请填写有效的数字"
    }
  }
}
