import Foundation
import SwiftData

enum DefaultExerciseSeeder {
  static let seedVersion = 2

  private struct Seed {
    let name: String
    let bodyPart: String
    let bodySubpart: String
    let weightKg: Double
    let sets: Int
    let reps: Int
    let maxSets: Int
    let maxReps: Int
    let completedFully: Bool
  }

  /// 用户当前训练数据；更新此列表后递增 `seedVersion`
  private static let seeds: [Seed] = [
    // 肩 + 三头
    Seed(name: "哑铃推肩", bodyPart: "肩", bodySubpart: "前束", weightKg: 7, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "阿诺德推肩", bodyPart: "肩", bodySubpart: "前束", weightKg: 5, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "器械推肩", bodyPart: "肩", bodySubpart: "前束", weightKg: 5, sets: 4, reps: 8, maxSets: 4, maxReps: 8, completedFully: false),
    Seed(name: "哑铃侧平举", bodyPart: "肩", bodySubpart: "中束", weightKg: 4, sets: 4, reps: 15, maxSets: 4, maxReps: 15, completedFully: false),
    Seed(name: "器械侧平举", bodyPart: "肩", bodySubpart: "中束", weightKg: 10, sets: 4, reps: 10, maxSets: 4, maxReps: 15, completedFully: false),
    Seed(name: "绳索侧平举", bodyPart: "肩", bodySubpart: "中束", weightKg: 1.25, sets: 3, reps: 8, maxSets: 3, maxReps: 15, completedFully: false),
    Seed(name: "反向蝴蝶机飞鸟", bodyPart: "肩", bodySubpart: "后束", weightKg: 14.5, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: true),
    Seed(name: "绳索面拉", bodyPart: "肩", bodySubpart: "后束", weightKg: 12.5, sets: 4, reps: 8, maxSets: 4, maxReps: 8, completedFully: false),
    Seed(name: "死虫", bodyPart: "核心", bodySubpart: "腹", weightKg: 0, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: false),
    // 背 + 二头 + 核心
    Seed(name: "高位下拉", bodyPart: "背", bodySubpart: "背宽", weightKg: 24, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "单臂下拉", bodyPart: "背", bodySubpart: "背宽", weightKg: 7, sets: 3, reps: 12, maxSets: 3, maxReps: 12, completedFully: true),
    Seed(name: "辅助引体", bodyPart: "背", bodySubpart: "背宽", weightKg: 50, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "对握下拉", bodyPart: "背", bodySubpart: "背宽", weightKg: 27.5, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "V把下拉", bodyPart: "背", bodySubpart: "背宽", weightKg: 18, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: false),
    Seed(name: "坐姿划船", bodyPart: "背", bodySubpart: "背厚", weightKg: 20, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "胸托划船", bodyPart: "背", bodySubpart: "背厚", weightKg: 11.25, sets: 4, reps: 12, maxSets: 4, maxReps: 12, completedFully: true),
    Seed(name: "直臂下压", bodyPart: "背", bodySubpart: "背宽", weightKg: 9.375, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "山羊挺身", bodyPart: "核心", bodySubpart: "腰", weightKg: 0, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: true),
    Seed(name: "悬垂举腿", bodyPart: "核心", bodySubpart: "腹", weightKg: 0, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: false),
    // 腿
    Seed(name: "髋外展机", bodyPart: "腿", bodySubpart: "臀", weightKg: 22.7, sets: 3, reps: 15, maxSets: 3, maxReps: 15, completedFully: false),
    // 手臂
    Seed(name: "二头弯举", bodyPart: "臂", bodySubpart: "二头", weightKg: 5, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: false),
    Seed(name: "锤式弯举", bodyPart: "臂", bodySubpart: "二头", weightKg: 4, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: false),
    Seed(name: "三头龙门架下压", bodyPart: "臂", bodySubpart: "三头", weightKg: 6.875, sets: 4, reps: 10, maxSets: 4, maxReps: 10, completedFully: false),
    Seed(name: "哑铃臂屈伸", bodyPart: "臂", bodySubpart: "三头", weightKg: 4, sets: 3, reps: 10, maxSets: 3, maxReps: 10, completedFully: false)
  ]

  static func seedIfNeeded(context: ModelContext) {
    guard AppSettings.exerciseLibrarySeedVersion < seedVersion else { return }

    let baselineDate = Calendar.current.startOfDay(
      for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    )
    var templates = WorkoutStore.allTemplates(in: context)

    for seed in seeds {
      upsert(seed, baselineDate: baselineDate, templates: &templates, in: context)
    }

    AppSettings.exerciseLibrarySeedVersion = seedVersion
    try? context.save()
  }

  /// 从计划或文本导入单条动作；已存在则按最新数据覆盖目标与上次记录
  static func importExercise(
    name: String,
    bodyPart: String,
    bodySubpart: String,
    weightKg: Double,
    sets: Int,
    reps: Int,
    maxSets: Int,
    maxReps: Int,
    completedFully: Bool,
    context: ModelContext
  ) {
    let seed = Seed(
      name: ExerciseNameCatalog.canonicalName(name),
      bodyPart: bodyPart,
      bodySubpart: bodySubpart,
      weightKg: weightKg,
      sets: sets,
      reps: reps,
      maxSets: maxSets,
      maxReps: maxReps,
      completedFully: completedFully
    )
    var templates = WorkoutStore.allTemplates(in: context)
    upsert(
      seed,
      baselineDate: Calendar.current.startOfDay(for: Date()),
      templates: &templates,
      in: context
    )
    try? context.save()
  }

  private static func upsert(
    _ seed: Seed,
    baselineDate: Date,
    templates: inout [ExerciseTemplate],
    in context: ModelContext
  ) {
    let normalized = ExerciseBodyCatalog.normalized(part: seed.bodyPart, subpart: seed.bodySubpart)
    let canonicalName = ExerciseNameCatalog.canonicalName(seed.name)

    if let existing = ExerciseNameCatalog.findTemplate(named: canonicalName, in: templates) {
      apply(seed, to: existing, baselineDate: baselineDate)
      WorkoutStore.syncPlannedExercises(from: existing, in: context)
      return
    }

    let template = ExerciseTemplate(
      name: canonicalName,
      bodyPart: normalized.0,
      bodySubpart: normalized.1,
      maxSets: seed.maxSets,
      maxReps: seed.maxReps,
      weightKg: seed.weightKg,
      targetSets: seed.sets,
      targetReps: seed.reps
    )
    applyLastRecord(seed, to: template, baselineDate: baselineDate)
    context.insert(template)
    templates.append(template)
  }

  private static func apply(_ seed: Seed, to template: ExerciseTemplate, baselineDate: Date) {
    template.maxSets = seed.maxSets
    template.maxReps = seed.maxReps
    template.bodyPart = ExerciseBodyCatalog.normalized(part: seed.bodyPart, subpart: seed.bodySubpart).0
    template.bodySubpart = ExerciseBodyCatalog.normalized(part: seed.bodyPart, subpart: seed.bodySubpart).1
    applyLastRecord(seed, to: template, baselineDate: baselineDate)
  }

  private static func applyLastRecord(_ seed: Seed, to template: ExerciseTemplate, baselineDate: Date) {
    template.weightKg = seed.weightKg
    template.targetSets = seed.sets
    template.targetReps = seed.reps
    template.lastWeightKg = seed.weightKg
    template.lastSets = seed.sets
    template.lastReps = seed.reps
    template.lastCompletedFully = seed.completedFully
    template.lastSessionDate = baselineDate
  }
}
