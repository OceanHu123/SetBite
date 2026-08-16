import SwiftData
import SwiftUI

@main
struct RecipeKeeperApp: App {
  @StateObject private var importCoordinator = ImportCoordinator()
  @StateObject private var languageStore = LanguageStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(importCoordinator)
        .environmentObject(languageStore)
        .id(languageStore.mode)
        .onOpenURL { url in
          guard url.scheme == "recipekeeper" else { return }
          importCoordinator.checkForPendingImport()
        }
        .onAppear {
          importCoordinator.checkForPendingImport()
        }
        .preferredColorScheme(.light)
        .tint(AppTheme.accent)
    }
    .modelContainer(AppModelContainer.shared)
  }
}

enum AppModelContainer {
  static let schema = Schema([
    Recipe.self,
    ShoppingItem.self,
    PantryItem.self,
    CookingLog.self,
    MealMacroLog.self,
    WaterLog.self,
    BodyRecord.self,
    WorkoutWeekPlan.self,
    WorkoutDayPlan.self,
    WorkoutExercise.self,
    ExerciseTemplate.self,
    ExerciseSessionLog.self
  ])

  static let shared: ModelContainer = makeContainer()
  static let storeURL: URL = {
    ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
  }()
  static let pendingRestoreFolderURL: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return base.appendingPathComponent("RecipeKeeperPendingRestore", isDirectory: true)
  }()

  private static func makeContainer() -> ModelContainer {
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    applyPendingRestoreIfNeeded(storeURL: configuration.url)

    do {
      return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("""
      无法初始化数据库。为避免数据丢失，应用已停止自动重建数据库。
      请保留设备上的现有 App 数据，并在修复迁移问题后再启动。
      错误详情：\(error.localizedDescription)
      """)
    }
  }

  static func stageRestoreFiles(from backupFolder: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: pendingRestoreFolderURL.path) {
      try fm.removeItem(at: pendingRestoreFolderURL)
    }
    try fm.createDirectory(at: pendingRestoreFolderURL, withIntermediateDirectories: true)

    let backupFiles = try fm.contentsOfDirectory(
      at: backupFolder,
      includingPropertiesForKeys: nil
    )
    for file in backupFiles {
      let name = file.lastPathComponent
      guard name.hasSuffix(".store") || name.hasSuffix(".store-wal") || name.hasSuffix(".store-shm") else {
        continue
      }
      let dest = pendingRestoreFolderURL.appendingPathComponent(name)
      try fm.copyItem(at: file, to: dest)
    }
  }

  private static func applyPendingRestoreIfNeeded(storeURL: URL) {
    let fm = FileManager.default
    guard fm.fileExists(atPath: pendingRestoreFolderURL.path),
          let files = try? fm.contentsOfDirectory(at: pendingRestoreFolderURL, includingPropertiesForKeys: nil),
          !files.isEmpty else {
      return
    }

    let storeBaseName = storeURL.lastPathComponent
    let targets: [(src: URL, dst: URL)] = [
      (pendingRestoreFolderURL.appendingPathComponent(storeBaseName), storeURL),
      (pendingRestoreFolderURL.appendingPathComponent(storeBaseName + "-wal"), URL(fileURLWithPath: storeURL.path + "-wal")),
      (pendingRestoreFolderURL.appendingPathComponent(storeBaseName + "-shm"), URL(fileURLWithPath: storeURL.path + "-shm"))
    ]

    do {
      for (_, dst) in targets where fm.fileExists(atPath: dst.path) {
        try fm.removeItem(at: dst)
      }
      for (src, dst) in targets where fm.fileExists(atPath: src.path) {
        try fm.copyItem(at: src, to: dst)
      }
      try fm.removeItem(at: pendingRestoreFolderURL)
    } catch {
      // 保留待恢复文件，下一次启动可再次尝试
    }
  }
}

enum DecimalInput {
  static func parse(_ text: String) -> Double? {
    var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    trimmed = trimmed
      .replacingOccurrences(of: "，", with: ".")
      .replacingOccurrences(of: ",", with: ".")
      .replacingOccurrences(of: "．", with: ".")

    let fullwidthZero: UInt32 = 0xFF10
    var normalized = ""
    for scalar in trimmed.unicodeScalars {
      if scalar.value >= fullwidthZero, scalar.value <= fullwidthZero + 9 {
        normalized.append(String(scalar.value - fullwidthZero))
      } else {
        normalized.append(String(scalar))
      }
    }

    return Double(normalized)
  }
}
