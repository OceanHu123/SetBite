import ActivityKit
import Foundation

@MainActor
enum RestTimerLiveActivityController {
  static func start(exerciseName: String, setNumber: Int, totalSets: Int, endDate: Date) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    endAll()

    let attributes = RestTimerAttributes(exerciseName: exerciseName)
    let state = RestTimerAttributes.ContentState(
      endDate: endDate,
      setNumber: setNumber,
      totalSets: totalSets
    )

    do {
      _ = try Activity.request(
        attributes: attributes,
        content: .init(state: state, staleDate: endDate),
        pushType: nil
      )
    } catch {
      // Live Activity may be disabled by the user; ignore.
    }
  }

  static func endAll() {
    for activity in Activity<RestTimerAttributes>.activities {
      let state = activity.content.state
      Task {
        await activity.end(
          .init(state: state, staleDate: nil),
          dismissalPolicy: .immediate
        )
      }
    }
  }
}
