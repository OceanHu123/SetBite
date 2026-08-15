import Combine
import Foundation
import SwiftUI

enum AppDisplayLanguage: String, CaseIterable, Identifiable {
  case english
  case chinese
  case bilingual

  var id: String { rawValue }

  var settingsTitle: String {
    switch self {
    case .english: return "English"
    case .chinese: return "中文"
    case .bilingual: return "中英双语"
    }
  }
}

@MainActor
final class LanguageStore: ObservableObject {
  @Published var mode: AppDisplayLanguage {
    didSet { AppSettings.displayLanguage = mode }
  }

  init(mode: AppDisplayLanguage = AppSettings.displayLanguage) {
    self.mode = mode
  }
}

enum L10n {
  static func t(_ english: String, _ chinese: String) -> String {
    switch AppSettings.displayLanguage {
    case .english: return english
    case .chinese: return chinese
    case .bilingual: return "\(english) · \(chinese)"
    }
  }

  static func tf(_ english: String, _ chinese: String, _ args: CVarArg...) -> String {
    switch AppSettings.displayLanguage {
    case .english:
      return String(format: english, arguments: args)
    case .chinese:
      return String(format: chinese, arguments: args)
    case .bilingual:
      return "\(String(format: english, arguments: args)) · \(String(format: chinese, arguments: args))"
    }
  }

  // Tabs
  static var tabEat: String { t("Eat", "吃") }
  static var tabTrain: String { t("Train", "练") }

  // App
  static var appName: String { t("SetBite", "食练记") }

  // Settings
  static var settings: String { t("Settings", "设置") }
  static var save: String { t("Save", "保存") }
  static var displayLanguage: String { t("Display language", "显示语言") }
  static var apiKeySection: String { t("DeepSeek API Key", "DeepSeek API Key") }
  static var getApiKey: String { t("Get API Key", "获取 API Key") }
  static var apiKeyHint: String {
    t(
      "Required for recipe parsing, body analysis, and meal calories.",
      "食谱解析、体型分析、拍照识热量都需要 API Key"
    )
  }
  static var saved: String { t("Saved", "已保存") }
  static var cleared: String { t("Cleared", "已清空") }
  static var dataBackup: String { t("Data backup", "数据备份") }
  static var exportBackup: String { t("Export backup", "导出本地备份") }
  static var shareBackup: String { t("Share backup file", "分享备份文件") }
  static var importBackup: String { t("Import backup (restore on next launch)", "导入备份并下次启动恢复") }
  static var backupReady: String {
    t("Backup ready to share or save to Files.", "备份已生成，可立即分享或存到文件。")
  }
  static var backupFailed: String { t("Backup failed", "备份失败") }
  static var gotIt: String { t("OK", "知道了") }
  static var restoreImported: String {
    t(
      "Restore files imported. Fully quit and reopen the app to apply.",
      "恢复文件已导入。请完全退出 App 后重新打开，数据会自动恢复。"
    )
  }

  // Macros
  static var carbs: String { t("Carbs", "碳水") }
  static var protein: String { t("Protein", "蛋白质") }
  static var fat: String { t("Fat", "脂肪") }
  static var trainingDay: String { t("Training day", "训练日") }
  static var restDay: String { t("Rest day", "休息日") }
  static var todayCalories: String { t("Today's calories", "今日热量") }

