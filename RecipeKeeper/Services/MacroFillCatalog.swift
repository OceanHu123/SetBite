import Foundation

enum MacroFillCatalog {
  struct Food: Identifiable {
    let name: String
    let macroPer100g: Double
    let pieceGrams: Double?
    let pieceUnit: String?

    var id: String { name }

    init(_ name: String, per100g: Double, pieceGrams: Double? = nil, pieceUnit: String? = nil) {
      self.name = name
      self.macroPer100g = per100g
      self.pieceGrams = pieceGrams
      self.pieceUnit = pieceUnit
    }

    func line(for remainingGrams: Double) -> String {
      let grams = remainingGrams / max(macroPer100g, 0.1) * 100
      let rounded = Self.roundGrams(grams)
      var text = "\(name) \(rounded)g"
      if let pieceGrams, pieceGrams > 0, let pieceUnit {
        let count = grams / pieceGrams
        if count >= 0.4 {
          let shown = count < 1 ? String(format: "%.1f", (count * 2).rounded() / 2) : "\(Int(count.rounded()))"
          text += " (~\(shown) \(pieceUnit))"
        }
      }
      return text
    }

    private static func roundGrams(_ grams: Double) -> Int {
      if grams < 8 { return max(1, Int(grams.rounded())) }
      if grams < 40 { return Int((grams / 5).rounded() * 5) }
      return Int((grams / 10).rounded() * 10)
    }
  }

  static func foods(for kind: MacroKind) -> [Food] {
    switch kind {
    case .carbs:
      return [
        Food("Raw rice", per100g: 78),
        Food("Cooked rice", per100g: 26),
        Food("Raw oats", per100g: 67),
        Food("Banana", per100g: 22, pieceGrams: 120, pieceUnit: "pc"),
        Food("Sweet potato", per100g: 20)
      ]
    case .protein:
      return [
        Food("Raw chicken breast", per100g: 23),
        Food("Cooked chicken breast", per100g: 31),
        Food("Egg", per100g: 13, pieceGrams: 50, pieceUnit: "pc"),
        Food("Firm tofu", per100g: 12),
        Food("Shrimp", per100g: 18)
      ]
    case .fat:
      return [
        Food("Olive oil", per100g: 100, pieceGrams: 14, pieceUnit: "tbsp"),
        Food("Avocado", per100g: 15, pieceGrams: 150, pieceUnit: "pc"),
        Food("Peanuts", per100g: 44),
        Food("Walnuts", per100g: 65),
        Food("Whole milk", per100g: 3.6)
      ]
    }
  }
}
