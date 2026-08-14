import Foundation
import SwiftData

@Model
final class Recipe: Identifiable {
  var id: UUID
  var title: String
  var ingredientNames: [String]
  var ingredientAmounts: [String]
  var steps: [String]
  var rawOCRText: String
  var sourceNote: String
  var coverImageData: Data?
  var categories: [String]
  var createdAt: Date
  var toCookAddedAt: Date?

  init(
    title: String,
    ingredients: [ParsedIngredient],
    steps: [String],
    rawOCRText: String = "",
    sourceNote: String = "",
    coverImageData: Data? = nil,
    categories: [String] = []
  ) {
    self.id = UUID()
    self.title = title
    self.ingredientNames = ingredients.map(\.name)
    self.ingredientAmounts = ingredients.map(\.amount)
    self.steps = steps
    self.rawOCRText = rawOCRText
    self.sourceNote = sourceNote
    self.coverImageData = coverImageData
    self.categories = categories
    self.createdAt = Date()
    self.toCookAddedAt = nil
  }

  var effectiveCategories: [String] {
    if categories.isEmpty {
      return RecipeCategoryCatalog.infer(title: title, ingredients: parsedIngredients)
    }
    return categories
  }

  var isInToCook: Bool {
    toCookAddedAt != nil
  }

  var parsedIngredients: [ParsedIngredient] {
    zip(ingredientNames, ingredientAmounts).map { ParsedIngredient(name: $0.0, amount: $0.1) }
  }

  var ingredientLines: [String] {
    parsedIngredients.map { item in
      item.amount.isEmpty ? item.name : "\(item.name) \(item.amount)"
    }
  }
}

@Model
final class CookingLog: Identifiable {
  var id: UUID
  var date: Date
  var recipeID: UUID
  var recipeTitle: String
  var createdAt: Date

  init(recipe: Recipe, date: Date = Date()) {
    self.id = UUID()
    self.date = Calendar.current.startOfDay(for: date)
    self.recipeID = recipe.id
    self.recipeTitle = recipe.title
    self.createdAt = Date()
  }
}

enum RecipeCategoryCatalog {
  static let all = ["烘焙", "素菜", "肉菜", "海鲜", "汤羹", "主食", "小吃", "其他"]

  static func infer(title: String, ingredients: [ParsedIngredient]) -> [String] {
    let text = ([title] + ingredients.map(\.name)).joined(separator: " ")
    let normalized = text.lowercased()
    var matched: [String] = []

    if containsAny(normalized, keywords: ["蛋糕", "面包", "曲奇", "饼干", "蛋挞", "司康", "烘焙", "吐司", "戚风", "慕斯", "泡芙"]) {
      matched.append("烘焙")
    }
    if containsAny(normalized, keywords: ["汤", "羹", "炖", "煲"]) {
      matched.append("汤羹")
    }
    if containsAny(normalized, keywords: ["饭", "面", "粉", "粥", "饺子", "馄饨", "馒头", "意面", "拉面", "米饭"]) {
      matched.append("主食")
    }
    if containsAny(normalized, keywords: ["鱼", "虾", "蟹", "贝", "蚝", "鱿鱼", "海鲜", "带鱼", "三文鱼", "蛤蜊"]) {
      matched.append("海鲜")
    }
    if containsAny(normalized, keywords: ["猪", "牛", "羊", "鸡", "鸭", "肉", "排骨", "培根", "里脊", "五花", "牛排"]) {
      matched.append("肉菜")
    }
    if containsAny(normalized, keywords: ["小吃", "零食", "炸", "串", "春卷", "锅贴"]) {
      matched.append("小吃")
    }
    if containsAny(normalized, keywords: ["素", "蔬菜", "豆腐", "菌", "蘑菇", "青菜", "时蔬"])
      && !matched.contains("肉菜")
      && !matched.contains("海鲜") {
      matched.append("素菜")
    }

    if matched.isEmpty {
      matched.append("其他")
    }
    return matched
  }

  static func matchesIngredient(_ recipe: Recipe, query: String) -> Bool {
    let q = IngredientMatcher.normalize(query)
    guard !q.isEmpty else { return true }
    if IngredientMatcher.normalize(recipe.title).contains(q) { return true }
    return recipe.ingredientNames.contains {
      IngredientMatcher.normalize($0).contains(q)
    }
  }

  private static func containsAny(_ text: String, keywords: [String]) -> Bool {
    keywords.contains { text.contains($0) }
  }
}

enum CookingStore {
  static func markCooked(_ recipe: Recipe, on date: Date = Date(), in context: ModelContext) {
    context.insert(CookingLog(recipe: recipe, date: date))
    recipe.toCookAddedAt = nil
    try? context.save()
  }

  static func logs(on day: Date, in logs: [CookingLog]) -> [CookingLog] {
    logs.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
      .sorted { $0.createdAt > $1.createdAt }
  }

  static func deleteLogs(for recipeID: UUID, in context: ModelContext) {
    let descriptor = FetchDescriptor<CookingLog>()
    guard let logs = try? context.fetch(descriptor) else { return }
    for log in logs where log.recipeID == recipeID {
      context.delete(log)
    }
    try? context.save()
  }

  static func rescheduleLog(_ log: CookingLog, to date: Date, in context: ModelContext) {
    log.date = Calendar.current.startOfDay(for: date)
    try? context.save()
  }
}

@Model
final class ShoppingItem: Identifiable {
  var id: UUID
  var ingredientName: String
  var amount: String
  var recipeTitle: String
  var recipeID: UUID?
  var isPurchased: Bool
  var createdAt: Date

  init(
    ingredientName: String,
    amount: String,
    recipeTitle: String,
    recipeID: UUID? = nil
  ) {
    self.id = UUID()
    self.ingredientName = ingredientName
    self.amount = amount
    self.recipeTitle = recipeTitle
    self.recipeID = recipeID
    self.isPurchased = false
    self.createdAt = Date()
  }

  var displayTitle: String {
    amount.isEmpty ? ingredientName : "\(ingredientName) · \(amount)"
  }
}

@Model
final class PantryItem: Identifiable {
  var id: UUID
  var name: String
  var createdAt: Date

  init(name: String) {
    self.id = UUID()
    self.name = name
    self.createdAt = Date()
  }
}

enum IngredientMatcher {
  static func normalize(_ text: String) -> String {
    text
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
  }

  static func isPantryItem(_ ingredientName: String, pantryItems: [PantryItem]) -> Bool {
    let normalized = normalize(ingredientName)
    return pantryItems.contains { normalize($0.name) == normalized }
  }
}
