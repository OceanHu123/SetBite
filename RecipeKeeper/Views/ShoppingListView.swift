import SwiftData
import SwiftUI

struct ShoppingListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var items: [ShoppingItem]
  @Query(sort: \PantryItem.createdAt, order: .reverse) private var pantryItems: [PantryItem]

  @State private var newItemName = ""
  @State private var newPantryName = ""
  @State private var isPantryExpanded = false

  private var pendingItems: [ShoppingItem] {
    items.filter { !$0.isPurchased }
  }

  private var purchasedItems: [ShoppingItem] {
    items.filter(\.isPurchased)
  }

  var body: some View {
    List {
      Section {
        DisclosureGroup(isExpanded: $isPantryExpanded) {
          HStack {
            TextField("添加常备", text: $newPantryName)
            Button("添加") { addPantryItem() }
              .disabled(newPantryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }

          if pantryItems.isEmpty {
            Text("暂无常备物品")
              .font(.footnote)
              .foregroundStyle(.secondary)
          } else {
            ForEach(pantryItems) { item in
              HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                  .foregroundStyle(AppTheme.accent)
                  .font(.caption)
                Text(item.name)
              }
            }
            .onDelete(perform: deletePantryItems)
          }
        } label: {
          HStack {
            Label("常备物品", systemImage: "cabinet.fill")
            Spacer()
            Text("\(pantryItems.count) 项")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } footer: {
        Text("常备物品加入待购时会自动跳过")
      }

      Section {
        HStack {
          TextField("添加待购食材", text: $newItemName)
          Button("添加") { addManualItem() }
            .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      } header: {
        Label("待购买", systemImage: "cart.fill")
      }

      if pendingItems.isEmpty && purchasedItems.isEmpty {
        Section {
          ContentUnavailableView("待购是空的", systemImage: "cart")
        }
      }

      if !pendingItems.isEmpty {
        Section {
          ForEach(pendingItems) { item in
            shoppingRow(item, purchased: false)
          }
          .onDelete(perform: deletePending)
        }
      }

      if !purchasedItems.isEmpty {
        Section("已购买") {
          ForEach(purchasedItems) { item in
            shoppingRow(item, purchased: true)
          }
          .onDelete(perform: deletePurchased)
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .appPageBackground()
    .dismissKeyboardOnTap()
    .keyboardDoneToolbar()
    .navigationTitle("待购")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !purchasedItems.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          Button("清除已购") { clearPurchased() }
            .font(.subheadline)
        }
      }
    }
  }

  private func shoppingRow(_ item: ShoppingItem, purchased: Bool) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Button { togglePurchased(item) } label: {
        Image(systemName: purchased ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(purchased ? .green : .secondary)
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.displayTitle)
          .font(.body.weight(.semibold))
          .strikethrough(purchased)
          .foregroundStyle(purchased ? .secondary : .primary)
        if !item.recipeTitle.isEmpty {
          Text(item.recipeTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 2)
  }

  private func addPantryItem() {
    let name = newPantryName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    let normalized = IngredientMatcher.normalize(name)
    guard !pantryItems.contains(where: { IngredientMatcher.normalize($0.name) == normalized }) else {
      newPantryName = ""
      return
    }
    modelContext.insert(PantryItem(name: name))
    newPantryName = ""
    try? modelContext.save()
  }

  private func addManualItem() {
    let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    modelContext.insert(ShoppingItem(ingredientName: name, amount: "", recipeTitle: "手动添加"))
    newItemName = ""
    try? modelContext.save()
  }

  private func deletePantryItems(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(pantryItems[index])
    }
    try? modelContext.save()
  }

  private func deletePending(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(pendingItems[index])
    }
    try? modelContext.save()
  }

  private func deletePurchased(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(purchasedItems[index])
    }
    try? modelContext.save()
  }

  private func togglePurchased(_ item: ShoppingItem) {
    item.isPurchased.toggle()
    try? modelContext.save()
  }

  private func clearPurchased() {
    for item in purchasedItems { modelContext.delete(item) }
    try? modelContext.save()
  }
}
