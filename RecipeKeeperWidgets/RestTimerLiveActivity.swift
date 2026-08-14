import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RecipeKeeperWidgets: WidgetBundle {
  var body: some Widget {
    RestTimerLiveActivity()
  }
}

struct RestTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestTimerAttributes.self) { context in
      RestTimerLockScreenView(context: context)
        .padding(16)
    } dynamicIsland: { context in
      let timerRange = timerRange(for: context.state.endDate)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.attributes.exerciseName, systemImage: "dumbbell.fill")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("第\(context.state.setNumber)/\(context.state.totalSets)组")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text("间歇")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Text(timerInterval: timerRange, countsDown: true, showsHours: false)
              .font(.title3.weight(.bold).monospacedDigit())
              .multilineTextAlignment(.trailing)
          }
        }
      } compactLeading: {
        Image(systemName: "figure.strengthtraining.traditional")
      } compactTrailing: {
        Text(timerInterval: timerRange, countsDown: true, showsHours: false)
          .monospacedDigit()
          .frame(width: 48)
          .multilineTextAlignment(.trailing)
      } minimal: {
        Image(systemName: "figure.strengthtraining.traditional")
      }
      .widgetURL(URL(string: "recipekeeper://workout"))
    }
  }

  private func timerRange(for endDate: Date) -> ClosedRange<Date> {
    let start = Date()
    let end = max(endDate, start.addingTimeInterval(1))
    return start...end
  }
}

private struct RestTimerLockScreenView: View {
  let context: ActivityViewContext<RestTimerAttributes>

  private var timerRange: ClosedRange<Date> {
    let start = Date()
    let end = max(context.state.endDate, start.addingTimeInterval(1))
    return start...end
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(context.attributes.exerciseName, systemImage: "dumbbell.fill")
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Spacer()
        Text("第\(context.state.setNumber)/\(context.state.totalSets)组")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .lastTextBaseline) {
        Text("间歇倒计时")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text(timerInterval: timerRange, countsDown: true, showsHours: false)
          .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
          .multilineTextAlignment(.trailing)
      }
    }
  }
}
