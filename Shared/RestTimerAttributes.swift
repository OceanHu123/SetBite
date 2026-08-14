import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var endDate: Date
    var setNumber: Int
    var totalSets: Int
  }

  var exerciseName: String
}
