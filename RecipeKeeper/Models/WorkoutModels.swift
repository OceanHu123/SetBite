import Foundation
import SwiftData

@Model
final class WorkoutWeekPlan {
  var id: UUID
  var weekStart: Date
  @Relationship(deleteRule: .cascade, inverse: \WorkoutDayPlan.weekPlan)
  var dayPlans: [WorkoutDayPlan]

  init(weekStart: Date) {
    self.id = UUID()
    self.weekStart = WorkoutCalendar.startOfWeek(for: weekStart)
    self.dayPlans = []
  }
}

@Model
final class WorkoutDayPlan {
  var id: UUID
  var date: Date
  var weekPlan: WorkoutWeekPlan?
  @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.dayPlan)
  var exercises: [WorkoutExercise]
  /// 当天全部动作做完后写入；折线图只统计此状态下的记录
  var sessionCompletedAt: Date?
  var aiSessionSummary: String?
  var totalVolumeKg: Double = 0
  var cachedHealthDuration: TimeInterval = 0
  var cachedHealthCalories: Double = 0

  init(date: Date) {
    self.id = UUID()
    self.date = Calendar.current.startOfDay(for: date)
    self.exercises = []
    self.sessionCompletedAt = nil
    self.aiSessionSummary = nil
    self.totalVolumeKg = 0
    self.cachedHealthDuration = 0
    self.cachedHealthCalories = 0
  }

  var sortedExercises: [WorkoutExercise] {
    exercises.sorted { $0.sortOrder < $1.sortOrder }
  }

  var isSessionComplete: Bool {
    sessionCompletedAt != nil
  }
}

/// 动作库：上限只在这里设置一次，level 随记录自动更新
@Model
final class ExerciseTemplate {
  var id: UUID
  var name: String
  var nameKey: String
  var bodyPart: String = "其他"
  var bodySubpart: String = "综合"
  var maxSets: Int
  var maxReps: Int
  var weightKg: Double
  var targetSets: Int
  var targetReps: Int
  var lastWeightKg: Double
  var lastSets: Int
  var lastReps: Int
  var lastCompletedFully: Bool
  var lastSessionDate: Date?
  var isCardio: Bool
  var createdAt: Date

  init(
    name: String,
    bodyPart: String = ExerciseBodyCatalog.otherPartName,
    bodySubpart: String = ExerciseBodyCatalog.otherSubpartName,
    maxSets: Int,
    maxReps: Int,
    weightKg: Double = 0,
    targetSets: Int = 4,
    targetReps: Int = 10
  ) {
    self.id = UUID()
    self.name = name
    self.nameKey = ExerciseTemplate.normalize(name)
    let normalized = ExerciseBodyCatalog.normalized(part: bodyPart, subpart: bodySubpart)
    self.bodyPart = normalized.0
    self.bodySubpart = normalized.1
    self.maxSets = maxSets
    self.maxReps = maxReps
    self.weightKg = weightKg
    self.targetSets = targetSets
    self.targetReps = targetReps
    self.lastWeightKg = 0
    self.lastSets = 0
    self.lastReps = 0
    self.lastCompletedFully = false
    self.lastSessionDate = nil
    self.isCardio = normalized.0 == "有氧"
    self.createdAt = Date()
  }

  var effectiveWeightKg: Double {
    lastWeightKg > 0 ? lastWeightKg : weightKg
  }

  var effectiveTargetSets: Int {
    lastSets > 0 ? lastSets : targetSets
  }

  var effectiveTargetReps: Int {
    lastReps > 0 ? lastReps : targetReps
  }

  var maxLabel: String {
    WorkoutFormat.targetSchemeLabel(
      sets: maxSets,
      minReps: targetReps,
      maxReps: maxReps,
      failureNote: maxReps <= 0 ? "力竭" : nil
    )
  }

  var lastRecordLabel: String {
    let w = effectiveWeightKg
    guard w > 0 else { return "暂无记录" }
    let sets = effectiveTargetSets
    let reps = effectiveTargetReps
    guard lastSessionDate != nil else {
      return "\(WorkoutFormat.weight(w)) \(sets)×\(reps)"
    }
    let status = lastCompletedFully ? "做满" : "没做满"
    return "\(WorkoutFormat.weight(w)) \(sets)×\(reps) · \(status)"
  }

  var readyToProgress: Bool {
    guard !isCardio else { return false }
    return lastCompletedFully && lastSets >= maxSets && lastReps >= maxReps
  }

  var categoryLabel: String {
    "\(bodyPart) · \(bodySubpart)"
  }

  static func normalize(_ name: String) -> String {
    name
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "　", with: "")
  }

  func mergeSession(from exercise: WorkoutExercise) {
    guard let exerciseDate = exercise.lastSessionDate else { return }
    if let templateDate = lastSessionDate, exerciseDate <= templateDate { return }
    weightKg = exercise.weightKg
    targetSets = exercise.targetSets
    targetReps = exercise.targetReps
    lastWeightKg = exercise.lastWeightKg
    lastSets = exercise.lastSets
    lastReps = exercise.lastReps
    lastCompletedFully = exercise.lastCompletedFully
    lastSessionDate = exercise.lastSessionDate
  }
}

