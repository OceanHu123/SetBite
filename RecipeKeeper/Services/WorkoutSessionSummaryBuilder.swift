import Foundation
import SwiftData

struct WorkoutMuscleHighlight: Identifiable, Hashable {
  let id: String
  let label: String
  let side: Side
  let score: Double
  let isPrimary: Bool

  enum Side: String, Hashable {
    case front
    case back
  }
}

struct WorkoutSessionSummaryData: Equatable, Identifiable {
  let date: Date
  let totalCapacityKg: Double
  let durationSeconds: TimeInterval
  let activeCalories: Double
  let muscleHighlights: [WorkoutMuscleHighlight]
  let exerciseCount: Int

  var id: TimeInterval { date.timeIntervalSince1970 }

  var durationLabel: String {
    let totalMinutes = max(0, Int(durationSeconds / 60))
    if totalMinutes >= 60 {
      let hours = totalMinutes / 60
      let minutes = totalMinutes % 60
      return minutes > 0 ? "\(hours)h\(String(format: "%02d", minutes))m" : "\(hours)h"
    }
    return "\(totalMinutes)分钟"
  }

  var capacityLabel: String {
    guard totalCapacityKg > 0 else { return "—" }
    return String(format: "%.0f", totalCapacityKg)
  }

  var caloriesLabel: String {
    guard activeCalories > 0 else { return "—" }
    return String(Int(activeCalories.rounded()))
  }
}

enum WorkoutSessionSummaryBuilder {
  private struct MuscleKey: Hashable {
    let label: String
    let side: WorkoutMuscleHighlight.Side
  }

  private static let subpartToMuscle: [String: (String, WorkoutMuscleHighlight.Side)] = [
    "上胸": ("上胸", .front),
    "中胸": ("中下胸", .front),
    "下胸": ("中下胸", .front),
    "前束": ("前束", .front),
    "中束": ("中束", .front),
    "后束": ("后束", .back),
    "背宽": ("背部", .back),
    "背厚": ("背部", .back),
    "股四": ("股四", .front),
    "腘绳": ("腘绳", .back),
    "臀": ("臀部", .back),
    "二头": ("二头", .front),
    "三头": ("三头", .back),
    "前臂": ("小臂", .front),
    "腹": ("腹部", .front),
    "腰": ("下背", .back),
    "稳态": ("有氧", .front),
    "间歇": ("有氧", .front),
    "综合": ("全身", .front)
  ]

  static func build(
    dayPlan: WorkoutDayPlan,
    healthDuration: TimeInterval,
    healthCalories: Double,
    in context: ModelContext
  ) -> WorkoutSessionSummaryData {
    var muscleScores: [MuscleKey: Double] = [:]
    var volume: Double = 0

    for exercise in dayPlan.sortedExercises {
      let log = WorkoutStore.sessionLog(for: exercise.templateID, on: dayPlan.date, in: context)
      if let log {
        volume += log.totalCapacityKg
      }

      let template = WorkoutStore.fetchTemplate(id: exercise.templateID, in: context)
      let part = template?.bodyPart ?? ExerciseBodyCatalog.otherPartName
      let subpart = template?.bodySubpart ?? ExerciseBodyCatalog.otherSubpartName
      let mapped = subpartToMuscle[subpart] ?? fallbackMuscle(part: part, subpart: subpart)
      let key = MuscleKey(label: mapped.0, side: mapped.1)
      let setWeight = max(1, Double(log?.sets ?? exercise.targetSets))
      muscleScores[key, default: 0] += setWeight
    }

    let maxScore = muscleScores.values.max() ?? 1
    let highlights = muscleScores
      .map { key, score in
        WorkoutMuscleHighlight(
          id: "\(key.side.rawValue)-\(key.label)",
          label: key.label,
          side: key.side,
          score: score,
          isPrimary: score >= maxScore * 0.75
        )
      }
      .sorted { lhs, rhs in
        if lhs.side != rhs.side { return lhs.side == .front }
        if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
        return lhs.label < rhs.label
      }

    let resolvedDuration = healthDuration > 0 ? healthDuration : dayPlan.cachedHealthDuration
    let resolvedCalories = healthCalories > 0 ? healthCalories : dayPlan.cachedHealthCalories
    let resolvedCapacity = dayPlan.totalVolumeKg > 0 ? dayPlan.totalVolumeKg : volume

    return WorkoutSessionSummaryData(
      date: dayPlan.date,
      totalCapacityKg: resolvedCapacity,
      durationSeconds: resolvedDuration,
      activeCalories: resolvedCalories,
      muscleHighlights: highlights,
      exerciseCount: dayPlan.sortedExercises.count
    )
  }

  private static func fallbackMuscle(
    part: String,
    subpart: String
  ) -> (String, WorkoutMuscleHighlight.Side) {
    switch part {
    case "肩": return ("中束", .front)
    case "胸": return ("中下胸", .front)
    case "背": return ("背部", .back)
    case "腿": return ("股四", .front)
    case "臂": return ("二头", .front)
    case "核心": return ("腹部", .front)
    case "有氧": return ("有氧", .front)
    default: return (subpart.isEmpty ? "全身" : subpart, .front)
    }
  }
}
