import Foundation

actor DeepSeekClient {

  private static let jsonSchema = """
    {
      "title": "菜名",
      "categories": ["汤羹", "主食"],
      "ingredients": [
        {"name": "食材名", "amount": "用量"}
      ],
      "steps": ["步骤1", "步骤2"]
    }
    """

  private static let sharedRules = """
    【用量 — 最重要】
    - 严禁把用量一律写成「适量」「少许」「若干」
    - OCR/原文里出现的数字、单位必须原样保留：如 2个、1勺、100g、半根、一把
    - 画面食材清单上的「番茄 2个」「鸡蛋 2个」必须逐条录入，不能省略
    - 步骤里提到但清单未列的食材（葱、白糖、醋、蛋液、菠菜等）也要补进 ingredients，并尽量写用量
    - 只有原文完全没提用量时，amount 才可写「适量」

    【步骤 — 要细、不要合并】
    - 按烹饪时间线排列，一步一阶段，禁止把多步压成一句
    - 和面、炒番茄、加水烧开、下面疙瘩、调味、加配菜出锅等应分开写
    - 每步写清：动作 + 火候/状态（爆香、出沙、大火烧开、煮至浮起、汤汁浓稠等）
    - 视频前面调酱汁、后面又调酱汁 → 两个独立步骤，配料各自写全
    - 时间戳相隔较远的相同文字视为不同操作，不要合并

    【其他】
    - title 简洁准确
    - categories 从以下选一个或多个：烘焙、素菜、肉菜、海鲜、汤羹、主食、小吃、其他
    - 酱料分次使用时 name 用「腌料生抽」「炒汁生抽」等区分
    - 忽略点赞、关注、广告
    """

  private static let fewShotExample = """
    示例（番茄疙瘩汤，请达到这个细致程度）：
    ingredients: 面粉 适量, 水 适量, 番茄 2个, 葱 适量, 生抽 1勺, 蚝油 1勺, 鸡蛋 2个, 白糖 少许, 醋 少许, 菠菜 100g
    steps:
    1. 将面粉放入碗中，一边用筷子搅拌一边缓慢加水，直到搅拌成均匀的面疙瘩。
    2. 起锅烧油，爆香葱，放入切好的番茄块，炒至出沙。
    3. 加入适量清水，大火烧开。
    4. 将面疙瘩均匀撒入锅中，煮至浮起，撒入蛋液，汤汁略微浓稠。
    5. 加入生抽和蚝油、白糖、醋调味。
    6. 加入一把菠菜，煮好后即可出锅装盘。
    """

  func parseRecipe(from ocrText: String, supplementText: String = "") async throws -> ParsedRecipe {
    let supplement = supplementText.trimmingCharacters(in: .whitespacesAndNewlines)
    let combinedSource = [supplement, ocrText].filter { !$0.isEmpty }.joined(separator: "\n\n")
    let narrationOnly = ocrText.rangeOfCharacter(from: .decimalDigits) == nil && supplement.isEmpty

    let narrationRules = narrationOnly ? """
    【口播视频 — OCR 无食材用量清单时】
    - 很多短视频用量在文案而不在画面，请根据菜名+口播还原完整食谱
    - 食材按家常 2-3 人份给出具体数字（番茄 2个、鸡蛋 2个、菠菜 100g、生抽 1勺），禁止全部写适量
    - 口播没提但此菜必需的食材和步骤要补足（和面加水、葱花、打蛋、下菠菜等）
    - 过滤广告片段，只保留烹饪相关口播
    """ : ""

    let systemPrompt = """
    你是专业食谱整理助手。输入是从烹饪视频 OCR 识别的字幕，每行前有 [分:秒] 时间戳。
    请整理成结构化食谱，只输出 JSON，不要 markdown，不要额外说明。
    JSON 格式：
    \(Self.jsonSchema)

    \(Self.sharedRules)
    \(narrationRules)

    \(Self.fewShotExample)
    """

    var userSections: [String] = []
    if !supplement.isEmpty {
      userSections.append("""
      【帖子文案 / 食材清单 — 优先采用这里的用量】
      \(supplement)
      """)
    }
    userSections.append("""
    【视频 OCR 字幕】
    \(ocrText)
    """)
    let userPrompt = userSections.joined(separator: "\n\n")

    var parsed = try await requestRecipe(systemPrompt: systemPrompt, userPrompt: userPrompt)
    if isLowDetail(parsed, sourceText: combinedSource, narrationOnly: narrationOnly) {
      let retryHint = narrationOnly
        ? "根据菜名和口播，按家常份量写出具体用量数字，步骤拆成 5-8 步，补足加水、打蛋等环节。"
        : "从原文找出每一个数字+单位写入 ingredients.amount，步骤覆盖备料、下锅、调味、出锅。"
      parsed = try await requestRecipe(
        systemPrompt: systemPrompt + "\n【重试】上次输出不合格。\(retryHint)",
        userPrompt: "请更详细解析：\n\n\(userPrompt)"
      )
    }
    return parsed
  }

  func parseRecipeFromText(_ recipeText: String) async throws -> ParsedRecipe {
    let trimmedText = recipeText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else {
      throw RecipeKeeperError.noTextFound
    }

    let systemPrompt = """
    你是专业食谱整理助手。用户粘贴文字食谱，请整理成结构化食谱。
    只输出 JSON，不要 markdown，不要额外说明。
    JSON 格式：
    \(Self.jsonSchema)

    \(Self.sharedRules)
    - 原文无菜名时根据内容推断
    - 保留原文所有关键步骤与用量，不要过度合并
    """

    var parsed = try await requestRecipe(systemPrompt: systemPrompt, userPrompt: trimmedText)
    if isLowDetail(parsed, sourceText: trimmedText, narrationOnly: false) {
      parsed = try await requestRecipe(
        systemPrompt: systemPrompt + "\n【重试】必须保留原文中的具体用量数字，步骤拆细。",
        userPrompt: "请更详细解析，禁止把用量都写成适量：\n\n\(trimmedText)"
      )
    }
    return parsed
  }

  private func requestRecipe(systemPrompt: String, userPrompt: String) async throws -> ParsedRecipe {
    let apiKey = AppSettings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else {
      throw RecipeKeeperError.missingAPIKey
    }

    let requestBody = DeepSeekChatRequest(
      messages: [
        .init(role: "system", content: systemPrompt),
        .init(role: "user", content: userPrompt)
      ]
    )

    let data = try await DeepSeekHTTP.post(
      apiKey: apiKey,
      body: try JSONEncoder().encode(requestBody)
    )

    let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
    guard let content = chatResponse.firstContent else {
      throw RecipeKeeperError.parseError
    }

    return try decodeRecipeJSON(from: content)
  }

  private func isLowDetail(_ recipe: ParsedRecipe, sourceText: String, narrationOnly: Bool) -> Bool {
    guard !recipe.ingredients.isEmpty else { return true }

    let vague = Set(["", "适量", "少许", "若干", "一些", "适当"])
    let vagueCount = recipe.ingredients.filter { vague.contains($0.amount.trimmingCharacters(in: .whitespaces)) }.count
    let mostlyVague = Double(vagueCount) / Double(recipe.ingredients.count) >= 0.6

    let sourceHasDigits = sourceText.rangeOfCharacter(from: .decimalDigits) != nil
    let recipeHasSpecificAmounts = recipe.ingredients.contains {
      !$0.amount.isEmpty && !vague.contains($0.amount.trimmingCharacters(in: .whitespaces))
    }

    let tooFewSteps = recipe.steps.count < 5 && sourceText.count > 120

    if narrationOnly && (mostlyVague || tooFewSteps) { return true }
    if sourceHasDigits && !recipeHasSpecificAmounts && mostlyVague { return true }
    if mostlyVague && recipe.ingredients.count >= 3 { return true }
    if tooFewSteps { return true }
    return false
  }

  private func decodeRecipeJSON(from content: String) throws -> ParsedRecipe {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmed.data(using: .utf8) else {
      throw RecipeKeeperError.parseError
    }

    do {
      return try JSONDecoder().decode(ParsedRecipe.self, from: data)
    } catch {
      if let start = trimmed.firstIndex(of: "{"),
         let end = trimmed.lastIndex(of: "}") {
        let jsonSlice = String(trimmed[start...end])
        if let sliceData = jsonSlice.data(using: .utf8) {
          return try JSONDecoder().decode(ParsedRecipe.self, from: sliceData)
        }
      }
      throw RecipeKeeperError.parseError
    }
  }
}
