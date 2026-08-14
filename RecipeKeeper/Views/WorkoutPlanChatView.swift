import SwiftData
import SwiftUI

struct WorkoutPlanImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

  @State private var selectedWeekStart = WorkoutCalendar.startOfWeek(for: Date())
  @State private var pastedPlan = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var assignmentPayload: PlanAssignmentPayload?
  @State private var nameResolutionPayload: NameResolutionPayload?
  @FocusState private var isInputFocused: Bool

  private let client = WorkoutPlanAIClient()

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        weekPicker

        TextEditor(text: $pastedPlan)
          .focused($isInputFocused)
          .padding(12)
          .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay {
            if pastedPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Text("粘贴其他 AI 生成的训练计划…")
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
                .allowsHitTesting(false)
            }
          }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("解析后如有不确定的动作名会先请你确认，再选择放在哪一天。")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 0)
      }
      .padding(16)
      .appPageBackground()
      .navigationTitle("导入计划")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task { await parsePlan() }
          } label: {
            if isLoading {
              ProgressView()
                .controlSize(.small)
            } else {
              Text("解析")
            }
          }
          .disabled(isLoading || pastedPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .keyboardDoneToolbar()
      .sheet(item: $nameResolutionPayload) { payload in
        WorkoutPlanNameResolutionSheet(selections: payload.selections) { confirmed in
          let resolved = payload.plan.applyingNameSelections(
            confirmed,
            existingTemplateNames: Set(templates.map(\.name))
          )
          nameResolutionPayload = nil
          assignmentPayload = PlanAssignmentPayload(
            assignments: resolved.days.map { day in
              PlanDayAssignment(weekdayIndex: day.weekdayIndex, exercises: day.exercises)
            }
          )
        }
      }
      .sheet(item: $assignmentPayload) { payload in
        WorkoutPlanAssignmentSheet(
          weekStart: selectedWeekStart,
          assignments: payload.assignments
        ) { confirmed in
          applyAssignments(confirmed)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var weekPicker: some View {
    HStack {
      Button { shiftWeek(by: -1) } label: {
        Image(systemName: "chevron.left.circle.fill")
          .font(.title3)
          .foregroundStyle(AppTheme.accent)
      }

      VStack(spacing: 2) {
        Text(isCurrentWeek ? "本周" : "目标周")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(WorkoutCalendar.weekRangeLabel(for: selectedWeekStart))
          .font(.subheadline.weight(.semibold))
      }
      .frame(maxWidth: .infinity)

      Button { shiftWeek(by: 1) } label: {
        Image(systemName: "chevron.right.circle.fill")
          .font(.title3)
          .foregroundStyle(AppTheme.accent)
      }
    }
    .padding(12)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var isCurrentWeek: Bool {
    Calendar.current.isDate(
      selectedWeekStart,
      inSameDayAs: WorkoutCalendar.startOfWeek(for: Date())
    )
  }

  private func shiftWeek(by offset: Int) {
    if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) {
      selectedWeekStart = WorkoutCalendar.startOfWeek(for: newStart)
    }
  }

  @MainActor
  private func parsePlan() async {
    isInputFocused = false
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let plan = try await client.parsePastedPlan(
        pastedText: pastedPlan,
        templates: templates,
        weekRangeLabel: WorkoutCalendar.weekRangeLabel(for: selectedWeekStart)
      )
      guard !plan.days.isEmpty else {
        errorMessage = "未能从文本中识别出训练日"
        return
      }

      if !plan.resolvedUncertainties.isEmpty {
        nameResolutionPayload = NameResolutionPayload(
          plan: plan,
          selections: plan.resolvedUncertainties.map { item in
            let candidates = ExerciseNameCatalog.resolutionCandidates(
              for: item.rawName,
              in: templates,
              extra: item.candidates
            )
            return NameResolutionItem(
              rawName: item.rawName,
              reason: item.reason,
              candidates: candidates,
              selectedOption: item.rawName,
              customName: item.rawName
            )
          }
        )
      } else {
        assignmentPayload = PlanAssignmentPayload(
          assignments: plan.days.map { day in
            PlanDayAssignment(weekdayIndex: day.weekdayIndex, exercises: day.exercises)
          }
        )
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func applyAssignments(_ assignments: [PlanDayAssignment]) {
    let plan = GeneratedWorkoutPlan(
      summary: nil,
      days: assignments.map {
        GeneratedWorkoutPlan.Day(weekdayIndex: $0.weekdayIndex, exercises: $0.exercises)
      }
    )

    let result = WorkoutStore.applyGeneratedPlan(
      plan,
      to: selectedWeekStart,
      clearWholeWeek: false,
      in: modelContext
    )
    guard result.exercisesAdded > 0 else {
      errorMessage = "没有可导入的动作"
      return
    }
    dismiss()
  }
}

struct PlanDayAssignment: Identifiable {
  let id = UUID()
  var weekdayIndex: Int
  let exercises: [GeneratedWorkoutPlan.Exercise]

  var summary: String {
    let names = exercises.map(\.name).prefix(4)
    let joined = names.joined(separator: "、")
    if exercises.count > 4 {
      return "\(joined) 等 \(exercises.count) 个动作"
    }
    return joined
  }
}

struct PlanAssignmentPayload: Identifiable {
  let id = UUID()
  var assignments: [PlanDayAssignment]
}

struct NameResolutionPayload: Identifiable {
  let id = UUID()
  var plan: GeneratedWorkoutPlan
  var selections: [NameResolutionItem]
}

private struct WorkoutPlanNameResolutionSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State var selections: [NameResolutionItem]
  let onConfirm: ([NameResolutionItem]) -> Void

  private var canContinue: Bool {
    selections.allSatisfy { !$0.selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("以下动作名称与动作库或原文不一致，请逐一确认。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        ForEach($selections) { $item in
          VStack(alignment: .leading, spacing: 8) {
            Text(item.rawName)
              .font(.subheadline.weight(.semibold))

            if let reason = item.reason, !reason.isEmpty {
              Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Picker("动作", selection: $item.selectedOption) {
              ForEach(item.candidates, id: \.self) { name in
                Text(name).tag(name)
              }
              Text("自定义（基于原名修改）").tag(NameResolutionItem.customOptionKey)
            }
            .pickerStyle(.menu)

            if item.selectedOption == NameResolutionItem.customOptionKey {
              TextField("自定义动作名", text: $item.customName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
          }
          .padding(.vertical, 4)
        }
      }
      .navigationTitle("确认动作名")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("返回") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("继续") {
            onConfirm(selections)
            dismiss()
          }
          .fontWeight(.semibold)
          .disabled(!canContinue)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

private struct WorkoutPlanAssignmentSheet: View {
  @Environment(\.dismiss) private var dismiss

  let weekStart: Date
  @State var assignments: [PlanDayAssignment]
  let onConfirm: ([PlanDayAssignment]) -> Void

  private var weekDays: [Date] {
    WorkoutCalendar.daysInWeek(starting: weekStart)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("确认每组训练放在哪一天。选中的日期会覆盖当天原有安排。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        ForEach($assignments) { $assignment in
          VStack(alignment: .leading, spacing: 10) {
            Text(assignment.summary)
              .font(.subheadline.weight(.medium))

            Picker("安排到", selection: $assignment.weekdayIndex) {
              ForEach(0..<7, id: \.self) { index in
                Text(dayLabel(for: index)).tag(index)
              }
            }
            .pickerStyle(.menu)
          }
          .padding(.vertical, 4)
        }
      }
      .navigationTitle("放在哪一天")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("返回") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("导入") {
            onConfirm(assignments)
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func dayLabel(for index: Int) -> String {
    guard weekDays.indices.contains(index) else { return "周\(index + 1)" }
    let day = weekDays[index]
    return day.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide))
  }
}