  // Meal
  static var calorieLog: String { t("Calorie log", "热量记录") }
  static var logMeal: String { t("Log this meal", "记录本顿") }
  static var estimateCalories: String { t("Estimate calories", "识别本顿热量") }
  static var estimateByText: String { t("Estimate by text", "按文字估算热量") }
  static var logToday: String { t("Log today", "记入今日") }
  static var fromNutritionLabel: String { t("From nutrition label", "包装成分表") }
  static var pickRecipe: String { t("Pick from recipes", "从菜谱选择") }
  static var todayLog: String { t("Today's log", "今日记录") }
  static var mealHint: String {
    t(
      "Brand + grams uses nutrition labels when available. Photo optional.",
      "写品牌+克数会查包装成分表，更准；不必上传图片。"
    )
  }
  static var mealPlaceholder: String {
    t("e.g. Greek yogurt 200g + rice 150g", "例如：安慕希 200g + 大米饭 150g")
  }
  static var macroRemaining: String { t("Still need", "还差") }
  static var carbsShort: String { t("C", "碳") }
  static var proteinShort: String { t("P", "蛋") }
  static var fatShort: String { t("F", "脂") }
  static var recognitionResult: String { t("Estimate result", "识别结果") }
  static var logMealHint: String {
    t("Photo, recipe, or brand + grams", "拍照、选菜谱，或写品牌+克数")
  }
  static var selectedRecipe: String { t("Selected recipe:", "已选菜谱：") }
  static var noRecipesForPicker: String {
    t("Add recipes under Eat first, then come back.", "先在「吃」里添加菜谱，再回来选。")
  }
  static var macroMetNoMore: String { t("Target met — no need to add more.", "已达标，不必再补。") }
  static var macroEatAbout: String { t("About:", "大约吃：") }

  // Train
  static var train: String { t("Train", "健身") }
  static var body: String { t("Body", "体型") }
  static var trainFeatures: String { t("Train · Tools", "练 · 功能") }
  static var bodyMetrics: String { t("Body metrics", "体型") }
  static var importPlan: String { t("Import plan", "导入计划") }
  static var importPlanSubtitle: String {
    t("Import workouts from text or AI", "用文字或 AI 导入训练安排")
  }
  static var progression: String { t("Progress charts", "进阶折线") }
  static var progressionSubtitle: String {
    t("Weight trends by muscle group", "按身体部位看重量变化")
  }
  static var workoutPlan: String { t("Workout plan", "健身计划") }
  static var workoutPlanSubtitle: String {
    t("Back to this week's schedule", "回到本周训练安排")
  }
  static var bodyRecords: String { t("Body records", "体型记录") }
  static var bodyRecordsSubtitle: String {
    t("Weight, measurements & trends", "体重、围度与趋势")
  }
  static var exerciseLibrary: String { t("Exercise library", "动作库") }
  static var exerciseLibrarySubtitle: String {
    t("Manage exercises & targets", "管理训练动作与目标")
  }
  static var close: String { t("Close", "关闭") }
  static var more: String { t("More", "更多") }
  static var pickExercise: String { t("Pick exercise", "选择动作") }
  static var newExercise: String { t("New exercise", "新建动作") }
  static var editExercise: String { t("Edit exercise", "编辑动作") }
  static var workoutComplete: String { t("Workout complete", "训练完成") }
  static var sessionNotes: String { t("Session notes", "训练备注") }
  static var mergeExercise: String { t("Merge exercise", "合并动作") }
  static var bodyPartCategory: String { t("Muscle group", "大类") }
  static var bodyPartDetail: String { t("Target area", "细分") }
  static var clearDay: String { t("Clear this day?", "清空当天？") }
  static var clearDayMessage: String {
    t("Removes all exercises scheduled for this day.", "将删除这一天的全部训练动作。")
  }
  static func recordedExercise(_ name: String) -> String {
    tf("Logged %@", "已记录 %@", ExerciseLexicon.display(name))
  }
  static func exerciseMaxedOut(_ name: String) -> String {
    tf(
      "Great! %@ hit the cap — add weight next time.",
      "太棒了！%@ 已达上限，下次可以进阶加重",
      ExerciseLexicon.display(name)
    )
  }

  // Recipes
  static var noRecipes: String { t("No recipes yet", "还没有食谱") }
  static var noMatch: String { t("No matching recipes", "没有匹配的菜谱") }
  static var shoppingList: String { t("Shopping list", "待购") }
  static var newRecipe: String { t("New recipe", "新食谱") }

  // Common
  static var cancel: String { t("Cancel", "取消") }
  static var done: String { t("Done", "完成") }
  static var clear: String { t("Clear", "清除") }
  static var search: String { t("Search", "搜索") }
  static var addApiKeyFirst: String {
    t("Add your DeepSeek API Key in Settings first.", "请先在设置中填写 DeepSeek API Key")
  }
  static var minutes: String { t("min", "分钟") }
}
