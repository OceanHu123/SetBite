import Foundation
import SwiftData

enum MacroDailyTargets {
  struct Values: Equatable {
    let carbsG: Double
    let proteinG: Double
    let fatG: Double
    let calories: Double
    let isTrainingDay: Bool

    var dayLabel: String {
      isTrainingDay ? "训练日" : "休息日"
    }

    func grams(for kind: MacroKind) -> Double {
      switch kind {
      case .carbs: return carbsG
      case .protein: return proteinG
      case .fat: return fatG
      }
    }
  }

  /// 当天有训练安排（至少 1 个动作）→ 训练日目标，否则休息日目标。
  static func forDay(date: Date = Date(), in context: ModelContext) -> Values {
    let isTraining = hasTrainingPlan(on: date, in: context)
    return isTraining ? trainingDay : restDay
  }

  static let trainingDay = Values(
    carbsG: 240,
    proteinG: 120,
    fatG: 55,
    calories: 2100,
    isTrainingDay: true
  )

  static let restDay = Values(
    carbsG: 180,
    proteinG: 120,
    fatG: 60,
    calories: 1900,
    isTrainingDay: false
  )

  static func hasTrainingPlan(on date: Date, in context: ModelContext) -> Bool {
    let day = Calendar.current.startOfDay(for: date)
    let descriptor = FetchDescriptor<WorkoutDayPlan>()
    guard let plans = try? context.fetch(descriptor) else { return false }
    return plans.contains { plan in
      Calendar.current.isDate(plan.date, inSameDayAs: day) && !plan.exercises.isEmpty
    }
  }
}
