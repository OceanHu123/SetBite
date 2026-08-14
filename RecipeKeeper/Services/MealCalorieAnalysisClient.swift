import Foundation
import UIKit

struct MealCalorieEstimate: Equatable {
  let foodName: String
  let calories: Double
  let carbsG: Double
  let proteinG: Double
  let fatG: Double
  let note: String
}

actor MealCalorieAnalysisClient {
  private let ocrService = ImageOCRService()
  private let foodFacts = OpenFoodFactsClient()

  /// 纯文字估算（无需图片），例如「番茄炒蛋 + 大米饭 150g」或「安慕希 200g」。
  func analyzeText(_ description: String) async throws -> MealCalorieEstimate {
    let apiKey = AppSettings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else { throw RecipeKeeperError.missingAPIKey }

    let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw RecipeKeeperError.apiError("请先写一下这顿吃了什么，或从菜谱选择")
    }
    return try await analyzeWithBrandLookup(apiKey: apiKey, description: trimmed)
  }

  func analyzeMeal(image: UIImage?, caption: String = "") async throws -> MealCalorieEstimate {
    let apiKey = AppSettings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else { throw RecipeKeeperError.missingAPIKey }

    let captionText = caption.trimmingCharacters(in: .whitespacesAndNewlines)

    if captionText.isEmpty {
      guard let image else {
        throw RecipeKeeperError.apiError("请先写一下这顿吃了什么，或从菜谱选择")
      }
      return try await analyzePhoto(apiKey: apiKey, image: image, caption: "")
    }

    return try await analyzeWithBrandLookup(apiKey: apiKey, description: captionText)
  }

  /// 纯文字估算（无需图片），例如「大米饭 150g」「番茄炒蛋一份」。
  func analyzeDescription(_ description: String) async throws -> MealCalorieEstimate {
    try await analyzeText(description)
  }

  private func analyzePhoto(apiKey: String, image: UIImage, caption: String) async throws -> MealCalorieEstimate {
    if let jpeg = compressedJPEG(from: image) {
      do {
        return try await requestVisionEstimate(apiKey: apiKey, jpeg: jpeg, caption: caption)
      } catch {
        // Fall through to OCR + text path.
      }
    }

    let ocrText = (try? await ocrService.extractText(from: [image], progress: { _, _ in })) ?? ""
    let combined = [caption, ocrText]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")

    guard !combined.isEmpty else {
      throw RecipeKeeperError.apiError("图片识别失败，请在补充说明里写一下这顿吃了什么，再试一次")
    }

    return try await analyzeWithBrandLookup(apiKey: apiKey, description: combined)
  }

  private func analyzeWithBrandLookup(apiKey: String, description: String) async throws -> MealCalorieEstimate {
    let items = (try? await splitFoodItems(apiKey: apiKey, description: description)) ?? []
    if items.isEmpty {
      return try await requestTextEstimate(apiKey: apiKey, description: description)
    }

    var labeled: [ItemEstimate] = []
    var unmatched: [FoodItem] = []

    for item in items {
      if let packaged = await foodFacts.searchBest(query: item.query),
         let estimate = scaledPackaged(item: item, packaged: packaged) {
        labeled.append(estimate)
      } else {
        unmatched.append(item)
      }
    }

    if !unmatched.isEmpty {
      let estimated = try await requestTextEstimate(
        apiKey: apiKey,
        description: unmatchedDescription(unmatched, original: description)
      )
      labeled.append(
        ItemEstimate(
          name: estimated.foodName,
          calories: estimated.calories,
          carbsG: estimated.carbsG,
          proteinG: estimated.proteinG,
          fatG: estimated.fatG,
          fromLabel: false,
          detail: estimated.note.isEmpty ? "估算" : estimated.note
        )
      )
    }

    return mergeEstimates(labeled)
  }

  private func scaledPackaged(item: FoodItem, packaged: PackagedNutrition) -> ItemEstimate? {
    let grams = item.grams ?? packaged.servingGrams ?? 100
    guard grams > 0 else { return nil }
    let macros = packaged.scaled(grams: grams)
    let amount = grams == grams.rounded() ? "\(Int(grams))g" : String(format: "%.0fg", grams)
    return ItemEstimate(
      name: packaged.displayName,
      calories: macros.calories,
      carbsG: macros.carbsG,
      proteinG: macros.proteinG,
      fatG: macros.fatG,
      fromLabel: true,
      detail: "\(amount) 包装成分表"
    )
  }

  private func unmatchedDescription(_ items: [FoodItem], original: String) -> String {
    let lines = items.map { item in
      if let grams = item.grams, grams > 0 {
        return "- \(item.name) \(Int(grams.rounded()))g"
      }
      return "- \(item.name)"
    }
    return """
    请估算以下未在包装成分表中找到的食物，按给定克数；未写克数则按家常一份。
    \(lines.joined(separator: "\n"))

    原始描述：
    \(original)
    """
  }

  private func mergeEstimates(_ parts: [ItemEstimate]) -> MealCalorieEstimate {
    let calories = parts.reduce(0) { $0 + $1.calories }
    let carbs = parts.reduce(0) { $0 + $1.carbsG }
    let protein = parts.reduce(0) { $0 + $1.proteinG }
    let fat = parts.reduce(0) { $0 + $1.fatG }
    let foodName = parts.map(\.name).joined(separator: " + ")
    let note = parts.map { "\($0.name)：\($0.detail)" }.joined(separator: " · ")
    return MealCalorieEstimate(
      foodName: foodName,
      calories: calories,
      carbsG: carbs,
      proteinG: protein,
      fatG: fat,
      note: note
    )
  }

  private func splitFoodItems(apiKey: String, description: String) async throws -> [FoodItem] {
    let body: [String: Any] = [
      "model": DeepSeekAPI.flashModel,
      "messages": [
        ["role": "system", "content": splitSystemPrompt],
        ["role": "user", "content": description]
      ],
      "response_format": ["type": "json_object"],
      "thinking": ["type": "disabled"]
    ]
    let content = try await postJSON(apiKey: apiKey, body: body)
    return parseFoodItems(from: content)
  }

  private var splitSystemPrompt: String {
    """
    把用户的餐食描述拆成食物条目。只输出 JSON，不要 markdown。
    {
      "items": [
        {"name": "展示名", "query": "品牌+品名搜索词", "grams": 200}
      ]
    }
    规则：
    - 多道菜/多种包装食品拆成多条
    - grams：用户写了 g/克/ml/毫升/kg 就换算成克；ml 按 1ml=1g；没写分量时 grams 为 0
    - query：适合搜索包装成分表，保留品牌和口味，去掉「一份」「一杯」等
    - 家常菜也要列出（搜不到再估算）
    """
  }

  private func parseFoodItems(from content: String) -> [FoodItem] {
    guard let json = jsonObject(from: content) as? [String: Any] else { return [] }
    let rawItems = json["items"] as? [[String: Any]] ?? []
    return rawItems.compactMap { raw in
      let name = (raw["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let query = (raw["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
      guard !name.isEmpty || !query.isEmpty else { return nil }
      let gramsValue = number(raw["grams"])
      return FoodItem(
        name: name.isEmpty ? query : name,
        query: query.isEmpty ? name : query,
        grams: gramsValue > 0 ? gramsValue : nil
      )
    }
  }

  private func requestVisionEstimate(apiKey: String, jpeg: Data, caption: String) async throws -> MealCalorieEstimate {
    let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    let captionBlock = caption.isEmpty
      ? "用户未补充文字说明，请仅根据图片判断。"
      : "用户补充：\(caption)"

    let body: [String: Any] = [
      "model": DeepSeekAPI.flashModel,
      "messages": [
        ["role": "system", "content": systemPrompt],
        [
          "role": "user", "content": [
            ["type": "text", "text": "请识别这顿饭并估算营养。\n\(captionBlock)"],
            ["type": "image_url", "image_url": ["url": dataURL]]
          ] as [[String: Any]]
        ]
      ],
      "response_format": ["type": "json_object"],
      "thinking": ["type": "disabled"]
    ]

    let content = try await postJSON(apiKey: apiKey, body: body, retries: 1)
    return try parseEstimate(from: content)
  }

  private func requestTextEstimate(apiKey: String, description: String) async throws -> MealCalorieEstimate {
    let body: [String: Any] = [
      "model": DeepSeekAPI.flashModel,
      "messages": [
        ["role": "system", "content": systemPrompt],
        [
          "role": "user",
          "content": """
          请根据以下餐食描述估算营养（可能来自用户备注、菜谱或图片文字）。
          若写明克数/份量，请严格按该分量估算；未写明则按家常一份估算。
          \(description)
          """
        ]
      ],
      "response_format": ["type": "json_object"],
      "thinking": ["type": "disabled"]
    ]

    let content = try await postJSON(apiKey: apiKey, body: body)
    return try parseEstimate(from: content)
  }

  private var systemPrompt: String {
    """
    你是营养估算助手。根据餐食照片、菜谱或文字描述，估算一份可食用分量的热量与三大营养素。
    只输出 JSON，不要 markdown，不要额外说明。
    JSON 格式：
    {
      "foodName": "菜名或食物名",
      "calories": 520,
      "carbsG": 55,
      "proteinG": 28,
      "fatG": 18,
      "note": "简短说明估算依据，一句即可"
    }
    规则：
    - 用户写明克数/毫升/份数时，严格按该分量估算（例如「大米饭 150g」）
    - 未写明分量时，按家常一餐常见份量估算
    - calories / carbsG / proteinG / fatG 用数字
    - 多道菜时按整盘合计
    - 看不清或信息不足时仍给合理估计，并在 note 标明不确定
    """
  }

  private func postJSON(apiKey: String, body: [String: Any], retries: Int = 2) async throws -> String {
    let payload = try JSONSerialization.data(withJSONObject: body)
    let data = try await DeepSeekHTTP.post(apiKey: apiKey, body: payload, timeout: 90, retries: retries)
    let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
    guard let content = chatResponse.firstContent else {
      throw RecipeKeeperError.parseError
    }
    return content
  }

  private func compressedJPEG(from image: UIImage, maxDimension: CGFloat = 720, maxBytes: Int = 160_000) -> Data? {
    let size = image.size
    let longest = max(size.width, size.height)
    let scaled: UIImage
    if longest > maxDimension {
      let scale = maxDimension / longest
      let newSize = CGSize(width: size.width * scale, height: size.height * scale)
      let renderer = UIGraphicsImageRenderer(size: newSize)
      scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    } else {
      scaled = image
    }

    var quality: CGFloat = 0.5
    var data = scaled.jpegData(compressionQuality: quality)
    while let current = data, current.count > maxBytes, quality > 0.22 {
      quality -= 0.08
      data = scaled.jpegData(compressionQuality: quality)
    }
    return data
  }

  private func parseEstimate(from content: String) throws -> MealCalorieEstimate {
    guard let json = jsonObject(from: content) as? [String: Any] else {
      throw RecipeKeeperError.parseError
    }

    let foodName = (json["foodName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let foodName, !foodName.isEmpty else { throw RecipeKeeperError.parseError }

    return MealCalorieEstimate(
      foodName: foodName,
      calories: number(json["calories"]),
      carbsG: number(json["carbsG"]),
      proteinG: number(json["proteinG"]),
      fatG: number(json["fatG"]),
      note: (json["note"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  private func jsonObject(from content: String) -> Any? {
    let trimmed = content
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "```json", with: "")
      .replacingOccurrences(of: "```", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if let data = trimmed.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) {
      return obj
    }
    if let start = trimmed.firstIndex(of: "{"),
       let end = trimmed.lastIndex(of: "}"),
       let data = String(trimmed[start...end]).data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) {
      return obj
    }
    return nil
  }

  private func number(_ value: Any?) -> Double {
    if let number = value as? Double { return max(0, number) }
    if let number = value as? Int { return Double(max(0, number)) }
    if let number = value as? NSNumber { return max(0, number.doubleValue) }
    if let text = value as? String, let number = Double(text) { return max(0, number) }
    return 0
  }
}

private struct FoodItem {
  let name: String
  let query: String
  let grams: Double?
}

private struct ItemEstimate {
  let name: String
  let calories: Double
  let carbsG: Double
  let proteinG: Double
  let fatG: Double
  let fromLabel: Bool
  let detail: String
}
