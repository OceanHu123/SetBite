import Foundation

enum ExerciseLexicon {
  struct Entry {
    let english: String
    let chinese: String
  }

  /// Canonical Chinese key → professional display names
  private static let entries: [String: Entry] = [
    // Shoulders
    "哑铃推肩": Entry(english: "Dumbbell Shoulder Press", chinese: "哑铃坐姿推肩"),
    "阿诺德推肩": Entry(english: "Arnold Press", chinese: "阿诺德推肩"),
    "器械推肩": Entry(english: "Machine Shoulder Press", chinese: "器械坐姿推肩"),
    "哑铃侧平举": Entry(english: "Dumbbell Lateral Raise", chinese: "哑铃侧平举"),
    "器械侧平举": Entry(english: "Machine Lateral Raise", chinese: "器械侧平举"),
    "绳索侧平举": Entry(english: "Cable Lateral Raise", chinese: "绳索侧平举"),
    "反向蝴蝶机飞鸟": Entry(english: "Reverse Pec Deck Fly", chinese: "反向蝴蝶机飞鸟"),
    "绳索面拉": Entry(english: "Cable Face Pull", chinese: "绳索面拉"),
    // Back
    "高位下拉": Entry(english: "Lat Pulldown", chinese: "高位下拉"),
    "单臂下拉": Entry(english: "Single-Arm Lat Pulldown", chinese: "单臂高位下拉"),
    "辅助引体": Entry(english: "Assisted Pull-Up", chinese: "辅助引体向上"),
    "对握下拉": Entry(english: "Neutral-Grip Lat Pulldown", chinese: "对握高位下拉"),
    "V把下拉": Entry(english: "V-Bar Lat Pulldown", chinese: "V 把高位下拉"),
    "坐姿划船": Entry(english: "Seated Cable Row", chinese: "坐姿绳索划船"),
    "胸托划船": Entry(english: "Chest-Supported Row", chinese: "胸托划船"),
    "直臂下压": Entry(english: "Straight-Arm Pulldown", chinese: "直臂下压"),
    // Core
    "死虫": Entry(english: "Dead Bug", chinese: "死虫式"),
    "山羊挺身": Entry(english: "Back Extension", chinese: "山羊挺身"),
    "悬垂举腿": Entry(english: "Hanging Leg Raise", chinese: "悬垂举腿"),
    // Legs
    "髋外展机": Entry(english: "Hip Abduction Machine", chinese: "髋外展"),
    // Arms
    "二头弯举": Entry(english: "Dumbbell Curl", chinese: "哑铃弯举"),
    "锤式弯举": Entry(english: "Hammer Curl", chinese: "锤式弯举"),
    "三头龙门架下压": Entry(english: "Cable Triceps Pushdown", chinese: "绳索三头下压"),
    "哑铃臂屈伸": Entry(english: "Overhead Dumbbell Triceps Extension", chinese: "哑铃过头臂屈伸"),
    // Chest (common imports)
    "杠铃卧推": Entry(english: "Barbell Bench Press", chinese: "杠铃卧推"),
    "哑铃卧推": Entry(english: "Dumbbell Bench Press", chinese: "哑铃卧推"),
    "上斜卧推": Entry(english: "Incline Bench Press", chinese: "上斜卧推"),
    "龙门架夹胸": Entry(english: "Cable Chest Fly", chinese: "龙门架夹胸"),
    // Legs (common)
    "杠铃深蹲": Entry(english: "Barbell Back Squat", chinese: "杠铃深蹲"),
    "罗马尼亚硬拉": Entry(english: "Romanian Deadlift", chinese: "罗马尼亚硬拉"),
    "腿举": Entry(english: "Leg Press", chinese: "腿举"),
    "保加利亚分腿蹲": Entry(english: "Bulgarian Split Squat", chinese: "保加利亚分腿蹲")
  ]

  private static let aliasToCanonical: [String: String] = {
    var map: [String: String] = [:]
    for (canonical, _) in entries {
      map[ExerciseTemplate.normalize(canonical)] = canonical
    }
    let aliases: [String: [String]] = [
      "器械推肩": ["器械肩推", "器械坐姿推肩", "坐姿器械推肩"],
      "哑铃推肩": ["坐姿哑铃推肩", "坐姿哑铃肩推", "坐姿推肩"],
      "反向蝴蝶机飞鸟": ["反向飞鸟", "蝴蝶机反向飞鸟", "反向蝴蝶机"],
      "绳索面拉": ["面拉", "龙门架面拉"],
      "单臂下拉": ["单臂高位下拉", "单边高位下拉"],
      "高位下拉": ["宽距正握高位下拉", "宽距高位下拉", "正握高位下拉", "宽握高位下拉"],
      "器械侧平举": ["悍马机侧平举", "悍马侧平举", "hammer机侧平举", "机器侧平举"],
      "哑铃侧平举": ["侧平举"],
      "阿诺德推肩": ["阿诺德"],
      "V把下拉": ["v把下拉"],
      "二头弯举": ["弯举", "哑铃二头弯举"],
      "三头龙门架下压": ["三头下压", "龙门架下压", "绳索下压"]
    ]
    for (canonical, names) in aliases {
      for alias in names {
        map[ExerciseTemplate.normalize(alias)] = canonical
      }
    }
    return map
  }()

