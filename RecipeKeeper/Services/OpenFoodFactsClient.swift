import Foundation

struct PackagedNutrition: Equatable {
  let productName: String
  let brands: String
  let caloriesPer100g: Double
  let carbsPer100g: Double
  let proteinPer100g: Double
  let fatPer100g: Double
  let servingGrams: Double?

  var displayName: String {
    let brand = brands.trimmingCharacters(in: .whitespacesAndNewlines)
    if brand.isEmpty || productName.localizedCaseInsensitiveContains(brand) {
      return productName
    }
    return "\(brand) \(productName)"
  }

  func scaled(grams: Double) -> (calories: Double, carbsG: Double, proteinG: Double, fatG: Double) {
    let factor = max(grams, 0) / 100
    return (
      caloriesPer100g * factor,
      carbsPer100g * factor,
      proteinPer100g * factor,
      fatPer100g * factor
    )
  }
}

actor OpenFoodFactsClient {
  private let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 12
    config.timeoutIntervalForResource = 16
    config.waitsForConnectivity = true
    return URLSession(configuration: config)
  }()

  func searchBest(query: String) async -> PackagedNutrition? {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else { return nil }

    async let cn = search(host: "cn.openfoodfacts.org", query: trimmed)
    async let world = search(host: "world.openfoodfacts.org", query: trimmed)
    let combined = ((try? await cn) ?? []) + ((try? await world) ?? [])
    return pickBest(from: combined, query: trimmed)
  }

  private func search(host: String, query: String) async throws -> [PackagedNutrition] {
    var components = URLComponents(string: "https://\(host)/cgi/search.pl")!
    components.queryItems = [
      URLQueryItem(name: "search_terms", value: query),
      URLQueryItem(name: "search_simple", value: "1"),
      URLQueryItem(name: "action", value: "process"),
      URLQueryItem(name: "json", value: "1"),
      URLQueryItem(name: "page_size", value: "8")
    ]
    guard let url = components.url else { return [] }

    var request = URLRequest(url: url)
    request.setValue(
      "SetBite/1.0 (iOS; calorie lookup; https://world.openfoodfacts.org)",
      forHTTPHeaderField: "User-Agent"
    )

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      return []
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let products = json["products"] as? [[String: Any]] else {
      return []
    }
    return products.compactMap(parseProduct)
  }

  private func parseProduct(_ json: [String: Any]) -> PackagedNutrition? {
    let name = firstNonEmpty(
      json["product_name_zh"] as? String,
      json["product_name"] as? String,
      json["generic_name_zh"] as? String,
      json["generic_name"] as? String
    )
    guard !name.isEmpty else { return nil }

    let nutriments = json["nutriments"] as? [String: Any] ?? [:]
    let calories = nutrient(nutriments, keys: ["energy-kcal_100g", "energy-kcal", "energy_kcal_100g"])
      ?? kjToKcal(nutrient(nutriments, keys: ["energy-kj_100g", "energy_100g"]))
    guard let calories, calories > 0 else { return nil }

    return PackagedNutrition(
      productName: name,
      brands: (json["brands"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
      caloriesPer100g: calories,
      carbsPer100g: nutrient(nutriments, keys: ["carbohydrates_100g"]) ?? 0,
      proteinPer100g: nutrient(nutriments, keys: ["proteins_100g"]) ?? 0,
      fatPer100g: nutrient(nutriments, keys: ["fat_100g"]) ?? 0,
      servingGrams: nutrient(json, keys: ["serving_quantity"]) ?? servingGrams(from: json["serving_size"] as? String)
    )
  }

  private func pickBest(from products: [PackagedNutrition], query: String) -> PackagedNutrition? {
    let scored = products.compactMap { product -> (PackagedNutrition, Int)? in
      let score = relevanceScore(product, query: query)
      guard score >= 8 else { return nil }
      return (product, score)
    }
    return scored.max(by: { $0.1 < $1.1 })?.0
  }

  private func relevanceScore(_ product: PackagedNutrition, query: String) -> Int {
    let q = normalize(query)
    let name = normalize(product.productName)
    let brand = normalize(product.brands)
    let haystack = name + brand
    guard q.count >= 2, haystack.count >= 2 else { return 0 }

    var score = 0
    if haystack.contains(q) || (name.count >= 2 && q.contains(name)) {
      score += 10
    } else if brand.count >= 2, haystack.contains(brand), q.contains(brand) {
      score += 8
    } else {
      return 0
    }

    if product.caloriesPer100g > 0 { score += 3 }
    if product.carbsPer100g > 0 || product.proteinPer100g > 0 || product.fatPer100g > 0 { score += 2 }
    if !product.brands.isEmpty { score += 1 }
    return score
  }

  private func normalize(_ text: String) -> String {
    text.lowercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
      .replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: "·", with: "")
  }

  private func firstNonEmpty(_ values: String?...) -> String {
    for value in values {
      let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !trimmed.isEmpty { return trimmed }
    }
    return ""
  }

  private func nutrient(_ json: [String: Any], keys: [String]) -> Double? {
    for key in keys {
      if let number = json[key] as? Double { return number }
      if let number = json[key] as? Int { return Double(number) }
      if let number = json[key] as? NSNumber { return number.doubleValue }
      if let text = json[key] as? String, let number = Double(text) { return number }
    }
    return nil
  }

  private func kjToKcal(_ kj: Double?) -> Double? {
    guard let kj, kj > 0 else { return nil }
    return kj / 4.184
  }

  private func servingGrams(from size: String?) -> Double? {
    guard let size else { return nil }
    let pattern = /(?<value>\d+(?:\.\d+)?)\s*(?<unit>g|克|ml|毫升|mL|ML)/
    guard let match = size.firstMatch(of: pattern),
          let value = Double(match.output.value) else { return nil }
    return value
  }
}
