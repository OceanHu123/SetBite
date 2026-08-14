import SwiftUI
import UniformTypeIdentifiers

struct SettingsContentView: View {
  @State private var apiKey = AppSettings.deepSeekAPIKey
  @State private var savedMessage: String?
  @State private var backupExportURL: URL?
  @State private var backupStatusMessage: String?
  @State private var backupErrorMessage: String?
  @State private var showingBackupImporter = false
  @State private var restoreMessage: String?

  var body: some View {
    Form {
      Section("DeepSeek API Key") {
        SecureField("sk-...", text: $apiKey)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Link("获取 API Key", destination: URL(string: "https://platform.deepseek.com")!)
          .font(.footnote)
        Text("食谱解析、体型分析、拍照识热量都需要 API Key")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if let savedMessage {
        Section {
          Text(savedMessage).foregroundStyle(.green).font(.footnote)
        }
      }

      Section("数据备份") {
        Button("导出本地备份") {
          do {
            backupExportURL = try BackupExporter.prepareBackupBundle()
            backupStatusMessage = "备份已生成，可立即分享或存到文件。"
            backupErrorMessage = nil
          } catch {
            backupErrorMessage = error.localizedDescription
          }
        }

        if let backupExportURL {
          ShareLink("分享备份文件", item: backupExportURL)
            .font(.footnote)
        }

        if let backupStatusMessage {
          Text(backupStatusMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Button("导入备份并下次启动恢复") {
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
    .navigationTitle("设置")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("保存") {
          AppSettings.deepSeekAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
          savedMessage = AppSettings.hasAPIKey ? "已保存" : "已清空"
        }
      }
    }
    .alert("备份失败", isPresented: Binding(
      get: { backupErrorMessage != nil },
      set: { if !$0 { backupErrorMessage = nil } }
    )) {
      Button("知道了", role: .cancel) { backupErrorMessage = nil }
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
          restoreMessage = "恢复文件已导入。请完全退出 App 后重新打开，数据会自动恢复。"
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
        .navigationTitle("⚙️ 设置")
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