  static func entry(for storedName: String) -> Entry? {
    let canonical = canonicalKey(storedName)
    return entries[canonical]
  }

  static func canonicalKey(_ storedName: String) -> String {
    let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }
    let normalized = ExerciseTemplate.normalize(trimmed)
    if let canonical = aliasToCanonical[normalized] {
      return canonical
    }
    if entries[trimmed] != nil { return trimmed }
    return ExerciseNameCatalog.canonicalName(trimmed)
  }

  static func display(_ storedName: String) -> String {
    let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }

    let key = canonicalKey(trimmed)
    let entry = entries[key]

    switch AppSettings.displayLanguage {
    case .english:
      return entry?.english ?? trimmed
    case .chinese:
      return entry?.chinese ?? trimmed
    case .bilingual:
      if let entry {
        return "\(entry.english) · \(entry.chinese)"
      }
      return trimmed
    }
  }
}

enum BodyPartLexicon {
  private static let parts: [String: (english: String, chinese: String)] = [
    "肩": ("Shoulders", "肩"),
    "胸": ("Chest", "胸"),
    "背": ("Back", "背"),
    "腿": ("Legs", "腿"),
    "臂": ("Arms", "臂"),
    "核心": ("Core", "核心"),
    "有氧": ("Cardio", "有氧"),
    "其他": ("Other", "其他")
  ]

  private static let subparts: [String: (english: String, chinese: String)] = [
    "前束": ("Front Delts", "三角肌前束"),
    "中束": ("Side Delts", "三角肌中束"),
    "后束": ("Rear Delts", "三角肌后束"),
    "上胸": ("Upper Chest", "上胸"),
    "中胸": ("Mid Chest", "中胸"),
    "下胸": ("Lower Chest", "下胸"),
    "背宽": ("Lats", "背阔肌"),
    "背厚": ("Mid Back", "中下背"),
    "股四": ("Quads", "股四头肌"),
    "腘绳": ("Hamstrings", "腘绳肌"),
    "臀": ("Glutes", "臀肌"),
    "二头": ("Biceps", "肱二头肌"),
    "三头": ("Triceps", "肱三头肌"),
    "前臂": ("Forearms", "前臂"),
    "腹": ("Abs", "腹直肌"),
    "腰": ("Lower Back", "竖脊肌"),
    "稳态": ("Steady State", "稳态有氧"),
    "间歇": ("Intervals", "间歇有氧"),
    "综合": ("General", "综合")
  ]

  static func display(part: String) -> String {
    let pair = parts[part]
    switch AppSettings.displayLanguage {
    case .english: return pair?.english ?? part
    case .chinese: return pair?.chinese ?? part
    case .bilingual:
      if let pair { return "\(pair.english) · \(pair.chinese)" }
      return part
    }
  }

  static func display(subpart: String) -> String {
    let pair = subparts[subpart]
    switch AppSettings.displayLanguage {
    case .english: return pair?.english ?? subpart
    case .chinese: return pair?.chinese ?? subpart
    case .bilingual:
      if let pair { return "\(pair.english) · \(pair.chinese)" }
      return subpart
    }
  }

  static func display(part: String, subpart: String) -> String {
    let left = display(part: part)
    let right = display(subpart: subpart)
    switch AppSettings.displayLanguage {
    case .english, .chinese:
      return "\(left) / \(right)"
    case .bilingual:
      return "\(left) / \(right)"
    }
  }

  /// Muscle diagram / summary labels (internal Chinese keys → display)
  static func displayMuscleLabel(_ internalLabel: String) -> String {
    if let pair = subparts[internalLabel] {
      switch AppSettings.displayLanguage {
      case .english: return pair.english
      case .chinese: return pair.chinese
      case .bilingual: return "\(pair.english) · \(pair.chinese)"
      }
    }
    let muscleMap: [String: (String, String)] = [
      "上胸": ("Upper Chest", "上胸"),
      "中下胸": ("Mid-Lower Chest", "中下胸"),
      "背部": ("Back", "背部"),
      "臀部": ("Glutes", "臀部"),
      "小臂": ("Forearms", "前臂"),
      "腹部": ("Abs", "腹部"),
      "下背": ("Lower Back", "下背"),
      "有氧": ("Cardio", "有氧"),
      "全身": ("Full Body", "全身")
    ]
    if let pair = muscleMap[internalLabel] {
      switch AppSettings.displayLanguage {
      case .english: return pair.0
      case .chinese: return pair.1
      case .bilingual: return "\(pair.0) · \(pair.1)"
      }
    }
    return internalLabel
  }
}
