import Foundation
import SwiftData

enum DefaultPantrySeeder {
  static let defaultItems = [
    "大米",
    "面粉",
    "盐",
    "白糖",
    "冰糖",
    "食用油",
    "生抽",
    "老抽",
    "料酒",
    "醋",
    "蚝油",
    "香油",
    "豆瓣酱",
    "番茄酱",
    "鸡精",
    "味精",
    "胡椒粉",
    "花椒",
    "辣椒粉",
    "八角",
    "孜然",
    "芝麻",
    "淀粉",
    "姜",
    "蒜",
    "葱"
  ]

  static func seedIfNeeded(context: ModelContext) {
    let descriptor = FetchDescriptor<PantryItem>()
    let existing = (try? context.fetch(descriptor)) ?? []
    let existingKeys = Set(existing.map { IngredientMatcher.normalize($0.name) })

    var added = false
    for name in defaultItems {
      let key = IngredientMatcher.normalize(name)
      guard !existingKeys.contains(key) else { continue }
      context.insert(PantryItem(name: name))
      added = true
    }

    if added {
      try? context.save()
    }

    if !AppSettings.hasSeededDefaultPantry {
      AppSettings.hasSeededDefaultPantry = true
    }
  }
}