@Model
final class WorkoutExercise {
  var id: UUID
  var templateID: UUID
  var name: String
  var sortOrder: Int
  var weightKg: Double
  var targetSets: Int
  var targetReps: Int
  var maxSets: Int
  var maxReps: Int
  var lastWeightKg: Double
  var lastSets: Int
  var lastReps: Int
  var lastCompletedFully: Bool
  var lastSessionDate: Date?
  var isCardio: Bool
  var lastSetRepsLog: String = ""
  var restSeconds: Int = 90
  var sessionNotes: String = ""
  var dayPlan: WorkoutDayPlan?

  init(from template: ExerciseTemplate, sortOrder: Int) {
    self.id = UUID()
    self.templateID = template.id
    self.name = template.name
    self.sortOrder = sortOrder
    self.weightKg = template.effectiveWeightKg
    self.targetSets = template.effectiveTargetSets
    self.targetReps = template.effectiveTargetReps
    self.maxSets = template.maxSets
    self.maxReps = template.maxReps
    self.lastWeightKg = template.lastWeightKg
    self.lastSets = template.lastSets
    self.lastReps = template.lastReps
    self.lastCompletedFully = template.lastCompletedFully
    self.lastSessionDate = template.lastSessionDate
    self.isCardio = template.isCardio
    self.restSeconds = 90
    self.sessionNotes = ""
  }

  var hasSessionNotes: Bool {
    !sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var maxLabel: String {
    let failureNote = maxReps <= 0
      ? (sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "力竭" : sessionNotes)
      : nil
    return WorkoutFormat.targetSchemeLabel(
      sets: maxSets,
      minReps: targetReps,
      maxReps: maxReps,
      failureNote: failureNote
    )
  }

  var lastRecordLabel: String {
    let w = lastWeightKg > 0 ? lastWeightKg : weightKg
    guard w > 0 else { return "暂无记录" }
    let sets = lastSets > 0 ? lastSets : targetSets
    let reps = lastReps > 0 ? lastReps : targetReps
    guard lastSessionDate != nil else {
      return "\(WorkoutFormat.weight(w)) \(sets)×\(reps)"
    }
    let status = lastCompletedFully ? "做满" : "没做满"
    let repsPart = WorkoutFormat.sessionRepsLabel(
      sets: lastSets,
      maxReps: maxReps > 0 ? maxReps : lastReps,
      setRepsLog: lastSetRepsLog
    )
    return "\(WorkoutFormat.weight(lastWeightKg)) \(repsPart) · \(status)"
  }

  var readyToProgress: Bool {
    guard !isCardio else { return false }
    return lastCompletedFully && lastSets >= maxSets
  }

  func isCompleted(on planDate: Date) -> Bool {
    guard let lastSessionDate else { return false }
    return Calendar.current.isDate(lastSessionDate, inSameDayAs: planDate)
  }

  func syncFromTemplate(_ template: ExerciseTemplate) {
    name = template.name
    weightKg = template.effectiveWeightKg
    targetSets = template.effectiveTargetSets
    targetReps = template.effectiveTargetReps
    maxSets = template.maxSets
    maxReps = template.maxReps
    lastWeightKg = template.lastWeightKg
    lastSets = template.lastSets
    lastReps = template.lastReps
    lastCompletedFully = template.lastCompletedFully
    lastSessionDate = template.lastSessionDate
    isCardio = template.isCardio
  }
}

enum WorkoutCalendar {
  static func startOfWeek(for date: Date) -> Date {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
      ?? calendar.startOfDay(for: date)
  }

  static func daysInWeek(starting weekStart: Date) -> [Date] {
    (0..<7).compactMap { offset in
      Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
    }
  }

  static func weekRangeLabel(for weekStart: Date) -> String {
    let days = daysInWeek(starting: weekStart)
    guard let first = days.first, let last = days.last else { return "" }
    let start = first.formatted(.dateTime.month(.defaultDigits).day())
    let end = last.formatted(.dateTime.month(.defaultDigits).day())
    return "\(start) – \(end)"
  }
}

enum WorkoutFormat {
  static func weight(_ kg: Double) -> String {
    if kg.truncatingRemainder(dividingBy: 1) == 0 {
      return String(format: "%.0fkg", kg)
    }
    return String(format: "%.1fkg", kg)
  }

