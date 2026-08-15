import SwiftUI
import UniformTypeIdentifiers

struct SettingsContentView: View {
  @EnvironmentObject private var languageStore: LanguageStore
  @State private var apiKey = AppSettings.deepSeekAPIKey
  @State private var savedMessage: String?
  @State private var backupExportURL: URL?
  @State private var backupStatusMessage: String?
  @State private var backupErrorMessage: String?
  @State private var showingBackupImporter = false
  @State private var restoreMessage: String?

  var body: some View {
    Form {
      Section(L10n.displayLanguage) {
        Picker(L10n.displayLanguage, selection: $languageStore.mode) {
          ForEach(AppDisplayLanguage.allCases) { mode in
            Text(mode.settingsTitle).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      }

      Section(L10n.apiKeySection) {
        SecureField("sk-...", text: $apiKey)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Link(L10n.getApiKey, destination: URL(string: "https://platform.deepseek.com")!)
          .font(.footnote)
        Text(L10n.apiKeyHint)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if let savedMessage {
        Section {
          Text(savedMessage).foregroundStyle(.green).font(.footnote)
        }
      }

      Section(L10n.dataBackup) {
        Button(L10n.exportBackup) {
          do {
            backupExportURL = try BackupExporter.prepareBackupBundle()
            backupStatusMessage = L10n.backupReady
            backupErrorMessage = nil
          } catch {
            backupErrorMessage = error.localizedDescription
          }
        }

        if let backupExportURL {
          ShareLink(L10n.shareBackup, item: backupExportURL)
            .font(.footnote)
        }

        if let backupStatusMessage {
          Text(backupStatusMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Button(L10n.importBackup) {
          showingBackupImporter = true
        }

        if let restoreMessage {
          Text(restoreMessage)
            .font(.footnote)
            .foregroundStyle(.orange)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .appPageBackground()
    .scrollDismissesKeyboard(.interactively)
    .keyboardDoneToolbar()
    .navigationTitle(L10n.settings)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(L10n.save) {
          AppSettings.deepSeekAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
          savedMessage = AppSettings.hasAPIKey ? L10n.saved : L10n.cleared
        }
      }
    }
    .alert(L10n.backupFailed, isPresented: Binding(
      get: { backupErrorMessage != nil },
      set: { if !$0 { backupErrorMessage = nil } }
    )) {
      Button(L10n.gotIt, role: .cancel) { backupErrorMessage = nil }
    } message: {
      Text(backupErrorMessage ?? "")
    }
    .fileImporter(
      isPresented: $showingBackupImporter,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        guard let url = urls.first else { return }
        do {
          try BackupRestorer.stageRestore(from: url)
          restoreMessage = L10n.restoreImported
          backupErrorMessage = nil
        } catch {
          backupErrorMessage = error.localizedDescription
        }
      case .failure(let error):
        backupErrorMessage = error.localizedDescription
      }
    }
  }
}

struct SettingsView: View {
  var body: some View {
    NavigationStack {
      SettingsContentView()
        .navigationTitle("⚙️ \(L10n.settings)")
        .navigationBarTitleDisplayMode(.large)
    }
  }
}

private enum BackupExporter {
  static func prepareBackupBundle() throws -> URL {
    let source = AppModelContainer.storeURL
    let fm = FileManager.default
    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let bundleURL = fm.temporaryDirectory.appendingPathComponent("RecipeKeeperBackup-\(timestamp)").appendingPathExtension("backup")

    if fm.fileExists(atPath: bundleURL.path) {
      try fm.removeItem(at: bundleURL)
    }
    try fm.createDirectory(at: bundleURL, withIntermediateDirectories: true)

    let files = [
      source,
      URL(fileURLWithPath: source.path + "-wal"),
      URL(fileURLWithPath: source.path + "-shm")
    ]

    var copiedAny = false
    for file in files where fm.fileExists(atPath: file.path) {
      let dest = bundleURL.appendingPathComponent(file.lastPathComponent)
      if fm.fileExists(atPath: dest.path) {
        try fm.removeItem(at: dest)
      }
      try fm.copyItem(at: file, to: dest)
      copiedAny = true
    }

    guard copiedAny else {
      throw NSError(domain: "BackupExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到可导出的数据库文件"])
    }
    return bundleURL
  }
}

private enum BackupRestorer {
  static func stageRestore(from folderURL: URL) throws {
    let access = folderURL.startAccessingSecurityScopedResource()
    defer {
      if access { folderURL.stopAccessingSecurityScopedResource() }
    }
    try AppModelContainer.stageRestoreFiles(from: folderURL)
  }
}
