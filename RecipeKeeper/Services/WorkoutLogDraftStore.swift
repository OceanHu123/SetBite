import Foundation

struct WorkoutLogDraft: Codable, Equatable {
  var exerciseID: UUID
  var weightText: String
  var notesText: String
  var restSeconds: Int
  var targetSets: Int
  var setReps: [Int]
  var completedSets: Int
  var quickInput: String
  var restEndDate: Date?
  var updatedAt: Date
}

enum WorkoutLogDraftStore {
  private static let key = "workout_log_draft_v1"
  private static let keepOpenKey = "workout_log_keep_sheet_open_v1"

  static var keepSheetOpen: Bool {
    get { UserDefaults.standard.bool(forKey: keepOpenKey) }
    set { UserDefaults.standard.set(newValue, forKey: keepOpenKey) }
  }

  static func load(for exerciseID: UUID) -> WorkoutLogDraft? {
    guard let draft = load(), draft.exerciseID == exerciseID else { return nil }
    return draft
  }

  static func load() -> WorkoutLogDraft? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(WorkoutLogDraft.self, from: data)
  }

  static func save(_ draft: WorkoutLogDraft) {
    guard let data = try? JSONEncoder().encode(draft) else { return }
    UserDefaults.standard.set(data, forKey: key)
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: key)
    keepSheetOpen = false
  }
}
