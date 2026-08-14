import Foundation

enum AppSettings {
  private static let apiKeyKey = "deepseek_api_key"
  private static let pantrySeededKey = "default_pantry_seeded"
  private static let exerciseSeedVersionKey = "exercise_library_seed_version"

  static var exerciseLibrarySeedVersion: Int {
    get { UserDefaults.standard.integer(forKey: exerciseSeedVersionKey) }
    set { UserDefaults.standard.set(newValue, forKey: exerciseSeedVersionKey) }
  }

  static var deepSeekAPIKey: String {
    get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
  }

  static var hasAPIKey: Bool {
    !deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  static var hasSeededDefaultPantry: Bool {
    get { UserDefaults.standard.bool(forKey: pantrySeededKey) }
    set { UserDefaults.standard.set(newValue, forKey: pantrySeededKey) }
  }

  private static let weightUnitKey = "weight_unit"

  static var weightUnit: WeightUnit {
    get {
      guard let raw = UserDefaults.standard.string(forKey: weightUnitKey),
            let unit = WeightUnit(rawValue: raw) else {
        return .kg
      }
      return unit
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: weightUnitKey) }
  }

  private static let heightKey = "user_height_cm"

  static var userHeightCm: Double {
    get {
      let value = UserDefaults.standard.double(forKey: heightKey)
      return value > 0 ? value : 175
    }
    set { UserDefaults.standard.set(newValue, forKey: heightKey) }
  }

  private static let trainingProfileKey = "training_profile_notes"

  /// 私人训练偏好，每次 AI 排课都会带上，不累积长对话
  static var trainingProfileNotes: String {
    get { UserDefaults.standard.string(forKey: trainingProfileKey) ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: trainingProfileKey) }
  }

  private static let dailyCarbsTargetKey = "daily_carbs_target_g"
  private static let dailyProteinTargetKey = "daily_protein_target_g"
  private static let dailyFatTargetKey = "daily_fat_target_g"

  static var dailyCarbsTargetG: Double {
    get {
      let value = UserDefaults.standard.double(forKey: dailyCarbsTargetKey)
      return value > 0 ? value : 250
    }
    set { UserDefaults.standard.set(newValue, forKey: dailyCarbsTargetKey) }
  }

  static var dailyProteinTargetG: Double {
    get {
      let value = UserDefaults.standard.double(forKey: dailyProteinTargetKey)
      return value > 0 ? value : 120
    }
    set { UserDefaults.standard.set(newValue, forKey: dailyProteinTargetKey) }
  }

  static var dailyFatTargetG: Double {
    get {
      let value = UserDefaults.standard.double(forKey: dailyFatTargetKey)
      return value > 0 ? value : 60
    }
    set { UserDefaults.standard.set(newValue, forKey: dailyFatTargetKey) }
  }
}

enum WeightUnit: String, CaseIterable, Identifiable {
  case kg
  case jin

  var id: String { rawValue }

  var label: String {
    switch self {
    case .kg: return "kg"
    case .jin: return "斤"
    }
  }

  func toKilograms(_ value: Double) -> Double {
    switch self {
    case .kg: return value
    case .jin: return value * 0.5
    }
  }

  func fromKilograms(_ kg: Double) -> Double {
    switch self {
    case .kg: return kg
    case .jin: return kg * 2
    }
  }
}
