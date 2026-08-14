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
          text += "（约 \(shown)\(pieceUnit)）"
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
        Food("生大米", per100g: 78),
        Food("熟米饭", per100g: 26),
        Food("生燕麦片", per100g: 67),
        Food("香蕉", per100g: 22, pieceGrams: 120, pieceUnit: "根"),
        Food("红薯", per100g: 20)
      ]
    case .protein:
      return [
        Food("生鸡胸肉", per100g: 23),
        Food("熟鸡胸肉", per100g: 31),
        Food("鸡蛋", per100g: 13, pieceGrams: 50, pieceUnit: "个"),
        Food("北豆腐", per100g: 12),
        Food("虾仁", per100g: 18)
      ]
    case .fat:
      return [
        Food("橄榄油", per100g: 100, pieceGrams: 14, pieceUnit: "勺"),
        Food("牛油果", per100g: 15, pieceGrams: 150, pieceUnit: "个"),
        Food("花生", per100g: 44),
        Food("核桃", per100g: 65),
        Food("全脂牛奶", per100g: 3.6)
      ]
    }
  }
}