  static func plannedSetsReps(sets: Int, minReps: Int, maxReps: Int, failureNote: String? = nil) -> String {
    if maxReps <= 0 {
      let tag = failureNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? failureNote!.trimmingCharacters(in: .whitespacesAndNewlines)
        : "力竭"
      return "\(sets)组×\(tag)"
    }
    if minReps != maxReps, maxReps > 0 {
      return "\(sets)组×\(minReps)-\(maxReps)次"
    }
    return "\(sets)×\(maxReps > 0 ? maxReps : minReps)"
  }

  static func targetSchemeLabel(
    sets: Int,
    minReps: Int,
    maxReps: Int,
    failureNote: String? = nil
  ) -> String {
    "目标 \(plannedSetsReps(sets: sets, minReps: minReps, maxReps: maxReps, failureNote: failureNote))"
  }

  static func sessionRepsLabel(sets: Int, maxReps: Int, setRepsLog: String) -> String {
    if setRepsLog.isEmpty {
      return "\(sets)×\(maxReps)"
    }
    return "\(sets)×\(maxReps)(\(setRepsLog))"
  }
}

enum WorkoutStore {
  static func fetchWeekPlan(for date: Date, in context: ModelContext) -> WorkoutWeekPlan? {
    let start = WorkoutCalendar.startOfWeek(for: date)
    let descriptor = FetchDescriptor<WorkoutWeekPlan>()
    return try? context.fetch(descriptor).first {
      Calendar.current.isDate($0.weekStart, inSameDayAs: start)
    }
  }

  static func weekPlan(for date: Date, in context: ModelContext) -> WorkoutWeekPlan {
    if let existing = fetchWeekPlan(for: date, in: context) {
      return existing
    }
    let plan = WorkoutWeekPlan(weekStart: date)
    context.insert(plan)
    try? context.save()
    return plan
  }

  static func dayPlan(for date: Date, weekPlan: WorkoutWeekPlan, in context: ModelContext) -> WorkoutDayPlan {
    let day = Calendar.current.startOfDay(for: date)
    if let existing = weekPlan.dayPlans.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
      return existing
    }
    let plan = WorkoutDayPlan(date: day)
    plan.weekPlan = weekPlan
    weekPlan.dayPlans.append(plan)
    context.insert(plan)
    try? context.save()
    return plan
  }

  static func allTemplates(in context: ModelContext) -> [ExerciseTemplate] {
    let descriptor = FetchDescriptor<ExerciseTemplate>(sortBy: [SortDescriptor(\.name)])
    return (try? context.fetch(descriptor)) ?? []
  }

  static func fetchTemplate(id: UUID, in context: ModelContext) -> ExerciseTemplate? {
    allTemplates(in: context).first { $0.id == id }
  }

