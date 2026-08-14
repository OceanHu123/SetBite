import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    TabView {
      RecipeListView()
        .tabItem { Label("Eat", systemImage: "fork.knife") }

      BodyTrackerView()
        .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
    }
    .tint(AppTheme.accent)
    .onAppear {
      DefaultPantrySeeder.seedIfNeeded(context: modelContext)
      DefaultExerciseSeeder.seedIfNeeded(context: modelContext)
      WorkoutStore.mergeCanonicalDuplicates(in: modelContext)
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(ImportCoordinator())
    .modelContainer(for: [
      Recipe.self, ShoppingItem.self, PantryItem.self, CookingLog.self, MealMacroLog.self, BodyRecord.self,
      WorkoutWeekPlan.self, WorkoutDayPlan.self, WorkoutExercise.self, ExerciseTemplate.self,
      ExerciseSessionLog.self
    ], inMemory: true)
}
