import SwiftData
import SwiftUI

struct ToCookView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var allRecipes: [Recipe]
  @Query(sort: \CookingLog.date, order: .reverse) private var cookingLogs: [CookingLog]
  @Query private var shoppingItems: [ShoppingItem]

  @State private var selectedWeekStart = WorkoutCalendar.startOfWeek(for: Date())
  @State private var selectedDay: Date?
  @State private var reschedulingLog: CookingLog?

  private var toCookRecipes: [Recipe] {
    allRecipes
      .filter(\.isInToCook)
      .sorted { ($0.toCookAddedAt ?? .distantPast) > ($1.toCookAddedAt ?? .distantPast) }
  }

  private var weekDays: [Date] {
    WorkoutCalendar.daysInWeek(starting: selectedWeekStart)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          weekNavigator
          cookingCalendarCard
          if let selectedDay {
            selectedDayCard(selectedDay)
          }
          toCookSection
        }
        .padding(16)
        .padding(.bottom, 16)
      }
      .appPageBackground()
      .navigationTitle("🍳 待做")
      .navigationBarTitleDisplayMode(.large)
      .sheet(isPresented: Binding(
        get: { reschedulingLog != nil },
        set: { if !$0 { reschedulingLog = nil } }
      )) {
        if let log = reschedulingLog {
          WorkoutDayMoveSheet(sourceDate: log.date, navigationTitle: "改到哪天") { newDate in
            CookingStore.rescheduleLog(log, to: newDate, in: modelContext)
            selectedDay = Calendar.current.startOfDay(for: newDate)
            reschedulingLog = nil
          }
        }
      }
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
        Text(isCurrentWeek ? "本周" : "记录周")
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

  private var isCurrentWeek: Bool {
    Calendar.current.isDate(
      selectedWeekStart,
      inSameDayAs: WorkoutCalendar.startOfWeek(for: Date())
    )
  }

  private var cookingCalendarCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("做饭日历")
        .font(.headline)
        .foregroundStyle(AppTheme.accent)
      Text("点选日期查看当天做过的菜")
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

  private func dayCell(for day: Date) -> some View {
    let logs = CookingStore.logs(on: day, in: cookingLogs)
    let label = logs.map(\.recipeTitle).joined()
    let isToday = Calendar.current.isDateInToday(day)
    let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
    let hasCooked = !label.isEmpty

    return Button {
      selectedDay = day
    } label: {
      VStack(spacing: 4) {
        Text(day.formatted(.dateTime.day()))
          .font(.subheadline.weight(isToday ? .bold : .medium))
        if hasCooked {
          Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(AppTheme.accent, in: Capsule())
        } else {
          Text("—")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(
        isSelected ? AppTheme.accent.opacity(0.18) : (isToday ? AppTheme.accentSoft : Color(.systemGray6)),
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
  }

  private func selectedDayCard(_ day: Date) -> some View {
    let logs = CookingStore.logs(on: day, in: cookingLogs)

    return VStack(alignment: .leading, spacing: 12) {
      Text(day.formatted(.dateTime.month(.wide).day().weekday(.wide)))
        .font(.headline)
        .foregroundStyle(AppTheme.accent)

      if logs.isEmpty {
        Text("这天还没有记录")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(logs) { log in
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
              Text(log.recipeTitle)
                .font(.subheadline)
              Text(log.date.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
              reschedulingLog = log
            } label: {
              Image(systemName: "calendar")
                .font(.caption)
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
              deleteLog(log)
            } label: {
              Image(systemName: "trash")
                .font(.caption)
            }
            .buttonStyle(.borderless)
          }
          .padding(.vertical, 4)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var toCookSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("待做清单")
        .font(.headline)
        .foregroundStyle(AppTheme.accent)

      if toCookRecipes.isEmpty {
        Text("还没有待做的菜，去食谱里加入待做吧")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      } else {
        VStack(spacing: 0) {
          ForEach(toCookRecipes) { recipe in
            toCookRow(recipe)
            if recipe.id != toCookRecipes.last?.id {
              Divider().padding(.leading, 16)
            }
          }
        }
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
  }

  private func toCookRow(_ recipe: Recipe) -> some View {
    HStack(spacing: 12) {
      NavigationLink {
        RecipeDetailView(recipe: recipe)
      } label: {
        HStack(spacing: 12) {
          RecipeCoverImage(data: recipe.coverImageData, height: 56, cornerRadius: 10)
            .frame(width: 56, height: 56)
          VStack(alignment: .leading, spacing: 4) {
            Text(recipe.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
            Text("\(recipe.steps.count) 个步骤")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
        }
      }
      .buttonStyle(.plain)

      Button("做完了") {
        markCooked(recipe)
      }
      .buttonStyle(.borderedProminent)
      .tint(.green)
      .controlSize(.small)
    }
    .padding(12)
  }

  private func shiftWeek(by offset: Int) {
    if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) {
      selectedWeekStart = WorkoutCalendar.startOfWeek(for: newStart)
    }
  }

  private func markCooked(_ recipe: Recipe) {
    let today = Calendar.current.startOfDay(for: Date())
    CookingStore.markCooked(recipe, on: today, in: modelContext)
    RecipeShoppingHelper.deleteShoppingItems(
      for: recipe.id,
      in: shoppingItems,
      context: modelContext
    )
    selectedDay = today
    selectedWeekStart = WorkoutCalendar.startOfWeek(for: today)
  }

  private func deleteLog(_ log: CookingLog) {
    modelContext.delete(log)
    try? modelContext.save()
  }
}
