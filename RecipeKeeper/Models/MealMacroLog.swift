import Foundation
import SwiftData
import SwiftUI

@Model
final class MealMacroLog: Identifiable {
  var id: UUID
  var date: Date
  var foodName: String
  var calories: Double
  var carbsG: Double
  var proteinG: Double
  var fatG: Double
  var note: String
  var imageData: Data?
  var createdAt: Date

  init(
    date: Date = Date(),
    foodName: String,
    calories: Double,
    carbsG: Double,
    proteinG: Double,
    fatG: Double,
    note: String = "",
    imageData: Data? = nil
  ) {
    self.id = UUID()
    self.date = date
    self.foodName = foodName
    self.calories = calories
    self.carbsG = carbsG
    self.proteinG = proteinG
    self.fatG = fatG
    self.note = note
    self.imageData = imageData
    self.createdAt = Date()
  }
}

enum MacroKind: String, CaseIterable, Identifiable {
  case carbs
  case protein
  case fat

  var id: String { rawValue }

  var title: String {
    switch self {
    case .carbs: return "Carbs"
    case .protein: return "Protein"
    case .fat: return "Fat"
    }
  }

  var shortTitle: String {
    switch self {
    case .carbs: return "C"
    case .protein: return "P"
    case .fat: return "F"
    }
  }

  var chartColor: Color {
    switch self {
    case .carbs: return Color(red: 0.95, green: 0.62, blue: 0.22)
    case .protein: return Color(red: 0.30, green: 0.55, blue: 0.92)
    case .fat: return Color(red: 0.92, green: 0.38, blue: 0.48)
    }
  }
}
