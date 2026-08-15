import Charts
import SwiftData
import SwiftUI

struct ExerciseProgressionView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]
  @Query(sort: \ExerciseSessionLog.date, order: .forward) private var logs: [ExerciseSessionLog]

  private var templatesWithLogs: [ExerciseTemplate] {
    let idsWithLogs = Set(logs.filter(\.countsForProgression).map(\.templateID))
    return templates.filter { idsWithLogs.contains($0.id) }
  }

  private var partGroups: [ProgressionPartGroup] {
    ProgressionPartGroup.build(from: templatesWithLogs)
  }

  var body: some View {
    Group {
      if partGroups.isEmpty {
        ScrollView {
          emptyState
            .padding(16)
        }
      } else {
        List {
          ForEach(partGroups) { group in
            NavigationLink {
              ProgressionPartDetailView(group: group)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: iconName(for: group.part))
                  .font(.title3)
                  .foregroundStyle(AppTheme.accent)
                  .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                  Text(BodyPartLexicon.display(part: group.part))
                    .font(.headline)
                  Text("\(group.templates.count) 个动作")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if group.templates.contains(where: \.readyToProgress) {
                  Text("可进阶")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green, in: Capsule())
                }
              }
              .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.cardBackground)
          }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
      }
    }
    .appPageBackground()
    .navigationTitle(L10n.progression)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "chart.xyaxis.line")
        .font(.largeTitle)
        .foregroundStyle(AppTheme.accent.opacity(0.6))
      Text("还没有进阶记录")
        .font(.headline)
      Text("点击「完成当天训练」后，这里会按身体部位汇总每个动作的重量变化")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(40)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func iconName(for part: String) -> String {
    switch part {
    case "肩": return "figure.arms.open"
    case "胸": return "figure.strengthtraining.traditional"
    case "背": return "figure.climbing"
    case "腿": return "figure.walk"
    case "臂": return "dumbbell.fill"
    case "核心": return "figure.core.training"
    case "有氧": return "figure.run"
    default: return "chart.xyaxis.line"
    }
  }
}

private struct ProgressionPartGroup: Identifiable {
  let id: String
  let part: String
  let templates: [ExerciseTemplate]

  static func build(from templates: [ExerciseTemplate]) -> [ProgressionPartGroup] {
    let grouped = Dictionary(grouping: templates) { $0.bodyPart }
    return grouped.map { part, items in
      ProgressionPartGroup(
        id: part,
        part: part,
        templates: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      )
    }
    .sorted { lhs, rhs in
      let left = ExerciseBodyCatalog.parts.firstIndex { $0.name == lhs.part } ?? 999
      let right = ExerciseBodyCatalog.parts.firstIndex { $0.name == rhs.part } ?? 999
      if left != right { return left < right }
      return lhs.part.localizedStandardCompare(rhs.part) == .orderedAscending
    }
  }
}

