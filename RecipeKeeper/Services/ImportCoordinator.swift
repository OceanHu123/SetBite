import Foundation

@MainActor
final class ImportCoordinator: ObservableObject {
  @Published var pendingImport: SharePendingImport?
  @Published var showAddRecipe = false

  func checkForPendingImport() {
    guard let pending = ShareImportStore.loadPendingImport() else { return }
    pendingImport = pending
    showAddRecipe = true
  }

  func clearSharedFiles() {
    ShareImportStore.clearPendingImport()
    pendingImport = nil
    showAddRecipe = false
  }
}