  static func renameTemplate(
    _ template: ExerciseTemplate,
    to newName: String,
    in context: ModelContext
  ) throws {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let newKey = ExerciseTemplate.normalize(trimmed)
    let oldKey = ExerciseTemplate.normalize(template.name)
    if newKey == oldKey {
      template.name = trimmed
      template.nameKey = newKey
      try context.save()
      return
    }

    let templates = allTemplates(in: context)
    if templates.contains(where: { $0.id != template.id && ExerciseTemplate.normalize($0.name) == newKey }) {
      throw NSError(domain: "WorkoutStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "已有同名动作"])
    }

    template.name = trimmed
    template.nameKey = newKey
    renameReferences(for: template.id, newName: trimmed, in: context)
    try context.save()
  }

  static func mergeTemplate(
    source: ExerciseTemplate,
    into target: ExerciseTemplate,
    in context: ModelContext
  ) {
    guard source.id != target.id else { return }
    absorbTemplate(from: source, into: target, in: context)
    context.delete(source)
    try? context.save()
  }

  static func deleteTemplate(_ template: ExerciseTemplate, in context: ModelContext) {
    if let exercises = try? context.fetch(FetchDescriptor<WorkoutExercise>()) {
      for exercise in exercises where exercise.templateID == template.id {
        context.delete(exercise)
      }
    }
    if let logs = try? context.fetch(FetchDescriptor<ExerciseSessionLog>()) {
      for log in logs where log.templateID == template.id {
        context.delete(log)
      }
    }
    context.delete(template)
    try? context.save()
  }

  static func mergeCanonicalDuplicates(in context: ModelContext) {
    let templates = allTemplates(in: context)
    var groups: [String: [ExerciseTemplate]] = [:]
    for template in templates {
      let key = ExerciseNameCatalog.canonicalKey(template.name)
      groups[key, default: []].append(template)
    }

    for (_, group) in groups where group.count > 1 {
      let canonical = ExerciseNameCatalog.canonicalName(group[0].name)
      let keeper = group.first {
        ExerciseTemplate.normalize($0.name) == ExerciseTemplate.normalize(canonical)
      } ?? group.max(by: { lhs, rhs in
        sessionLogs(for: lhs.id, in: context).count < sessionLogs(for: rhs.id, in: context).count
      }) ?? group[0]

      for duplicate in group where duplicate.id != keeper.id {
        absorbTemplate(from: duplicate, into: keeper, in: context)
        context.delete(duplicate)
      }
      keeper.name = canonical
      keeper.nameKey = ExerciseTemplate.normalize(canonical)
    }

    try? context.save()
  }

  private static func absorbTemplate(
    from source: ExerciseTemplate,
    into target: ExerciseTemplate,
    in context: ModelContext
  ) {
    if let sourceDate = source.lastSessionDate {
      if let targetDate = target.lastSessionDate {
        if sourceDate > targetDate {
          copySessionSummary(from: source, to: target)
        }
      } else {
        copySessionSummary(from: source, to: target)
      }
    }

    if let exercises = try? context.fetch(FetchDescriptor<WorkoutExercise>()) {
      for exercise in exercises where exercise.templateID == source.id {
        exercise.templateID = target.id
        exercise.name = target.name
        exercise.syncFromTemplate(target)
      }
    }

    if let logs = try? context.fetch(FetchDescriptor<ExerciseSessionLog>()) {
      for log in logs where log.templateID == source.id {
        log.templateID = target.id
        log.exerciseName = target.name
      }
    }
  }

  private static func renameReferences(for templateID: UUID, newName: String, in context: ModelContext) {
    if let exercises = try? context.fetch(FetchDescriptor<WorkoutExercise>()) {
      for exercise in exercises where exercise.templateID == templateID {
        exercise.name = newName
      }
    }
    if let logs = try? context.fetch(FetchDescriptor<ExerciseSessionLog>()) {
      for log in logs where log.templateID == templateID {
        log.exerciseName = newName
      }
    }
  }

  private static func copySessionSummary(from source: ExerciseTemplate, to target: ExerciseTemplate) {
    target.lastWeightKg = source.lastWeightKg
    target.lastSets = source.lastSets
    target.lastReps = source.lastReps
    target.lastCompletedFully = source.lastCompletedFully
    target.lastSessionDate = source.lastSessionDate
    if target.weightKg == 0, source.weightKg > 0 {
      target.weightKg = source.weightKg
      target.targetSets = source.targetSets
      target.targetReps = source.targetReps
    }
  }

  static func applySessionLog(
    to exercise: WorkoutExercise,
    template: ExerciseTemplate?,
    weightKg: Double,
    sets: Int,
    reps: Int,
    setRepsLog: String,
    completedFully: Bool,
    sessionDate: Date,
    in context: ModelContext
  ) {
    exercise.lastWeightKg = weightKg
    exercise.lastSets = sets
    exercise.lastReps = reps
    exercise.lastSetRepsLog = setRepsLog
    exercise.lastCompletedFully = completedFully
    exercise.lastSessionDate = sessionDate
    exercise.weightKg = weightKg
    exercise.targetSets = sets
    exercise.targetReps = reps

    if let template {
      template.lastWeightKg = weightKg
      template.lastSets = sets
      template.lastReps = reps
      template.lastCompletedFully = completedFully
      template.lastSessionDate = sessionDate

      upsertSessionLog(
        templateID: template.id,
        exerciseName: template.name,
        sessionDate: sessionDate,
        weightKg: weightKg,
        sets: sets,
        reps: reps,
        setRepsLog: setRepsLog,
        completedFully: completedFully,
        in: context
      )
      syncPlannedExercises(from: template, in: context)
    }
    try? context.save()
  }

  static func syncPlannedExercises(from template: ExerciseTemplate, in context: ModelContext) {
    let descriptor = FetchDescriptor<WorkoutExercise>()
    guard let exercises = try? context.fetch(descriptor) else { return }
    for exercise in exercises where exercise.templateID == template.id {
      guard let planDate = exercise.dayPlan?.date else { continue }
      guard !exercise.isCompleted(on: planDate) else { continue }
      exercise.syncFromTemplate(template)
    }
  }

  static func upsertSessionLog(
    templateID: UUID,
    exerciseName: String,
    sessionDate: Date,
    weightKg: Double,
    sets: Int,
    reps: Int,
    setRepsLog: String,
    completedFully: Bool,
    in context: ModelContext
  ) {
    let day = Calendar.current.startOfDay(for: sessionDate)
    let descriptor = FetchDescriptor<ExerciseSessionLog>()
    let existing = try? context.fetch(descriptor).first {
      $0.templateID == templateID && Calendar.current.isDate($0.date, inSameDayAs: day)
    }
    if let existing {
      existing.exerciseName = exerciseName
      existing.weightKg = weightKg
      existing.sets = sets
      existing.reps = reps
      existing.setRepsLog = setRepsLog
      existing.completedFully = completedFully
      if !isSessionComplete(on: day, in: context) {
        existing.countsForProgression = false
      }
    } else {
      context.insert(
        ExerciseSessionLog(
          templateID: templateID,
          exerciseName: exerciseName,
          date: sessionDate,
          weightKg: weightKg,
          sets: sets,
          reps: reps,
          setRepsLog: setRepsLog,
          completedFully: completedFully,
          countsForProgression: false
        )
      )
    }
    try? context.save()
  }

  static func deleteSessionLogs(
    templateID: UUID,
    on date: Date? = nil,
    in context: ModelContext
  ) {
    let descriptor = FetchDescriptor<ExerciseSessionLog>()
    guard let logs = try? context.fetch(descriptor) else { return }
    for log in logs where log.templateID == templateID {
      if let date {
        guard Calendar.current.isDate(log.date, inSameDayAs: date) else { continue }
      }
      context.delete(log)
    }
    try? context.save()
  }

  static func deleteSessionLog(_ log: ExerciseSessionLog, in context: ModelContext) {
    let templateID = log.templateID
    let deletedDate = log.date
    context.delete(log)
    resyncTemplateSession(templateID: templateID, in: context)

    let exerciseDescriptor = FetchDescriptor<WorkoutExercise>()
    if let exercises = try? context.fetch(exerciseDescriptor) {
      for exercise in exercises where exercise.templateID == templateID {
        guard let lastDate = exercise.lastSessionDate,
              Calendar.current.isDate(lastDate, inSameDayAs: deletedDate) else { continue }
        if let template = fetchTemplate(id: templateID, in: context), let sessionDate = template.lastSessionDate {
          let latestLog = sessionLogs(for: templateID, in: context).last
          exercise.lastWeightKg = template.lastWeightKg
          exercise.lastSets = template.lastSets
          exercise.lastReps = template.lastReps
          exercise.lastSetRepsLog = latestLog?.setRepsLog ?? ""
          exercise.lastCompletedFully = template.lastCompletedFully
          exercise.lastSessionDate = sessionDate
          exercise.weightKg = template.weightKg
        } else {
          exercise.lastWeightKg = 0
          exercise.lastSets = 0
          exercise.lastReps = 0
          exercise.lastSetRepsLog = ""
          exercise.lastCompletedFully = false
          exercise.lastSessionDate = nil
        }
      }
    }

    try? context.save()
  }

  private static func resyncTemplateSession(templateID: UUID, in context: ModelContext) {
    guard let template = fetchTemplate(id: templateID, in: context) else { return }
    let remaining = sessionLogs(for: templateID, in: context)

    guard let latest = remaining.last else {
      template.lastWeightKg = 0
      template.lastSets = 0
      template.lastReps = 0
      template.lastCompletedFully = false
      template.lastSessionDate = nil
      return
    }

    template.lastWeightKg = latest.weightKg
    template.lastSets = latest.sets
    template.lastReps = latest.reps
    template.lastCompletedFully = latest.completedFully
    template.lastSessionDate = latest.date
    syncPlannedExercises(from: template, in: context)
  }

  static func sessionLogs(for templateID: UUID, in context: ModelContext) -> [ExerciseSessionLog] {
    let descriptor = FetchDescriptor<ExerciseSessionLog>(
      sortBy: [SortDescriptor(\.date, order: .forward)]
    )
    return (try? context.fetch(descriptor).filter { $0.templateID == templateID }) ?? []
  }

  static func progressionLogs(for templateID: UUID, in context: ModelContext) -> [ExerciseSessionLog] {
    sessionLogs(for: templateID, in: context).filter(\.countsForProgression)
  }

  static func sessionLog(
    for templateID: UUID,
    on date: Date,
    in context: ModelContext
  ) -> ExerciseSessionLog? {
    let day = Calendar.current.startOfDay(for: date)
    let descriptor = FetchDescriptor<ExerciseSessionLog>()
    return try? context.fetch(descriptor).first {
      $0.templateID == templateID && Calendar.current.isDate($0.date, inSameDayAs: day)
    }
  }

  static func isSessionComplete(on date: Date, in context: ModelContext) -> Bool {
    let day = Calendar.current.startOfDay(for: date)
    let descriptor = FetchDescriptor<WorkoutDayPlan>()
    guard let plans = try? context.fetch(descriptor) else { return false }
    return plans.contains { plan in
      plan.sessionCompletedAt != nil && Calendar.current.isDate(plan.date, inSameDayAs: day)
    }
  }

  @discardableResult
  static func tryCompleteDaySession(
    dayPlan: WorkoutDayPlan,
    healthDuration: TimeInterval = 0,
    healthCalories: Double = 0,
    in context: ModelContext
  ) -> Bool {
    guard dayPlan.sessionCompletedAt == nil else { return false }
    guard !dayPlan.sortedExercises.isEmpty else { return false }

    let day = dayPlan.date
    var volume: Double = 0
    for exercise in dayPlan.sortedExercises {
      if let log = sessionLog(for: exercise.templateID, on: day, in: context) {
        volume += log.totalCapacityKg
        log.countsForProgression = true
      }
    }

    dayPlan.sessionCompletedAt = Date()
    dayPlan.totalVolumeKg = volume
    dayPlan.cachedHealthDuration = healthDuration
    dayPlan.cachedHealthCalories = healthCalories
    try? context.save()
    return true
  }

  static func invalidateDayCompletion(_ dayPlan: WorkoutDayPlan, in context: ModelContext) {
    dayPlan.sessionCompletedAt = nil
    dayPlan.aiSessionSummary = nil
    dayPlan.totalVolumeKg = 0
    dayPlan.cachedHealthDuration = 0
    dayPlan.cachedHealthCalories = 0
    for exercise in dayPlan.sortedExercises {
      if let log = sessionLog(for: exercise.templateID, on: dayPlan.date, in: context) {
        log.countsForProgression = false
      }
    }
    try? context.save()
  }

  static func trainingStreak(endingOn date: Date, in context: ModelContext) -> Int {
    let calendar = Calendar.current
    var streak = 0
    var cursor = calendar.startOfDay(for: date)

    while hasCompletedSession(on: cursor, in: context) {
      streak += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    return streak
  }

  static func hasCompletedSession(on date: Date, in context: ModelContext) -> Bool {
    let descriptor = FetchDescriptor<WorkoutDayPlan>()
    guard let plans = try? context.fetch(descriptor) else { return false }
    return plans.contains { plan in
      plan.sessionCompletedAt != nil && Calendar.current.isDate(plan.date, inSameDayAs: date)
    }
  }

  static func resetDayCompletionMetadata(_ dayPlan: WorkoutDayPlan) {
    dayPlan.sessionCompletedAt = nil
    dayPlan.aiSessionSummary = nil
    dayPlan.totalVolumeKg = 0
    dayPlan.cachedHealthDuration = 0
    dayPlan.cachedHealthCalories = 0
  }

  static func resolveOrCreateTemplate(
    for exercise: GeneratedWorkoutPlan.Exercise,
    templates: inout [ExerciseTemplate],
    in context: ModelContext
  ) -> (template: ExerciseTemplate, isNew: Bool) {
    let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let nameKey = ExerciseTemplate.normalize(trimmedName)
    if let existing = templates.first(where: { ExerciseTemplate.normalize($0.name) == nameKey }) {
      applyImportedScheme(exercise, to: existing)
      return (existing, false)
    }

    let inferred = inferBodyPart(from: trimmedName, templates: templates)
    let preferredBody = preferredBodyClassification(
      part: exercise.bodyPart,
      subpart: exercise.bodySubpart,
      fallback: inferred
    )
    let normalized = ExerciseBodyCatalog.normalized(
      part: preferredBody.part,
      subpart: preferredBody.subpart
    )
    let limits = importedLimits(from: exercise)
    let created = ExerciseTemplate(
      name: trimmedName,
      bodyPart: normalized.0,
      bodySubpart: normalized.1,
      maxSets: limits.maxSets,
      maxReps: limits.maxReps,
      weightKg: 0,
      targetSets: limits.targetSets,
      targetReps: limits.targetReps
    )
    context.insert(created)
    templates.append(created)
    return (created, true)
  }

  private static func inferBodyPart(
    from name: String,
    templates: [ExerciseTemplate]
  ) -> (part: String, subpart: String)? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let sourceTokens = ExerciseNameCatalog.featureTokens(from: trimmed)
    let normalizedSource = ExerciseTemplate.normalize(trimmed)

    func score(_ template: ExerciseTemplate) -> Int {
      let candidate = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !candidate.isEmpty else { return 0 }
      let normalizedCandidate = ExerciseTemplate.normalize(candidate)
      var s = 0
      if normalizedCandidate.contains(normalizedSource) || normalizedSource.contains(normalizedCandidate) { s += 4 }
      let candidateTokens = ExerciseNameCatalog.featureTokens(from: candidate)
      s += sourceTokens.intersection(candidateTokens).count * 2
      return s
    }

    let best = templates
      .map { ($0, score($0)) }
      .filter { $0.1 > 0 }
      .sorted { $0.1 > $1.1 }
      .first?.0

    guard let best else { return nil }
    return (best.bodyPart, best.bodySubpart)
  }

  private static func preferredBodyClassification(
    part: String?,
    subpart: String?,
    fallback: (part: String, subpart: String)?
  ) -> (part: String, subpart: String) {
    let normalizedPart = part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let normalizedSubpart = subpart?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let providedIsUsable =
      !normalizedPart.isEmpty &&
      !(normalizedPart == ExerciseBodyCatalog.otherPartName && normalizedSubpart == ExerciseBodyCatalog.otherSubpartName)

    if providedIsUsable {
      return (normalizedPart, normalizedSubpart)
    }

    if let fallback {
      return fallback
    }

    return (ExerciseBodyCatalog.otherPartName, ExerciseBodyCatalog.otherSubpartName)
  }

  /// 从导入的组数次数解析上限：如 4组×4-6次 → 上限 4×6，目标次数取下限 4
  private static func importedLimits(from item: GeneratedWorkoutPlan.Exercise) -> (maxSets: Int, maxReps: Int, targetSets: Int, targetReps: Int) {
    let sets = max(1, item.targetSets ?? 4)
    if failureIntensityNote(from: item) != nil {
      return (sets, 0, sets, 0)
    }
    let upperReps = max(1, item.maxReps ?? item.minReps ?? 12)
    let lowerReps = max(1, item.minReps ?? item.maxReps ?? upperReps)
    return (sets, upperReps, sets, lowerReps)
  }

  private static func failureIntensityNote(from item: GeneratedWorkoutPlan.Exercise) -> String? {
    let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if notes.contains("接近力竭") { return "接近力竭" }
    if notes.localizedCaseInsensitiveContains("力竭") { return "力竭" }
    if notes.localizedCaseInsensitiveContains("rpe") { return notes }
    return nil
  }

  private static func applyImportedScheme(_ item: GeneratedWorkoutPlan.Exercise, to template: ExerciseTemplate) {
    guard item.targetSets != nil || item.minReps != nil || item.maxReps != nil else { return }
    let limits = importedLimits(from: item)
    template.maxSets = limits.maxSets
    template.maxReps = limits.maxReps
    template.targetSets = limits.targetSets
    template.targetReps = limits.targetReps
  }

  private static func applyImportedScheme(_ item: GeneratedWorkoutPlan.Exercise, to exercise: WorkoutExercise) {
    guard item.targetSets != nil || item.minReps != nil || item.maxReps != nil else { return }
    let limits = importedLimits(from: item)
    exercise.maxSets = limits.maxSets
    exercise.maxReps = limits.maxReps
    exercise.targetSets = limits.targetSets
    exercise.targetReps = limits.targetReps
  }

  @discardableResult
  static func copyPreviousWeek(to targetWeekStart: Date, in context: ModelContext) -> Int {
    guard let previousStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: targetWeekStart),
          let sourcePlan = fetchWeekPlan(for: previousStart, in: context) else {
      return 0
    }

    let targetPlan = weekPlan(for: targetWeekStart, in: context)
    var copiedDays = 0

    for sourceDay in sourcePlan.dayPlans where !sourceDay.exercises.isEmpty {
      let offset = Calendar.current.dateComponents([.day], from: sourcePlan.weekStart, to: sourceDay.date).day ?? 0
      guard let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: targetPlan.weekStart) else {
        continue
      }

      let targetDay = dayPlan(for: targetDate, weekPlan: targetPlan, in: context)
      if !targetDay.exercises.isEmpty { continue }

      for (index, sourceExercise) in sourceDay.sortedExercises.enumerated() {
        let template: ExerciseTemplate
        if let existing = fetchTemplate(id: sourceExercise.templateID, in: context) {
          existing.mergeSession(from: sourceExercise)
          template = existing
        } else {
          let created = ExerciseTemplate(
            name: sourceExercise.name,
            bodyPart: ExerciseBodyCatalog.otherPartName,
            bodySubpart: ExerciseBodyCatalog.otherSubpartName,
            maxSets: sourceExercise.maxSets,
            maxReps: sourceExercise.maxReps,
            weightKg: sourceExercise.weightKg,
            targetSets: sourceExercise.targetSets,
            targetReps: sourceExercise.targetReps
          )
          created.lastWeightKg = sourceExercise.lastWeightKg
          created.lastSets = sourceExercise.lastSets
          created.lastReps = sourceExercise.lastReps
          created.lastCompletedFully = sourceExercise.lastCompletedFully
          created.lastSessionDate = sourceExercise.lastSessionDate
          context.insert(created)
          template = created
        }

        let exercise = WorkoutExercise(from: template, sortOrder: index)
        exercise.targetSets = sourceExercise.targetSets
        exercise.targetReps = sourceExercise.targetReps
        exercise.maxSets = sourceExercise.maxSets
        exercise.maxReps = sourceExercise.maxReps
        exercise.restSeconds = sourceExercise.restSeconds
        exercise.sessionNotes = sourceExercise.sessionNotes
        exercise.dayPlan = targetDay
        targetDay.exercises.append(exercise)
        context.insert(exercise)
      }
      copiedDays += 1
    }