private struct ProgressionPartDetailView: View {
  @Environment(\.modelContext) private var modelContext
  let group: ProgressionPartGroup

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ForEach(group.templates) { template in
          ProgressionChartCard(
            template: template,
            logs: WorkoutStore.progressionLogs(for: template.id, in: modelContext)
          )
        }
      }
      .padding(16)
    }
    .appPageBackground()
    .navigationTitle(BodyPartLexicon.display(part: group.part))
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ProgressionChartCard: View {
  @Environment(\.modelContext) private var modelContext

  let template: ExerciseTemplate
  let logs: [ExerciseSessionLog]

  @State private var logPendingDelete: ExerciseSessionLog?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header

      if template.isCardio {
        cardioRecordsPanel
      } else if logs.count < 2 {
        Text("再记录 \(2 - logs.count) 次即可看到折线")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 80)
      } else {
        progressionChart
        Text("长按数据点可删除")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }

      if !template.isCardio {
        logList
      }

      if let latest = logs.last {
        Text("最近：\(latest.levelLabel) · \(latest.completedFully ? "做满" : "没做满")")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .alert("删除这条记录？", isPresented: deleteAlertBinding) {
      Button("删除", role: .destructive) {
        if let log = logPendingDelete {
          WorkoutStore.deleteSessionLog(log, in: modelContext)
        }
        logPendingDelete = nil
      }
      Button("取消", role: .cancel) {
        logPendingDelete = nil
      }
    } message: {
      if let log = logPendingDelete {
        Text("\(log.date.formatted(.dateTime.month(.defaultDigits).day())) · \(log.levelLabel)")
      }
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(ExerciseLexicon.display(template.name))
          .font(.headline)
        Text(template.categoryLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if template.readyToProgress {
        Text("可进阶")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.green, in: Capsule())
      } else if template.isCardio {
        Text("有氧")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.blue, in: Capsule())
      }
    }
  }

  private var cardioRecordsPanel: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("每次记录")
        .font(.caption)
        .foregroundStyle(.secondary)
      logList
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var progressionChart: some View {
    Chart(logs) { log in
      LineMark(
        x: .value("日期", log.date, unit: .day),
        y: .value("重量", log.weightKg)
      )
      .foregroundStyle(AppTheme.accent)
      .interpolationMethod(.catmullRom)

      PointMark(
        x: .value("日期", log.date, unit: .day),
        y: .value("重量", log.weightKg)
      )
      .foregroundStyle(logPendingDelete?.id == log.id ? Color.red : AppTheme.accent)
      .symbolSize(logPendingDelete?.id == log.id ? 120 : 60)
      .annotation(position: .top, spacing: 4) {
        Text(WorkoutFormat.weight(log.weightKg))
          .font(.caption2.weight(.bold))
          .foregroundStyle(AppTheme.accent)
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic) { value in
        if let date = value.as(Date.self) {
          AxisValueLabel {
            Text(date.formatted(.dateTime.month(.defaultDigits).day()))
              .font(.caption2)
          }
        }
      }
    }
    .chartYAxisLabel("kg")
    .frame(height: 180)
    .chartOverlay { proxy in
      GeometryReader { geometry in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .gesture(
            LongPressGesture(minimumDuration: 0.45)
              .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
              .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                if let log = nearestLog(
                  to: drag.location,
                  proxy: proxy,
                  geometry: geometry
                ) {
                  logPendingDelete = log
                }
              }
          )
      }
    }
  }

  private var logList: some View {
    VStack(spacing: 0) {
      ForEach(logs) { log in
        HStack {
          Text(log.date.formatted(.dateTime.month(.defaultDigits).day()))
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Text(log.levelLabel)
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
          Text(log.completedFully ? "做满" : "没做满")
            .font(.caption2)
            .foregroundStyle(log.completedFully ? .green : .orange)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
          Button("删除记录", role: .destructive) {
            logPendingDelete = log
          }
        }

        if log.id != logs.last?.id {
          Divider()
        }
      }
    }
  }

  private var deleteAlertBinding: Binding<Bool> {
    Binding(
      get: { logPendingDelete != nil },
      set: { if !$0 { logPendingDelete = nil } }
    )
  }

  private func nearestLog(
    to location: CGPoint,
    proxy: ChartProxy,
    geometry: GeometryProxy
  ) -> ExerciseSessionLog? {
    guard let plotFrame = proxy.plotFrame else { return nil }
    let plotRect = geometry[plotFrame]
    let threshold: CGFloat = 44

    var best: (log: ExerciseSessionLog, distance: CGFloat)?

    for log in logs {
      guard let xPosition = proxy.position(forX: log.date),
            let yPosition = proxy.position(forY: log.weightKg) else { continue }

      let point = CGPoint(
        x: plotRect.origin.x + xPosition,
        y: plotRect.origin.y + yPosition
      )
      let distance = hypot(location.x - point.x, location.y - point.y)
      guard distance <= threshold else { continue }

      if best == nil || distance < best!.distance {
        best = (log, distance)
      }
    }

    return best?.log
  }
}
