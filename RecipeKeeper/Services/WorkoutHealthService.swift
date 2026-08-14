import Foundation
import HealthKit

struct WorkoutHealthDaySummary: Equatable {
  let duration: TimeInterval
  let activeCalories: Double
  let workoutCount: Int
  let workoutName: String

  var isEmpty: Bool {
    duration <= 0 && activeCalories <= 0
  }

  var durationLabel: String {
    let totalMinutes = max(0, Int((duration / 60).rounded()))
    if totalMinutes >= 60 {
      let hours = totalMinutes / 60
      let minutes = totalMinutes % 60
      return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
    }
    return "\(max(totalMinutes, duration > 0 ? 1 : 0))分钟"
  }

  var caloriesLabel: String {
    guard activeCalories > 0 else { return "—" }
    return "\(Int(activeCalories.rounded())) 千卡"
  }
}

enum WorkoutHealthService {
  private static let store = HKHealthStore()

  /// Gym-style sessions commonly started from Apple Watch.
  private static let preferredActivities: Set<HKWorkoutActivityType> = [
    .traditionalStrengthTraining,
    .functionalStrengthTraining,
    .crossTraining,
    .highIntensityIntervalTraining,
    .mixedCardio,
    .coreTraining,
    .flexibility,
    .yoga,
    .pilates,
    .elliptical,
    .rowing,
    .stairs,
    .walking,
    .running,
    .cycling
  ]

  static var isAvailable: Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  private static var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = [HKObjectType.workoutType()]
    if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(energy)
    }
    return types
  }

  static func requestReadAccess() async throws {
    guard isAvailable else { return }
    try await store.requestAuthorization(toShare: [], read: readTypes)
  }

  /// Reads the Watch workout for this training day: duration + active calories.
  static func daySummary(for date: Date) async throws -> WorkoutHealthDaySummary {
    guard isAvailable else { return emptySummary() }

    let calendar = Calendar.current
    let start = calendar.startOfDay(for: date)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
      return emptySummary()
    }

    let workouts = try await fetchWorkouts(from: start, to: end)
    guard let workout = selectPrimaryWorkout(from: workouts) else {
      return emptySummary()
    }

    let calories = try await calories(for: workout)
    return WorkoutHealthDaySummary(
      duration: max(0, workout.duration),
      activeCalories: calories,
      workoutCount: 1,
      workoutName: activityName(workout.workoutActivityType)
    )
  }

  private static func emptySummary() -> WorkoutHealthDaySummary {
    WorkoutHealthDaySummary(duration: 0, activeCalories: 0, workoutCount: 0, workoutName: "")
  }

  private static func selectPrimaryWorkout(from workouts: [HKWorkout]) -> HKWorkout? {
    guard !workouts.isEmpty else { return nil }

    let preferred = workouts.filter { preferredActivities.contains($0.workoutActivityType) }
    let pool = preferred.isEmpty ? workouts : preferred

    // One Watch session for the day: take the longest (main gym block).
    return pool.max(by: { $0.duration < $1.duration })
  }

  private static func fetchWorkouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: .strictStartDate
    )

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: HKObjectType.workoutType(),
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
      }
      store.execute(query)
    }
  }

  private static func calories(for workout: HKWorkout) async throws -> Double {
    if let fromStats = statisticsCalories(from: workout), fromStats > 0 {
      return fromStats
    }
    if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()), energy > 0 {
      return energy
    }
    // Fallback: sum active energy samples overlapping this Watch workout.
    return try await activeEnergy(from: workout.startDate, to: workout.endDate)
  }

  private static func statisticsCalories(from workout: HKWorkout) -> Double? {
    guard let activeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
          let statistics = workout.statistics(for: activeType),
          let sum = statistics.sumQuantity() else {
      return nil
    }
    return sum.doubleValue(for: .kilocalorie())
  }

  private static func activeEnergy(from start: Date, to end: Date) async throws -> Double {
    guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: [.strictStartDate, .strictEndDate]
    )

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        let value = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        continuation.resume(returning: value)
      }
      store.execute(query)
    }
  }

  private static func activityName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .traditionalStrengthTraining: return "传统力量训练"
    case .functionalStrengthTraining: return "功能性力量训练"
    case .crossTraining: return "交叉训练"
    case .highIntensityIntervalTraining: return "高强度间歇"
    case .coreTraining: return "核心训练"
    case .mixedCardio: return "混合有氧"
    case .flexibility: return "柔韧训练"
    case .yoga: return "瑜伽"
    case .pilates: return "普拉提"
    case .walking: return "步行"
    case .running: return "跑步"
    case .cycling: return "骑行"
    case .rowing: return "划船"
    case .elliptical: return "椭圆机"
    case .stairs: return "爬楼"
    default: return "体能训练"
    }
  }
}