    try? context.save()
    return copiedDays
  }

  @discardableResult
  static func moveDayPlan(from sourceDate: Date, to targetDate: Date, in context: ModelContext) -> Bool {
    let source = Calendar.current.startOfDay(for: sourceDate)
    let target = Calendar.current.startOfDay(for: targetDate)
    guard !Calendar.current.isDate(source, inSameDayAs: target) else { return false }

    let sourceWeek = weekPlan(for: source, in: context)
    let targetWeek = weekPlan(for: target, in: context)
    let sourceDay = dayPlan(for: source, weekPlan: sourceWeek, in: context)
    let targetDay = dayPlan(for: target, weekPlan: targetWeek, in: context)

    let moving = sourceDay.sortedExercises
    guard !moving.isEmpty else { return false }

    var nextOrder = targetDay.exercises.count
    for exercise in moving {
      sourceDay.exercises.removeAll { $0.id == exercise.id }
      exercise.dayPlan = targetDay
      exercise.sortOrder = nextOrder
      targetDay.exercises.append(exercise)
      nextOrder += 1
    }

    if sourceDay.sessionCompletedAt != nil {
      targetDay.sessionCompletedAt = sourceDay.sessionCompletedAt
      targetDay.aiSessionSummary = sourceDay.aiSessionSummary
      targetDay.totalVolumeKg = sourceDay.totalVolumeKg
      targetDay.cachedHealthDuration = sourceDay.cachedHealthDuration
      targetDay.cachedHealthCalories = sourceDay.cachedHealthCalories
      resetDayCompletionMetadata(sourceDay)
    }

    try? context.save()
    return true
  }

  static func clearDayPlan(on date: Date, in context: ModelContext) {
    let day = Calendar.current.startOfDay(for: date)
    let week = weekPlan(for: day, in: context)
    let plan = dayPlan(for: day, weekPlan: week, in: context)
    clearDayExercises(plan, in: context)
    try? context.save()
  }

  @discardableResult
  static func applyGeneratedPlan(
    _ plan: GeneratedWorkoutPlan,
    to weekStart: Date,
    clearWholeWeek: Bool,
    in context: ModelContext
  ) -> ApplyPlanResult {
    let weekPlan = weekPlan(for: weekStart, in: context)
    var templates = allTemplates(in: context)
    var newExercisesCreated: [String] = []
    var daysApplied = 0
    var exercisesAdded = 0

    if clearWholeWeek {
      clearWeekPlan(weekPlan, in: context)
    }

    let groupedDays = Dictionary(grouping: plan.days, by: \.weekdayIndex)

    for weekdayIndex in groupedDays.keys.sorted() {
      guard (0..<7).contains(weekdayIndex) else { continue }
      guard let dayGroups = groupedDays[weekdayIndex],
            let targetDate = Calendar.current.date(byAdding: .day, value: weekdayIndex, to: weekPlan.weekStart) else {
        continue
      }

      let targetDay = dayPlan(for: targetDate, weekPlan: weekPlan, in: context)
      if !clearWholeWeek {
        clearDayExercises(targetDay, in: context)
      }

      var nextOrder = 0
      var addedOnDay = 0
      for day in dayGroups {
        for item in day.exercises {
          let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmedName.isEmpty else { continue }

          let resolved = resolveOrCreateTemplate(
            for: GeneratedWorkoutPlan.Exercise(
              name: trimmedName,
              bodyPart: item.bodyPart,
              bodySubpart: item.bodySubpart,
              restSeconds: item.restSeconds,
              notes: item.notes,
              targetSets: item.targetSets,
              minReps: item.minReps,
              maxReps: item.maxReps
            ),
            templates: &templates,
            in: context
          )
          if resolved.isNew, !newExercisesCreated.contains(resolved.template.name) {
            newExercisesCreated.append(resolved.template.name)
          }

          let exercise = WorkoutExercise(from: resolved.template, sortOrder: nextOrder)
          applyImportedScheme(item, to: exercise)
          exercise.restSeconds = item.restSeconds ?? 90
          exercise.sessionNotes = item.notes ?? ""
          exercise.dayPlan = targetDay
          targetDay.exercises.append(exercise)
          context.insert(exercise)
          nextOrder += 1
          addedOnDay += 1
          exercisesAdded += 1
        }
      }

      if addedOnDay > 0 { daysApplied += 1 }
    }

    try? context.save()
    return ApplyPlanResult(
      daysApplied: daysApplied,
      exercisesAdded: exercisesAdded,
      newExercisesCreated: newExercisesCreated
    )
  }

  private static func clearDayExercises(_ dayPlan: WorkoutDayPlan, in context: ModelContext) {
    for exercise in dayPlan.exercises {
      if let log = sessionLog(for: exercise.templateID, on: dayPlan.date, in: context) {
        log.countsForProgression = false
      }
      context.delete(exercise)
    }
    dayPlan.exercises.removeAll()
    resetDayCompletionMetadata(dayPlan)
    try? context.save()
  }

  private static func clearWeekPlan(_ weekPlan: WorkoutWeekPlan, in context: ModelContext) {
    for offset in 0..<7 {
      guard let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: weekPlan.weekStart) else {
        continue
      }
      clearDayExercises(dayPlan(for: targetDate, weekPlan: weekPlan, in: context), in: context)
    }
  }
}

struct ApplyPlanResult: Equatable {
  let daysApplied: Int
  let exercisesAdded: Int
  let newExercisesCreated: [String]
}
