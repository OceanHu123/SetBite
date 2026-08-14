import Foundation
import SwiftData

@Model
final class ExerciseSessionLog {
  var id: UUID
  var templateID: UUID
  var exerciseName: String
  var date: Date
  var weightKg: Double
  var sets: Int
  var reps: Int
  var setRepsLog: String = ""
  var completedFully: Bool
  /// 仅当所属训练日「全部完成」时为 true，进阶折线只统计这类记录
  var countsForProgression: Bool = false

  init(
    templateID: UUID,
    exerciseName: String,
    date: Date,
    weightKg: Double,
    sets: Int,
    reps: Int,
    setRepsLog: String = "",
    completedFully: Bool,
    countsForProgression: Bool = false
  ) {
    self.id = UUID()
    self.templateID = templateID
    self.exerciseName = exerciseName
    self.date = Calendar.current.startOfDay(for: date)
    self.weightKg = weightKg
    self.sets = sets
    self.reps = reps
    self.setRepsLog = setRepsLog
    self.completedFully = completedFully
    self.countsForProgression = countsForProgression
  }

  var levelLabel: String {
    let repsPart = WorkoutFormat.sessionRepsLabel(sets: sets, maxReps: reps, setRepsLog: setRepsLog)
    return "\(WorkoutFormat.weight(weightKg)) · \(repsPart)"
  }

  var totalCapacityKg: Double {
    guard weightKg > 0, sets > 0 else { return 0 }
    let loggedReps = Array(perSetReps.prefix(sets))
    if loggedReps.count == sets, loggedReps.allSatisfy({ $0 > 0 }) {
      return loggedReps.reduce(0) { $0 + weightKg * Double($1) }
    }
    return weightKg * Double(sets) * Double(max(reps, 1))
  }

  var perSetReps: [Int] {
    setRepsLog.compactMap { Int(String($0)) }
  }
}
