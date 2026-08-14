import Foundation

enum ExerciseNameCatalog {
  /// 规范名 → 可合并的别名（均映射到规范名）
  private static let mergeGroups: [String: [String]] = [
    "器械推肩": ["器械肩推", "器械坐姿推肩", "坐姿器械推肩"],
    "哑铃推肩": ["坐姿哑铃推肩", "坐姿哑铃肩推", "坐姿推肩"],
    "反向蝴蝶机飞鸟": ["反向飞鸟", "蝴蝶机反向飞鸟", "反向蝴蝶机"],
    "绳索面拉": ["面拉", "龙门架面拉"],
    "单臂下拉": ["单臂高位下拉", "单边高位下拉"],
    "高位下拉": ["宽距正握高位下拉", "宽距高位下拉", "正握高位下拉", "宽握高位下拉"],
    "器械侧平举": ["悍马机侧平举", "悍马侧平举", "hammer机侧平举", "机器侧平举"],
    "哑铃侧平举": ["侧平举"],
    "阿诺德推肩": ["阿诺德"],
    "V把下拉": ["v把下拉"]
  ]

  private static let aliasByKey: [String: String] = {
    var map: [String: String] = [:]
    for (canonical, aliases) in mergeGroups {
      map[ExerciseTemplate.normalize(canonical)] = canonical
      for alias in aliases {
        map[ExerciseTemplate.normalize(alias)] = canonical
      }
    }
    return map
  }()

  static var mergeRulesForPrompt: String {
    mergeGroups.map { canonical, aliases in
      "\(aliases.joined(separator: "、")) → \(canonical)"
    }.joined(separator: "；")
  }

  static var allCanonicalNames: [String] {
    mergeGroups.keys.sorted()
  }

  /// 统一动作显示名，便于动作库合并与导入匹配
  static func canonicalName(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }

    let key = ExerciseTemplate.normalize(trimmed)
    if let alias = aliasByKey[key] {
      return alias
    }
    return trimmed
  }

  static func canonicalKey(_ raw: String) -> String {
    ExerciseTemplate.normalize(canonicalName(raw))
  }

  static func findTemplate(named rawName: String, in templates: [ExerciseTemplate]) -> ExerciseTemplate? {
    let key = canonicalKey(rawName)
    return templates.first { canonicalKey($0.name) == key }
  }

  /// 动作库中可能的候选（规范名 + 库中已有同名系）
  static func candidates(for rawName: String, in templates: [ExerciseTemplate]) -> [String] {
    let canonical = canonicalName(rawName)
    var options = [canonical]
    let key = canonicalKey(rawName)
    for template in templates {
      let name = template.name
      if canonicalKey(name) == key, !options.contains(name) {
        options.append(name)
      }
    }
    return options
  }

  /// 动作库中是否存在与导入名完全一致的动作
  static func hasExactTemplateName(_ rawName: String, in templates: [ExerciseTemplate]) -> Bool {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return templates.contains { $0.name == trimmed }
  }

  /// 导入确认页的候选：原名优先，附带动作库中可能相关的名称
  static func resolutionCandidates(
    for rawName: String,
    in templates: [ExerciseTemplate],
    extra: [String] = []
  ) -> [String] {
    var options: [String] = []

    func add(_ name: String) {
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, !options.contains(trimmed) else { return }
      options.append(trimmed)
    }

    add(rawName)
    for suggestion in extra { add(suggestion) }
    for suggestion in candidates(for: rawName, in: templates) { add(suggestion) }
    for template in templates where canonicalKey(template.name) == canonicalKey(rawName) {
      add(template.name)
    }
    for suggestion in similarTemplateNames(for: rawName, in: templates, limit: 6) {
      add(suggestion)
    }
    return options
  }

  private static func similarTemplateNames(
    for rawName: String,
    in templates: [ExerciseTemplate],
    limit: Int
  ) -> [String] {
    let source = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else { return [] }
    let normalizedSource = ExerciseTemplate.normalize(source)

    let ranked = templates.compactMap { template -> (String, Int)? in
      let name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return nil }
      let normalized = ExerciseTemplate.normalize(name)
      let score = similarityScore(
        source: source,
        normalizedSource: normalizedSource,
        candidate: name,
        normalizedCandidate: normalized
      )
      return score > 0 ? (name, score) : nil
    }
    .sorted { lhs, rhs in
      if lhs.1 == rhs.1 { return lhs.0.count < rhs.0.count }
      return lhs.1 > rhs.1
    }

    var result: [String] = []
    for (name, _) in ranked where !result.contains(name) {
      result.append(name)
      if result.count >= limit { break }
    }
    return result
  }

  private static func similarityScore(
    source: String,
    normalizedSource: String,
    candidate: String,
    normalizedCandidate: String
  ) -> Int {
    var score = 0

    if normalizedCandidate.contains(normalizedSource) || normalizedSource.contains(normalizedCandidate) {
      score += 4
    }

    let sourceTokens = featureTokens(from: source)
    let candidateTokens = featureTokens(from: candidate)
    let common = sourceTokens.intersection(candidateTokens)
    score += common.count * 2

    if source.contains("推") && candidate.contains("推") { score += 1 }
    if source.contains("拉") && candidate.contains("拉") { score += 1 }
    if source.contains("飞鸟") && candidate.contains("飞鸟") { score += 2 }
    if source.contains("下拉") && candidate.contains("下拉") { score += 2 }
    if source.contains("侧平举") && candidate.contains("侧平举") { score += 2 }

    return score
  }

  static func featureTokens(from name: String) -> Set<String> {
    let tokens = [
      "哑铃", "杠铃", "器械", "绳索", "龙门架", "单臂", "双臂", "坐姿", "站姿", "高位", "下拉", "划船", "推",
      "飞鸟", "面拉", "侧平举", "反向", "宽距", "正握", "中立握", "窄距", "阿诺德", "悍马", "V把"
    ]
    var found = Set<String>()
    for token in tokens where name.contains(token) {
      found.insert(token)
    }
    return found
  }
}
