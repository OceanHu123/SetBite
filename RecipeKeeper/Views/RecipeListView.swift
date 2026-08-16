import SwiftData
import SwiftUI

struct RecipeListView: View {
  @EnvironmentObject private var importCoordinator: ImportCoordinator
  @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
  @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var shoppingItems: [ShoppingItem]
  @State private var showingAdd = false
  @State private var searchText = ""
  @State private var selectedCategory: String?
  @State private var navigationPath = NavigationPath()

  private let columns = [
    GridItem(.flexible(), spacing: 16, alignment: .top),
    GridItem(.flexible(), spacing: 16, alignment: .top)
  ]

  private var filteredRecipes: [Recipe] {
    recipes.filter { recipe in
      let matchesCategory = selectedCategory == nil || recipe.effectiveCategories.contains(selectedCategory!)
      guard matchesCategory else { return false }

      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !query.isEmpty else { return true }

      if recipe.title.localizedCaseInsensitiveContains(query) { return true }
      if recipe.effectiveCategories.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
      return RecipeCategoryCatalog.matchesIngredient(recipe, query: query)
    }
  }

  private var pendingShoppingCount: Int {
    shoppingItems.filter { !$0.isPurchased }.count
  }

  var body: some View {
    NavigationStack(path: $navigationPath) {
      ScrollView {
        VStack(spacing: 16) {
          categoryFilterBar

          if recipes.isEmpty {
            ContentUnavailableView(L10n.noRecipes, systemImage: "book.closed")
              .padding(.top, 40)
          } else if filteredRecipes.isEmpty {
            ContentUnavailableView(L10n.noMatch, systemImage: "magnifyingglass")
              .padding(.top, 40)
          } else {
            LazyVGrid(columns: columns, spacing: 16) {
              ForEach(filteredRecipes) { recipe in
                RecipeCard(recipe: recipe)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
                  .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                  .onTapGesture {
                    navigationPath.append(recipe.id)
                  }
              }
            }
          }
        }
        .padding(16)
      }
      .appPageBackground()
      .navigationDestination(for: UUID.self) { id in
        if let recipe = recipes.first(where: { $0.id == id }) {
          RecipeDetailView(recipe: recipe)
        }
      }
      .navigationDestination(for: EatDestination.self) { destination in
        switch destination {
        case .shopping:
          ShoppingListView()
        case .settings:
          SettingsContentView()
        case .calories:
          MealCalorieView()
        }
      }
      .navigationTitle(L10n.appName)
      .navigationBarTitleDisplayMode(.large)
      .searchable(text: $searchText, prompt: L10n.search)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            navigationPath.append(EatDestination.settings)
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel(L10n.settings)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            navigationPath.append(EatDestination.calories)
          } label: {
            Image(systemName: "flame.fill")
          }
          .accessibilityLabel(L10n.dietRecord)

          Button {
            navigationPath.append(EatDestination.shopping)
          } label: {
            Image(systemName: pendingShoppingCount > 0 ? "cart.fill" : "cart")
              .overlay(alignment: .topTrailing) {
                if pendingShoppingCount > 0 {
                  Text("\(min(pendingShoppingCount, 99))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red, in: Capsule())
                    .offset(x: 8, y: -8)
                }
              }
          }
          .accessibilityLabel(L10n.shoppingList)

          Button {
            showingAdd = true
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.title3)
              .symbolRenderingMode(.palette)
              .foregroundStyle(.white, AppTheme.accent)
          }
          .accessibilityLabel(L10n.newRecipe)
        }
      }
      .sheet(isPresented: $showingAdd) {
        AddRecipeView(onFinished: { showingAdd = false })
      }
      .sheet(isPresented: $importCoordinator.showAddRecipe) {
        AddRecipeView(
          sharedImport: importCoordinator.pendingImport,
          onFinished: { importCoordinator.clearSharedFiles() }
        )
      }
    }
  }

  private var categoryFilterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        categoryChip(title: L10n.t("All", "全部"), category: nil)
        ForEach(RecipeCategoryCatalog.all, id: \.self) { category in
          categoryChip(title: category, category: category)
        }
      }
      .padding(.horizontal, 2)
    }
  }

  private func categoryChip(title: String, category: String?) -> some View {
    let isSelected = selectedCategory == category
    return Button {
      selectedCategory = category
    } label: {
      Text(title)
        .font(AppTheme.bodyFont(size: 12, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
          isSelected ? AppTheme.accent : AppTheme.cardBackground.opacity(0.92),
          in: Capsule()
        )
        .foregroundStyle(isSelected ? .white : .primary)
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: 8, y: 2)
    }
    .buttonStyle(.plain)
  }
}

private enum EatDestination: Hashable {
  case shopping
  case settings
  case calories
}

struct RecipeCard: View {
  let recipe: Recipe

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      RecipeCoverImage(data: recipe.coverImageData, height: 128, cornerRadius: 20)
        .padding(8)

      VStack(alignment: .leading, spacing: 6) {
        Text(recipe.title)
          .font(AppTheme.bodyFont(size: 15, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(2)
        if !recipe.effectiveCategories.isEmpty {
          HStack(spacing: 4) {
            ForEach(recipe.effectiveCategories.prefix(2), id: \.self) { category in
              Text(category)
                .font(AppTheme.bodyFont(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.accentSoft, in: Capsule())
            }
            if recipe.effectiveCategories.count > 2 {
              Text("+\(recipe.effectiveCategories.count - 2)")
                .font(AppTheme.bodyFont(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }
          }
        }
        HStack(spacing: 8) {
          Label("\(recipe.ingredientNames.count)", systemImage: "basket")
          Label("\(recipe.steps.count)", systemImage: "list.number")
        }
        .font(AppTheme.bodyFont(size: 10))
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
    }
    .appCardStyle()
  }
}
