import Foundation
import SwiftData

@Model
final class BodyRecord: Identifiable {
  var id: UUID
  var date: Date
  var weight: Double
  var waist: Double
  var arm: Double
  var createdAt: Date

  init(date: Date, weight: Double, waist: Double, arm: Double) {
    self.id = UUID()
    self.date = Calendar.current.startOfDay(for: date)
    self.weight = weight
    self.waist = waist
    self.arm = arm
    self.createdAt = Date()
  }

  var dayLabel: String {
    date.formatted(.dateTime.month(.abbreviated).day())
  }
}

struct BodyAnalysisResult: Codable {
  let trend: String
  let summary: String
  let bodyFatPercent: String
  let goalDistance: String
  let targetDescription: String
  let encouragement: String
  let tips: [String]
}
