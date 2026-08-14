import SwiftData
import SwiftUI

struct WorkoutHomeContent: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WorkoutDayPlan.date) private var allDayPlans: [WorkoutDayPlan]
  @Query private var templates: [ExerciseTemplate]

  @State private var selectedWeekStart = WorkoutCalendar.startOfWeek(for: Date())
  @State private var selectedDayRoute: WorkoutDayRoute?
  @State private var movingDayDate: Date?
  @State private var clearingDayDate: Date?
  @State private var toastMessage: String?

  private var weekDays: [Date] {
    WorkoutCalendar.daysInWeek(starting: selectedWeekStart)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        weekNavigator
        weekActions
        weekCalendarCard
      }
      .padding(16)
      .padding(.bottom, 16)
    }
    .navigationDestination(item: $selectedDayRoute) { route in
      WorkoutDayDetailView(
        dayPlan: WorkoutStore.dayPlan(
          for: route.date,
          weekPlan: WorkoutStore.weekPlan(for: selectedWeekStart, in: modelContext),
          in: modelContext
        )
      )
    }
    .overlay(alignment: .bottom) {
      if let toastMessage {
        ToastBanner(message: toastMessage)
          .padding(.bottom, 88)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeInOut, value: toastMessage)
    .sheet(isPresented: Binding(
      get: { movingDayDate != nil },
      set: { if !$0 { movingDayDate = nil } }
    )) {
      if let date = movingDayDate {
        WorkoutDayMoveSheet(sourceDate: date) { targetDate in
          if WorkoutStore.moveDayPlan(from: date, to: targetDate, in: modelContext) {
            showToast("已移到 \(targetDate.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide)))")
          }
          movingDayDate = nil
        }
      }
    }
    .alert("清空当天？", isPresented: Binding(
      get: { clearingDayDate != nil },
      set: { if !$0 { clearingDayDate = nil } }
    )) {
      Button("取消", role: .cancel) { clearingDayDate = nil }
      Button("清空", role: .destructive) {
        if let date = clearingDayDate {
          WorkoutStore.clearDayPlan(on: date, in: modelContext)
          showToast("已清空 \(date.formatted(.dateTime.month(.defaultDigits).day())) 的安排")
        }
        clearingDayDate = nil
      }
    } message: {
      Text("将删除这一天的全部训练动作。")
    }
  }

  private var weekNavigator: some View {
    HStack {
      Button { shiftWeek(by: -1) } label: {
        Image(systemName: "chevron.left.circle.fill")
          .font(.title2)
          .foregroundStyle(AppTheme.accent)
      }

      VStack(spacing: 2) {
        Text(isCurrentWeek ? "本周" : "训练周")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(WorkoutCalendar.weekRangeLabel(for: selectedWeekStart))
          .font(.headline)
      }
      .frame(maxWidth: .infinity)

      Button { shiftWeek(by: 1) } label: {
        Image(systemName: "chevron.right.circle.fill")
          .font(.title2)
          .foregroundStyle(AppTheme.accent)
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var weekActions: some View {
    Button {
      let copied = WorkoutStore.copyPreviousWeek(to: selectedWeekStart, in: modelContext)
      if copied > 0 {
        showToast("已复制上周 \(copied) 天训练安排")
      } else {
        showToast("上周没有可复制的训练，或本周已有安排")
      }
    } label: {
      Label("复制上周计划", systemImage: "doc.on.doc")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .tint(AppTheme.accent)
  }

  private var isCurrentWeek: Bool {
    Calendar.current.isDate(
      selectedWeekStart,
      inSameDayAs: WorkoutCalendar.startOfWeek(for: Date())
    )
  }

  private var weekCalendarCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("本周日历")
        .font(.headline)
        .foregroundStyle(AppTheme.accent)

      Text("点选日期，从动作库勾选动作即可，自动继承上次 level")
        .font(.footnote)
        .foregroundStyle(.secondary)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
        ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
          Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }

        ForEach(weekDays, id: \.self) { day in
          dayCell(for: day)
        }
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func dayPlan(on day: Date) -> WorkoutDayPlan? {
    allDayPlans.first {
      Calendar.current.isDate($0.date, inSameDayAs: day)
    }
  }

  private func bodyPartLabel(on day: Date) -> String {
    guard let plan = dayPlan(on: day), !plan.exercises.isEmpty else { return "" }
    var seen = Set<String>()
    var parts: [String] = []
    for exercise in plan.sortedExercises {
      let part = templates.first { $0.id == exercise.templateID }?.bodyPart ?? "其他"
      if seen.insert(part).inserted {
        parts.append(part)
      }
    }
    return parts.joined()
  }

  private func dayCell(for day: Date) -> some View {
    let partLabel = bodyPartLabel(on: day)
    let isToday = Calendar.current.isDateInToday(day)
    let hasWorkout = !partLabel.isEmpty

    return Button {
      selectedDayRoute = WorkoutDayRoute(date: day)
    } label: {
      VStack(spacing: 4) {
        Text(day.formatted(.dateTime.day()))
          .font(.subheadline.weight(isToday ? .bold : .medium))
        if hasWorkout {
          Text(partLabel)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(AppTheme.accent, in: Capsule())
        } else {
          Text("休息")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(
        isToday ? AppTheme.accentSoft : Color(.systemGray6),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .overlay {
        if isToday {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.accent, lineWidth: 1.5)
        }
      }
    }
    .buttonStyle(.plain)
    .contextMenu {
      if hasWorkout {
        Button {
          movingDayDate = day
        } label: {
          Label("移到其他日期", systemImage: "arrow.right.arrow.left")
        }
        Button(role: .destructive) {
          clearingDayDate = day
        } label: {
          Label("清空当天", systemImage: "trash")
        }
      }
    }
  }

  private func shiftWeek(by offset: Int) {
    if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) {
      selectedWeekStart = WorkoutCalendar.startOfWeek(for: newStart)
    }
  }

  private func showToast(_ message: String) {
    toastMessage = message
    Task {
      try? await Task.sleep(for: .seconds(2.2))
      await MainActor.run { toastMessage = nil }
    }
  }
}

struct WorkoutDayRoute: Identifiable, Hashable {
  let id: Date
  var date: Date { id }

  init(date: Date) {
    self.id = Calendar.current.startOfDay(for: date)
  }
}

extension UUID: @retroactive Identifiable {
  public var id: UUID { self }
}

struct WorkoutDayDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Bindable var dayPlan: WorkoutDayPlan

  @State private var showingPicker = false
  @State private var showingMoveDay = false
  @State private var showingClearConfirm = false
  @State private var loggingExerciseID: UUID?
  @State private var editingNotesExercise: WorkoutExercise?
  @State private var toastMessage: String?
  @State private var healthSummary: WorkoutHealthDaySummary?
  @State private var isLoadingHealth = false
  @State private var healthAccessRequested = false
  @State private var completionSummary: WorkoutSessionSummaryData?
  @State private var cachedSessionSummary: WorkoutSessionSummaryData?

  var body: some View {
    List {
      if let cachedSessionSummary, dayPlan.isSessionComplete {
        Section {
          WorkoutSessionSummaryCard(
            summary: cachedSessionSummary,
            aiText: dayPlan.aiSessionSummary,
            showCelebration: false
          )
          .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)

          if cachedSessionSummary.activeCalories <= 0 || cachedSessionSummary.durationSeconds <= 0 {
            Button {
              Task { await refreshHealthSummary(requestAccess: true) }
            } label: {
              Label("从手表同步耗时/消耗", systemImage: "applewatch")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
          }
        }
      } else {
        Section {
          headerCard
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
      }

      if dayPlan.sortedExercises.isEmpty {
        Section {
          emptyState
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
      } else {
        Section {
          ForEach(dayPlan.sortedExercises) { exercise in
            exerciseCard(exercise)
              .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                  deleteExercise(exercise)
                } label: {
                  Label("删除", systemImage: "trash")
                }
              }
          }
        }
      }

      if showsCompleteButton {
        Section {
          completeDayButton
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .appPageBackground()
    .refreshable {
      await refreshHealthSummary(requestAccess: healthAccessRequested)
    }
    .task(id: dayPlan.date) {
      await refreshHealthSummary(requestAccess: !healthAccessRequested)
      refreshSessionSummary()
    }
    .task(id: dayPlan.sessionCompletedAt) {
      refreshSessionSummary()
    }
    .navigationTitle(dayPlan.date.formatted(.dateTime.month(.wide).day().weekday(.wide)))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Menu {
          Button {
            showingMoveDay = true
          } label: {
            Label("移到其他日期", systemImage: "arrow.right.arrow.left")
          }
          Button(role: .destructive) {
            showingClearConfirm = true
          } label: {
            Label("清空当天", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button { showingPicker = true } label: {
          Image(systemName: "plus.circle.fill")
            .foregroundStyle(AppTheme.accent)
        }
      }
    }
    .sheet(isPresented: $showingMoveDay) {
      WorkoutDayMoveSheet(sourceDate: dayPlan.date) { targetDate in
        if WorkoutStore.moveDayPlan(from: dayPlan.date, to: targetDate, in: modelContext) {
          showToast("已移到 \(targetDate.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide)))")
        }
      }
    }
    .alert("清空当天？", isPresented: $showingClearConfirm) {
      Button("取消", role: .cancel) {}
      Button("清空", role: .destructive) {
        WorkoutStore.clearDayPlan(on: dayPlan.date, in: modelContext)
        showToast("已清空当天安排")
      }
    } message: {
      Text("将删除这一天的全部训练动作，已完成记录仍保留在动作库里。")
    }
    .sheet(isPresented: $showingPicker) {
      ExerciseLibraryPickerSheet(dayPlan: dayPlan)
    }
    .sheet(item: $loggingExerciseID) { exerciseID in
      if let exercise = dayPlan.sortedExercises.first(where: { $0.id == exerciseID }) {
        WorkoutLogSheet(exercise: exercise, sessionDate: dayPlan.date) {
          handleExerciseSaved(exercise)
        }
      }
    }
    .fullScreenCover(item: $completionSummary) { summary in
      WorkoutDayCompletionSheet(dayPlan: dayPlan, summary: summary)
    }
    .sheet(item: $editingNotesExercise) { exercise in
      ExerciseNotesSheet(exercise: exercise)
    }
    .onAppear {
      restoreLoggingSheetIfNeeded()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        restoreLoggingSheetIfNeeded()
      }
    }
    .overlay(alignment: .bottom) {
      if let toastMessage {
        ToastBanner(message: toastMessage)
          .padding(.bottom, 24)
      }
    }
  }

  private func openLogSheet(for exercise: WorkoutExercise) {
    WorkoutLogDraftStore.keepSheetOpen = true
    loggingExerciseID = exercise.id
  }

  private func restoreLoggingSheetIfNeeded() {
    guard loggingExerciseID == nil,
          WorkoutLogDraftStore.keepSheetOpen,
          let draft = WorkoutLogDraftStore.load(),
          dayPlan.sortedExercises.contains(where: { $0.id == draft.exerciseID }) else {
      return
    }
    loggingExerciseID = draft.exerciseID
  }

  private var showsCompleteButton: Bool {
    !dayPlan.isSessionComplete && !dayPlan.sortedExercises.isEmpty
  }

  private var completeDayButton: some View {
    Button {
      Task { await completeDayManually() }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "flag.checkered")
        Text("完成当天训练")
      }
      .font(.headline)
      .foregroundStyle(.white)
      .padding(.horizontal, 22)
      .padding(.vertical, 14)
    }
    .buttonStyle(.plain)
    .background(AppTheme.accent, in: Capsule())
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("今日训练")
        .font(.headline)
        .foregroundStyle(AppTheme.accent)
      Text("左滑删除 · 练完后点底部「完成当天训练」")
        .font(.footnote)
        .foregroundStyle(.secondary)

      if WorkoutHealthService.isAvailable {
        Divider()
        healthSummaryRow
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder
  private var healthSummaryRow: some View {
    if isLoadingHealth {
      HStack(spacing: 8) {
        ProgressView()
        Text("读取手表训练…")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    } else if let healthSummary, !healthSummary.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(healthSummary.workoutName.isEmpty ? "手表训练" : healthSummary.workoutName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Button("刷新") {
            Task { await refreshHealthSummary(requestAccess: true) }
          }
          .font(.caption)
        }
        HStack(spacing: 16) {
          Label(healthSummary.durationLabel, systemImage: "timer")
          Label(healthSummary.caloriesLabel, systemImage: "flame.fill")
        }
        .font(.subheadline)
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text("还没读到手表上的本次训练。练完后点同步，会写入复盘的耗时和消耗。")
          .font(.footnote)
          .foregroundStyle(.secondary)
        Button("同步手表训练") {
          Task { await refreshHealthSummary(requestAccess: true) }
        }
        .font(.footnote.weight(.semibold))
      }
    }
  }

  private func refreshHealthSummary(requestAccess: Bool) async {
    guard WorkoutHealthService.isAvailable else { return }
    isLoadingHealth = true
    defer { isLoadingHealth = false }

    do {
      if requestAccess {
        try await WorkoutHealthService.requestReadAccess()
        healthAccessRequested = true
      }
      let health = try await WorkoutHealthService.daySummary(for: dayPlan.date)
      healthSummary = health

      if dayPlan.isSessionComplete, !health.isEmpty {
        dayPlan.cachedHealthDuration = health.duration
        dayPlan.cachedHealthCalories = health.activeCalories
        try? modelContext.save()
        refreshSessionSummary()
      }
    } catch {
      healthSummary = nil
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "dumbbell")
        .font(.largeTitle)
        .foregroundStyle(AppTheme.accent.opacity(0.6))
      Text("还没有安排动作")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("从动作库添加") { showingPicker = true }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(exercise.name)
          .font(.headline)
        Spacer()
        if exercise.readyToProgress {
          Text("可进阶")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green, in: Capsule())
        }
      }

      HStack {
        Label(exercise.maxLabel, systemImage: "target")
          .font(.subheadline)
          .foregroundStyle(AppTheme.accent)
        Spacer()
        if exercise.restSeconds > 0 {
          Label("\(exercise.restSeconds)s 间歇", systemImage: "timer")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      if exercise.hasSessionNotes {
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "text.quote")
            .font(.caption)
            .foregroundStyle(AppTheme.accent)
            .padding(.top, 2)
          Text(exercise.sessionNotes)
            .font(.footnote)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
      }

      Text(exercise.lastRecordLabel)
        .font(.footnote)
        .foregroundStyle(.secondary)

      if exercise.readyToProgress {
        Text("\(WorkoutFormat.sessionRepsLabel(sets: exercise.lastSets, maxReps: exercise.maxReps, setRepsLog: exercise.lastSetRepsLog)) 已做满，下次可加重量")
          .font(.footnote.weight(.medium))
          .foregroundStyle(.green)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      }

      HStack {
        if exercise.isCompleted(on: dayPlan.date) {
          Label(dayPlan.isSessionComplete ? "已记录" : "已完成", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        } else {
          Button("记录完成") { openLogSheet(for: exercise) }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        Spacer(minLength: 0)
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .contextMenu {
      Button("编辑备注") { editingNotesExercise = exercise }
      if exercise.isCompleted(on: dayPlan.date) {
        Button("编辑记录") { openLogSheet(for: exercise) }
      }
      Button("删除", role: .destructive) { deleteExercise(exercise) }
    }
  }

  private func handleExerciseSaved(_ exercise: WorkoutExercise) {
    if exercise.readyToProgress {
      showToast("太棒了！\(exercise.name) 已达上限，下次可以进阶加重")
    } else {
      showToast("已记录 \(exercise.name)")
    }
  }

  private func completeDayManually() async {
    var healthDuration: TimeInterval = 0
    var healthCalories: Double = 0
    if WorkoutHealthService.isAvailable {
      try? await WorkoutHealthService.requestReadAccess()
      healthAccessRequested = true
      if let health = try? await WorkoutHealthService.daySummary(for: dayPlan.date) {
        healthDuration = health.duration
        healthCalories = health.activeCalories
        healthSummary = health
        if health.isEmpty {
          showToast("未读到手表训练，复盘耗时/消耗可稍后下拉刷新同步")
        }
      }
    }

    guard WorkoutStore.tryCompleteDaySession(
      dayPlan: dayPlan,
      healthDuration: healthDuration,
      healthCalories: healthCalories,
      in: modelContext
    ) else {
      showToast("今天已经标记完成了")
      return
    }

    let summary = WorkoutSessionSummaryBuilder.build(
      dayPlan: dayPlan,
      healthDuration: healthDuration,
      healthCalories: healthCalories,
      in: modelContext
    )
    cachedSessionSummary = summary
    completionSummary = summary
  }

  private func refreshSessionSummary() {
    guard dayPlan.isSessionComplete else {
      cachedSessionSummary = nil
      return
    }
    cachedSessionSummary = WorkoutSessionSummaryBuilder.build(
      dayPlan: dayPlan,
      healthDuration: dayPlan.cachedHealthDuration,
      healthCalories: dayPlan.cachedHealthCalories,
      in: modelContext
    )
  }

  private func deleteExercise(_ exercise: WorkoutExercise) {
    WorkoutStore.deleteSessionLogs(
      templateID: exercise.templateID,
      on: dayPlan.date,
      in: modelContext
    )
    if exercise.isCompleted(on: dayPlan.date) {
      if let template = WorkoutStore.fetchTemplate(id: exercise.templateID, in: modelContext),
         let lastDate = template.lastSessionDate,
         Calendar.current.isDate(lastDate, inSameDayAs: dayPlan.date) {
        template.lastSessionDate = nil
      }
      exercise.lastSessionDate = nil
    }
    dayPlan.exercises.removeAll { $0.id == exercise.id }
    modelContext.delete(exercise)
    try? modelContext.save()
  }

  private func showToast(_ message: String) {
    toastMessage = message
    Task {
      try? await Task.sleep(for: .seconds(2.2))
      await MainActor.run { toastMessage = nil }
    }
  }
}

struct ExerciseLibraryPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

  @Bindable var dayPlan: WorkoutDayPlan
  @State private var selectedIDs: Set<UUID> = []
  @State private var filterPart: String?

  private var existingTemplateIDs: Set<UUID> {
    Set(dayPlan.exercises.map(\.templateID))
  }

  private var filteredTemplates: [ExerciseTemplate] {
    guard let filterPart else { return templates }
    return templates.filter { $0.bodyPart == filterPart }
  }

  private var groupedSections: [ExerciseTemplateGroup] {
    ExerciseTemplateGroup.build(from: filteredTemplates)
  }

  var body: some View {
    NavigationStack {
      Group {
        if templates.isEmpty {
          ContentUnavailableView(
            "动作库为空",
            systemImage: "dumbbell",
            description: Text("请先在动作库中添加常用动作")
          )
        } else {
          VStack(spacing: 0) {
            partFilterBar
            List {
              ForEach(groupedSections) { group in
                Section("\(group.part) · \(group.subpart)") {
                  ForEach(group.templates) { template in
                    templateRow(template)
                  }
                }
              }
            }
            .listStyle(.insetGrouped)
          }
        }
      }
      .navigationTitle("选择动作")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("添加") { addSelected() }
            .disabled(selectedIDs.isEmpty)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var partFilterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        filterChip(title: "全部", part: nil)
        ForEach(ExerciseBodyCatalog.parts) { part in
          if templates.contains(where: { $0.bodyPart == part.name }) {
            filterChip(title: part.name, part: part.name)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .background(AppTheme.pageBackground)
  }

  private func filterChip(title: String, part: String?) -> some View {
    let selected = filterPart == part
    return Button {
      filterPart = part
    } label: {
      Text(title)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(selected ? AppTheme.accent : Color(.systemGray6), in: Capsule())
        .foregroundStyle(selected ? .white : .primary)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func templateRow(_ template: ExerciseTemplate) -> some View {
    let alreadyAdded = existingTemplateIDs.contains(template.id)
    Button {
      guard !alreadyAdded else { return }
      toggleSelection(template.id)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(template.name)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
          Text(template.maxLabel)
            .font(.caption)
            .foregroundStyle(AppTheme.accent)
          Text(template.lastRecordLabel)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if alreadyAdded {
          Text("已添加")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Image(systemName: selectedIDs.contains(template.id) ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selectedIDs.contains(template.id) ? AppTheme.accent : .secondary)
        }
      }
    }
    .disabled(alreadyAdded)
  }

  private func toggleSelection(_ id: UUID) {
    if selectedIDs.contains(id) {
      selectedIDs.remove(id)
    } else {
      selectedIDs.insert(id)
    }
  }

  private func addSelected() {
    let sorted = templates.filter { selectedIDs.contains($0.id) }
    var nextOrder = dayPlan.exercises.count
    for template in sorted {
      guard !existingTemplateIDs.contains(template.id) else { continue }
      let exercise = WorkoutExercise(from: template, sortOrder: nextOrder)
      exercise.dayPlan = dayPlan
      dayPlan.exercises.append(exercise)
      modelContext.insert(exercise)
      nextOrder += 1
    }
    try? modelContext.save()
    dismiss()
  }
}

struct ExerciseLibraryManageView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

  var embedded = false

  @State private var showingCreate = false
  @State private var editingTemplate: ExerciseTemplate?
  @State private var mergeSourceTemplate: ExerciseTemplate?
  @State private var mergeTargetID: UUID?
  @State private var deletingTemplate: ExerciseTemplate?
  @State private var actionErrorMessage: String?

  private var groupedSections: [ExerciseTemplateGroup] {
    ExerciseTemplateGroup.build(from: templates)
  }

  var body: some View {
    Group {
      if embedded {
        libraryContent
      } else {
        NavigationStack {
          libraryContent
        }
      }
    }
  }

  private var libraryContent: some View {
    List {
      if templates.isEmpty {
        Text("添加常用动作，目标只需设置一次")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      ForEach(groupedSections) { group in
        Section("\(group.part) · \(group.subpart)") {
          ForEach(group.templates) { template in
            Button {
              editingTemplate = template
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                  .font(.body.weight(.medium))
                  .foregroundStyle(.primary)
                Text(template.maxLabel)
                  .font(.caption)
                  .foregroundStyle(AppTheme.accent)
                Text(template.lastRecordLabel)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .contextMenu {
              Button("编辑动作") {
                editingTemplate = template
              }
              Button("合并到其他动作") {
                mergeTargetID = nil
                mergeSourceTemplate = template
              }
              Button("删除动作", role: .destructive) {
                deletingTemplate = template
              }
            }
          }
          .onDelete { offsets in
            deleteTemplates(in: group, at: offsets)
          }
        }
      }
    }
    .navigationTitle("动作库")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !embedded {
        ToolbarItem(placement: .cancellationAction) {
          Button("完成") { dismiss() }
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button { showingCreate = true } label: {
          Image(systemName: "plus")
        }
      }
    }
    .sheet(isPresented: $showingCreate) {
      ExerciseTemplateEditorSheet(template: nil)
    }
    .sheet(item: $editingTemplate) { template in
      ExerciseTemplateEditorSheet(template: template)
    }
    .sheet(item: $mergeSourceTemplate) { source in
      ExerciseTemplateMergeSheet(
        source: source,
        targets: templates.filter { $0.id != source.id },
        selectedTargetID: $mergeTargetID
      ) { target in
        WorkoutStore.mergeTemplate(source: source, into: target, in: modelContext)
      }
    }
    .alert("删除动作？", isPresented: Binding(
      get: { deletingTemplate != nil },
      set: { if !$0 { deletingTemplate = nil } }
    )) {
      Button("取消", role: .cancel) { deletingTemplate = nil }
      Button("删除", role: .destructive) {
        if let template = deletingTemplate {
          WorkoutStore.deleteTemplate(template, in: modelContext)
        }
        deletingTemplate = nil
      }
    } message: {
      Text("仅删除该动作及其训练记录，不会影响菜谱记录。")
    }
    .alert("操作失败", isPresented: Binding(
      get: { actionErrorMessage != nil },
      set: { if !$0 { actionErrorMessage = nil } }
    )) {
      Button("知道了", role: .cancel) { actionErrorMessage = nil }
    } message: {
      Text(actionErrorMessage ?? "")
    }
  }

  private func deleteTemplates(in group: ExerciseTemplateGroup, at offsets: IndexSet) {
    for index in offsets {
      let template = group.templates[index]
      WorkoutStore.deleteTemplate(template, in: modelContext)
    }
  }
}

private struct ExerciseTemplateMergeSheet: View {
  @Environment(\.dismiss) private var dismiss

  let source: ExerciseTemplate
  let targets: [ExerciseTemplate]
  @Binding var selectedTargetID: UUID?
  let onMerge: (ExerciseTemplate) -> Void

  var body: some View {
    NavigationStack {
      List(targets) { target in
        Button {
          selectedTargetID = target.id
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(target.name)
                .foregroundStyle(.primary)
              Text(target.categoryLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedTargetID == target.id {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.accent)
            }
          }
        }
      }
      .navigationTitle("合并“\(source.name)”")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("合并") {
            guard let id = selectedTargetID,
                  let target = targets.first(where: { $0.id == id }) else { return }
            onMerge(target)
            dismiss()
          }
          .disabled(selectedTargetID == nil)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}

struct ExerciseTemplateGroup: Identifiable {
  let id: String
  let part: String
  let subpart: String
  let templates: [ExerciseTemplate]

  static func build(from templates: [ExerciseTemplate]) -> [ExerciseTemplateGroup] {
    let grouped = Dictionary(grouping: templates) { "\($0.bodyPart)|\($0.bodySubpart)" }
    return grouped.map { key, items in
      let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
      let part = parts.first ?? ExerciseBodyCatalog.otherPartName
      let subpart = parts.count > 1 ? parts[1] : ExerciseBodyCatalog.otherSubpartName
      return ExerciseTemplateGroup(
        id: key,
        part: part,
        subpart: subpart,
        templates: items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      )
    }
    .sorted { lhs, rhs in
      let left = sortIndex(part: lhs.part, subpart: lhs.subpart)
      let right = sortIndex(part: rhs.part, subpart: rhs.subpart)
      if left.part != right.part { return left.part < right.part }
      if left.sub != right.sub { return left.sub < right.sub }
      return lhs.part.localizedStandardCompare(rhs.part) == .orderedAscending
    }
  }

  private static func sortIndex(part: String, subpart: String) -> (part: Int, sub: Int) {
    let partIndex = ExerciseBodyCatalog.parts.firstIndex { $0.name == part } ?? 999
    let subIndex = ExerciseBodyCatalog.part(named: part)?.subparts.firstIndex(of: subpart) ?? 999
    return (partIndex, subIndex)
  }
}

struct ExerciseTemplateEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let template: ExerciseTemplate?

  @State private var name = ""
  @State private var bodyPart = ExerciseBodyCatalog.parts[0].name
  @State private var bodySubpart = ExerciseBodyCatalog.parts[0].subparts[0]
  @State private var maxSetsText = "4"
  @State private var maxRepsText = "12"
  @State private var weightText = ""
  @State private var targetSetsText = "4"
  @State private var targetRepsText = "10"
  @State private var errorMessage: String?

  private var subpartOptions: [String] {
    ExerciseBodyCatalog.part(named: bodyPart)?.subparts
      ?? [ExerciseBodyCatalog.otherSubpartName]
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("部位") {
          Picker("大类", selection: $bodyPart) {
            ForEach(ExerciseBodyCatalog.parts) { part in
              Text(part.name).tag(part.name)
            }
          }
          .onChange(of: bodyPart) { _, newPart in
            bodySubpart = ExerciseBodyCatalog.defaultSubpart(for: newPart)
          }

          Picker("细分", selection: $bodySubpart) {
            ForEach(subpartOptions, id: \.self) { sub in
              Text(sub).tag(sub)
            }
          }
        }

        Section("动作名称") {
          TextField("如：胸托划船", text: $name)
        }

        Section("目标（只需设置一次）") {
          HStack {
            TextField("目标组数", text: $maxSetsText)
              .keyboardType(.numberPad)
            Text("×")
            TextField("目标次数", text: $maxRepsText)
              .keyboardType(.numberPad)
          }
        }

        Section("起始 level（尚无记录时用）") {
          TextField("重量 kg", text: $weightText)
            .keyboardType(.decimalPad)
          HStack {
            TextField("组数", text: $targetSetsText)
              .keyboardType(.numberPad)
            Text("×")
            TextField("每组次数", text: $targetRepsText)
              .keyboardType(.numberPad)
          }
        }

        if let errorMessage {
          Section {
            Text(errorMessage).foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(template == nil ? "新建动作" : "编辑动作")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") { save() }
        }
      }
      .keyboardDoneToolbar()
      .onAppear {
        loadExisting()
        normalizeBodySelection()
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func normalizeBodySelection() {
    let normalized = ExerciseBodyCatalog.normalized(part: bodyPart, subpart: bodySubpart)
    bodyPart = normalized.0
    bodySubpart = normalized.1
  }

  private func loadExisting() {
    guard let template else { return }
    name = template.name
    bodyPart = template.bodyPart
    bodySubpart = template.bodySubpart
    maxSetsText = "\(template.maxSets)"
    maxRepsText = "\(template.maxReps)"
    if template.weightKg > 0 {
      weightText = formatWeight(template.weightKg)
    }
    targetSetsText = "\(template.targetSets)"
    targetRepsText = "\(template.targetReps)"
  }

  private func syncExercises(from template: ExerciseTemplate) {
    WorkoutStore.syncPlannedExercises(from: template, in: modelContext)
  }

  private func formatWeight(_ kg: Double) -> String {
    if kg.truncatingRemainder(dividingBy: 1) == 0 {
      return String(format: "%.0f", kg)
    }
    return String(format: "%.1f", kg)
  }

  private func save() {
    errorMessage = nil
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty,
          let maxSets = Int(maxSetsText.trimmingCharacters(in: .whitespaces)),
          let maxReps = Int(maxRepsText.trimmingCharacters(in: .whitespaces)),
          maxSets > 0, maxReps > 0 else {
      errorMessage = "请填写动作名和有效的目标组数次数"
      return
    }

    normalizeBodySelection()
    let normalized = ExerciseBodyCatalog.normalized(part: bodyPart, subpart: bodySubpart)

    let weight = Double(weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0
    let targetSets = Int(targetSetsText.trimmingCharacters(in: .whitespaces)) ?? 4
    let targetReps = Int(targetRepsText.trimmingCharacters(in: .whitespaces)) ?? 10

    do {
      if let template {
        try WorkoutStore.renameTemplate(template, to: trimmedName, in: modelContext)
        template.maxSets = maxSets
        template.maxReps = maxReps
        template.bodyPart = normalized.0
        template.bodySubpart = normalized.1
        template.isCardio = normalized.0 == "有氧"
        if weight > 0 {
          template.weightKg = weight
          template.targetSets = targetSets
          template.targetReps = targetReps
        }
        syncExercises(from: template)
      } else {
        let key = ExerciseTemplate.normalize(trimmedName)
        if WorkoutStore.allTemplates(in: modelContext).contains(where: { $0.nameKey == key }) {
          errorMessage = "已有同名动作"
          return
        }
        let created = ExerciseTemplate(
          name: trimmedName,
          bodyPart: normalized.0,
          bodySubpart: normalized.1,
          maxSets: maxSets,
          maxReps: maxReps,
          weightKg: max(0, weight),
          targetSets: targetSets,
          targetReps: targetReps
        )
        modelContext.insert(created)
      }
      try modelContext.save()
      dismiss()
    } catch {
      errorMessage = "保存失败：\(error.localizedDescription)"
    }
  }
}

struct WorkoutLogSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  let exercise: WorkoutExercise
  let sessionDate: Date
  let onSaved: () -> Void

  @State private var weightText = ""
  @State private var notesText = ""
  @State private var restSecondsLocal = 90
  @State private var targetSets = 0
  @State private var setReps: [Int] = []
  @State private var completedSets = 0
  @State private var quickInput = ""
  @State private var restEndDate: Date?
  @State private var errorMessage: String?
  @State private var didSetup = false

  private var allDone: Bool { completedSets >= targetSets && targetSets > 0 }
  private var isResting: Bool {
    guard let restEndDate else { return false }
    return restEndDate > Date()
  }
  private var restRemaining: Int? {
    guard let restEndDate else { return nil }
    return max(0, Int(ceil(restEndDate.timeIntervalSinceNow)))
  }
  private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          infoCard
          notesCard
          setsCard
          if let remaining = restRemaining, isResting {
            restTimerCard(remaining)
          }
          if allDone || completedSets > 0 { saveCard }
          if let msg = errorMessage {
            Text(msg).font(.footnote).foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 4)
          }
        }
        .padding(16)
      }
      .appPageBackground()
      .navigationTitle(exercise.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { cancelAndDismiss() }
        }
      }
      .keyboardDoneToolbar()
      .onAppear {
        if !didSetup {
          setup()
          didSetup = true
        } else {
          persistDraft()
        }
        WorkoutLogDraftStore.keepSheetOpen = true
      }
      .onReceive(ticker) { _ in tickRest() }
      .onChange(of: scenePhase) { _, phase in
        if phase == .background || phase == .inactive {
          persistDraft()
        }
      }
      .onChange(of: weightText) { _, _ in persistDraft() }
      .onChange(of: notesText) { _, _ in persistDraft() }
      .onChange(of: restSecondsLocal) { _, _ in persistDraft() }
      .onChange(of: targetSets) { _, _ in persistDraft() }
      .onChange(of: setReps) { _, _ in persistDraft() }
      .onChange(of: completedSets) { _, _ in persistDraft() }
      .onChange(of: quickInput) { _, _ in persistDraft() }
      .onDisappear {
        // Keep draft if user is just backgrounding; clear only on explicit cancel/save.
        persistDraft()
      }
    }
    .presentationDetents([.large])
    .interactiveDismissDisabled(completedSets > 0 || isResting)
  }

  // MARK: - Cards

  private var infoCard: some View {
    VStack(spacing: 12) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("重量").font(.caption).foregroundStyle(.secondary)
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField("—", text: $weightText)
              .keyboardType(.decimalPad)
              .font(.title2.weight(.bold))
              .frame(width: 72)
            Text("kg").font(.subheadline).foregroundStyle(.secondary)
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("间歇").font(.caption).foregroundStyle(.secondary)
          HStack(spacing: 6) {
            Button { restSecondsLocal = max(0, restSecondsLocal - 15) } label: {
              Image(systemName: "minus.circle").foregroundStyle(AppTheme.accent)
            }
            Text("\(restSecondsLocal)s").font(.subheadline.weight(.semibold)).frame(width: 40)
            Button { restSecondsLocal = min(600, restSecondsLocal + 15) } label: {
              Image(systemName: "plus.circle").foregroundStyle(AppTheme.accent)
            }
          }
        }
      }
      Divider()
      VStack(alignment: .leading, spacing: 6) {
        Text(exercise.maxLabel)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AppTheme.accent)
        Text(lastRecordDisplay)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var notesCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("本次要求")
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField("如：力竭、顶峰停顿、控制离心…", text: $notesText, axis: .vertical)
        .lineLimit(2...5)
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var setsCard: some View {
    VStack(spacing: 0) {
      HStack {
        Text("组数")
          .font(.subheadline.weight(.semibold))
        Spacer()
        HStack(spacing: 10) {
          Button {
            shrinkTargetSets()
          } label: {
            Image(systemName: "minus.circle.fill")
              .font(.title3)
              .foregroundStyle(targetSets <= max(1, completedSets) ? Color.secondary.opacity(0.35) : AppTheme.accent)
          }
          .disabled(targetSets <= max(1, completedSets))

          Text("\(targetSets)")
            .font(.title3.weight(.semibold).monospacedDigit())
            .frame(minWidth: 28)

          Button {
            growTargetSets()
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.title3)
              .foregroundStyle(targetSets >= 20 ? Color.secondary.opacity(0.35) : AppTheme.accent)
          }
          .disabled(targetSets >= 20)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)

      Divider().padding(.leading, 14)

      HStack {
        TextField("快速输入 6645", text: $quickInput)
          .keyboardType(.numberPad)
          .font(.subheadline.monospacedDigit())
          .onChange(of: quickInput) { _, newValue in
            applyQuickInput(newValue)
          }
        if !quickInput.isEmpty {
          Button {
            quickInput = ""
            completedSets = 0
            setReps = Array(repeating: max(1, exercise.targetReps), count: targetSets)
            clearRest()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)

      Divider().padding(.leading, 14)

      ForEach(0..<targetSets, id: \.self) { i in
        setRow(index: i)
        if i < targetSets - 1 {
          Divider().padding(.leading, 56)
        }
      }
    }
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder
  private func setRow(index i: Int) -> some View {
    let isDone = i < completedSets
    let isActive = i == completedSets && !isResting

    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(isDone ? Color.green : (isActive ? AppTheme.accent : Color(.systemGray5)))
          .frame(width: 34, height: 34)
        if isDone {
          Image(systemName: "checkmark")
            .font(.caption.weight(.bold)).foregroundStyle(.white)
        } else {
          Text("\(i + 1)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isActive ? .white : .secondary)
        }
      }

      Text("第 \(i + 1) 组")
        .font(.subheadline)
        .foregroundStyle(isDone ? .secondary : .primary)

      Spacer()

      if isDone {
        Text("\(setReps[safe: i] ?? 0) 次")
          .font(.subheadline)
          .foregroundStyle((setReps[safe: i] ?? 0) >= exercise.maxReps ? .green : .orange)
      } else if isActive {
        HStack(spacing: 2) {
          Button {
            if setReps.indices.contains(i), setReps[i] > 1 { setReps[i] -= 1 }
          } label: {
            Image(systemName: "minus.circle.fill")
              .font(.title3).foregroundStyle(AppTheme.accent)
          }
          Text("\(setReps[safe: i] ?? max(1, exercise.targetReps))")
            .font(.title3.weight(.semibold))
            .frame(width: 34)
            .multilineTextAlignment(.center)
          Button {
            if setReps.indices.contains(i), setReps[i] < 99 { setReps[i] += 1 }
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.title3).foregroundStyle(AppTheme.accent)
          }
          Text("/\(exercise.maxReps)").font(.caption).foregroundStyle(.secondary)
        }

        Button("完成") { completeSet(index: i) }
          .buttonStyle(.borderedProminent)
          .tint(AppTheme.accent)
          .controlSize(.small)
          .padding(.leading, 8)
      } else {
        Text("\(setReps[safe: i] ?? max(1, exercise.targetReps)) 次")
          .font(.subheadline).foregroundStyle(.tertiary)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .opacity(!isDone && !isActive ? 0.4 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: completedSets)
  }

  private func restTimerCard(_ remaining: Int) -> some View {
    let total = max(restSecondsLocal, 1)
    let progress = Double(total - remaining) / Double(total)
    let isUrgent = remaining <= 10

    return VStack(spacing: 10) {
      HStack {
        Label("间歇中", systemImage: "timer")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(isUrgent ? .red : AppTheme.accent)
        Spacer()
        Button("跳过") { clearRest() }
          .font(.subheadline).foregroundStyle(.secondary)
      }

      Text("\(remaining)")
        .font(.system(size: 52, weight: .bold, design: .monospaced))
        .foregroundStyle(isUrgent ? .red : .primary)
        .contentTransition(.numericText())
        .animation(.easeInOut, value: remaining)

      ProgressView(value: min(max(progress, 0), 1))
        .tint(isUrgent ? .red : AppTheme.accent)
        .scaleEffect(y: 1.5)

      Text("切到其他 App 时，倒计时会显示在灵动岛 / 锁屏")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var saveCard: some View {
    VStack(spacing: 8) {
      Button { save() } label: {
        Label(
          allDone ? "保存记录" : "提前结束（\(completedSets)/\(targetSets) 组）",
          systemImage: "checkmark.circle.fill"
        )
        .frame(maxWidth: .infinity)
        .font(.headline)
      }
      .buttonStyle(.borderedProminent)
      .tint(allDone ? AppTheme.accent : .orange)

      if !allDone {
        Text("还有 \(targetSets - completedSets) 组未完成").font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Logic

  private var lastRecordDisplay: String {
    if let template = WorkoutStore.fetchTemplate(id: exercise.templateID, in: modelContext),
       let log = WorkoutStore.sessionLogs(for: template.id, in: modelContext).last,
       log.weightKg > 0 {
      let status = log.completedFully ? "做满" : "没做满"
      let repsPart = WorkoutFormat.sessionRepsLabel(
        sets: log.sets,
        maxReps: exercise.maxReps,
        setRepsLog: log.setRepsLog
      )
      return "\(WorkoutFormat.weight(log.weightKg)) \(repsPart) · \(status)"
    }
    return exercise.lastRecordLabel
  }

  private func setup() {
    if let draft = WorkoutLogDraftStore.load(for: exercise.id) {
      restore(from: draft)
      return
    }

    let template = WorkoutStore.fetchTemplate(id: exercise.templateID, in: modelContext)
    let w = exercise.lastWeightKg > 0
      ? exercise.lastWeightKg
      : (template?.effectiveWeightKg ?? exercise.weightKg)
    weightText = w > 0 ? (w.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", w)
      : String(format: "%.1f", w)) : ""
    restSecondsLocal = max(0, exercise.restSeconds)
    notesText = exercise.sessionNotes
    // Prefer today's planned sets, not last session count.
    let plannedSets = exercise.targetSets > 0
      ? exercise.targetSets
      : (template?.targetSets ?? exercise.maxSets)
    targetSets = max(1, plannedSets)
    setReps = Array(repeating: max(1, exercise.targetReps), count: targetSets)
    completedSets = 0
    quickInput = ""
    restEndDate = nil
    persistDraft()
  }

  private func restore(from draft: WorkoutLogDraft) {
    weightText = draft.weightText
    notesText = draft.notesText
    restSecondsLocal = draft.restSeconds
    targetSets = max(1, draft.targetSets)
    setReps = draft.setReps
    if setReps.count < targetSets {
      setReps.append(contentsOf: Array(repeating: max(1, exercise.targetReps), count: targetSets - setReps.count))
    } else if setReps.count > targetSets {
      setReps = Array(setReps.prefix(targetSets))
    }
    completedSets = min(draft.completedSets, targetSets)
    quickInput = draft.quickInput
    if let end = draft.restEndDate, end > Date() {
      restEndDate = end
      RestTimerLiveActivityController.start(
        exerciseName: exercise.name,
        setNumber: completedSets,
        totalSets: targetSets,
        endDate: end
      )
    } else {
      restEndDate = nil
      RestTimerLiveActivityController.endAll()
    }
  }

  private func growTargetSets() {
    guard targetSets < 20 else { return }
    targetSets += 1
    setReps.append(max(1, exercise.targetReps))
  }

  private func shrinkTargetSets() {
    let minimum = max(1, completedSets)
    guard targetSets > minimum else { return }
    targetSets -= 1
    if setReps.count > targetSets {
      setReps.removeLast(setReps.count - targetSets)
    }
  }

  private func applyQuickInput(_ text: String) {
    let digits = text.compactMap { Int(String($0)) }
    guard !digits.isEmpty else { return }

    if digits.count > targetSets {
      let extra = digits.count - targetSets
      targetSets = min(20, targetSets + extra)
      while setReps.count < targetSets {
        setReps.append(max(1, exercise.targetReps))
      }
    }

    for index in 0..<min(digits.count, targetSets) {
      setReps[index] = max(1, digits[index])
    }

    if digits.count >= targetSets {
      completedSets = targetSets
      clearRest()
    } else {
      completedSets = digits.count
    }
  }

  private func completeSet(index: Int) {
    guard index == completedSets else { return }
    completedSets += 1
    if completedSets < targetSets, restSecondsLocal > 0 {
      let end = Date().addingTimeInterval(TimeInterval(restSecondsLocal))
      restEndDate = end
      RestTimerLiveActivityController.start(
        exerciseName: exercise.name,
        setNumber: completedSets,
        totalSets: targetSets,
        endDate: end
      )
    } else {
      clearRest()
    }
    persistDraft()
  }

  private func tickRest() {
    guard let restEndDate else { return }
    if restEndDate <= Date() {
      clearRest()
    }
  }

  private func clearRest() {
    restEndDate = nil
    RestTimerLiveActivityController.endAll()
    persistDraft()
  }

  private func persistDraft() {
    guard didSetup || targetSets > 0 else { return }
    let draft = WorkoutLogDraft(
      exerciseID: exercise.id,
      weightText: weightText,
      notesText: notesText,
      restSeconds: restSecondsLocal,
      targetSets: targetSets,
      setReps: setReps,
      completedSets: completedSets,
      quickInput: quickInput,
      restEndDate: restEndDate,
      updatedAt: Date()
    )
    WorkoutLogDraftStore.save(draft)
    WorkoutLogDraftStore.keepSheetOpen = true
  }

  private func cancelAndDismiss() {
    clearRest()
    WorkoutLogDraftStore.clear()
    dismiss()
  }

  private func save() {
    guard let weight = Double(weightText), weight > 0 else {
      errorMessage = "请填写有效重量"
      return
    }
    guard completedSets > 0 else {
      errorMessage = "请至少完成一组"
      return
    }

    let doneReps = Array(setReps.prefix(completedSets))
    let setRepsLog = doneReps.map(String.init).joined()
    let completedFully = completedSets >= exercise.maxSets
      && doneReps.allSatisfy { $0 >= exercise.maxReps }

    exercise.restSeconds = restSecondsLocal
    exercise.sessionNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)

    let template = WorkoutStore.fetchTemplate(id: exercise.templateID, in: modelContext)
    WorkoutStore.applySessionLog(
      to: exercise,
      template: template,
      weightKg: weight,
      sets: completedSets,
      reps: exercise.maxReps,
      setRepsLog: setRepsLog,
      completedFully: completedFully,
      sessionDate: sessionDate,
      in: modelContext
    )
    clearRest()
    WorkoutLogDraftStore.clear()
    onSaved()
    dismiss()
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

struct ExerciseNotesSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Bindable var exercise: WorkoutExercise

  var body: some View {
    NavigationStack {
      TextEditor(text: $exercise.sessionNotes)
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(16)
        .appPageBackground()
        .navigationTitle("训练备注")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("取消") { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("保存") { saveAndDismiss() }
          }
        }
        .keyboardDoneToolbar()
    }
    .presentationDetents([.medium])
  }

  private func saveAndDismiss() {
    exercise.sessionNotes = exercise.sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    try? modelContext.save()
    dismiss()
  }
}

struct WorkoutDayMoveSheet: View {
  @Environment(\.dismiss) private var dismiss

  let sourceDate: Date
  let navigationTitle: String
  let onSelect: (Date) -> Void

  @State private var weekStart: Date

  init(sourceDate: Date, navigationTitle: String = "选择日期", onSelect: @escaping (Date) -> Void) {
    self.sourceDate = sourceDate
    self.navigationTitle = navigationTitle
    self.onSelect = onSelect
    _weekStart = State(initialValue: WorkoutCalendar.startOfWeek(for: sourceDate))
  }

  private var weekDays: [Date] {
    WorkoutCalendar.daysInWeek(starting: weekStart)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("从 \(sourceDate.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide))) 移到")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        weekNavigator

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
          ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
            Text(label)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
          }
          ForEach(weekDays, id: \.self) { day in
            dayButton(for: day)
          }
        }

        Spacer(minLength: 0)
      }
      .padding(16)
      .appPageBackground()
      .navigationTitle(navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
  }

  private var weekNavigator: some View {
    HStack {
      Button { shiftWeek(by: -1) } label: {
        Image(systemName: "chevron.left.circle.fill")
          .foregroundStyle(AppTheme.accent)
      }
      Text(WorkoutCalendar.weekRangeLabel(for: weekStart))
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
      Button { shiftWeek(by: 1) } label: {
        Image(systemName: "chevron.right.circle.fill")
          .foregroundStyle(AppTheme.accent)
      }
    }
    .padding(12)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func dayButton(for day: Date) -> some View {
    let isSource = Calendar.current.isDate(day, inSameDayAs: sourceDate)
    let isToday = Calendar.current.isDateInToday(day)

    return Button {
      onSelect(day)
      dismiss()
    } label: {
      VStack(spacing: 4) {
        Text(day.formatted(.dateTime.day()))
          .font(.subheadline.weight(isToday ? .bold : .medium))
        Text(day.formatted(.dateTime.weekday(.abbreviated)))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        isSource ? Color(.systemGray4) : AppTheme.accentSoft,
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .overlay {
        if isToday {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.accent, lineWidth: 1.5)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(isSource)
  }

  private func shiftWeek(by offset: Int) {
    if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart) {
      weekStart = WorkoutCalendar.startOfWeek(for: newStart)
    }
  }
}
