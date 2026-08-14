import Foundation
import SwiftData

enum RecipeShoppingHelper {
  static func deleteShoppingItems(for recipeID: UUID, in items: [ShoppingItem], context: ModelContext) {
    for item in items where item.recipeID == recipeID {
      context.delete(item)
    }
  }
}
