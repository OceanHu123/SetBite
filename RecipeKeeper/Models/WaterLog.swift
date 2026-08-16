import Foundation
import SwiftData

@Model
final class WaterLog: Identifiable {
  var id: UUID
  var createdAt: Date
  var amountMl: Double

  init(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    amountMl: Double
  ) {
    self.id = id
    self.createdAt = createdAt
    self.amountMl = amountMl
  }
}
