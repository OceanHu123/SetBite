import SwiftUI

struct BodyMuscleDiagramView: View {
  let highlights: [WorkoutMuscleHighlight]

  private var frontActive: Set<String> {
    Set(highlights.filter { $0.side == .front }.map(\.label))
  }

  private var backActive: Set<String> {
    Set(highlights.filter { $0.side == .back }.map(\.label))
  }

  private var frontPrimary: Set<String> {
    Set(highlights.filter { $0.side == .front && $0.isPrimary }.map(\.label))
  }

  private var backPrimary: Set<String> {
    Set(highlights.filter { $0.side == .back && $0.isPrimary }.map(\.label))
  }

  var body: some View {
    HStack(alignment: .top, spacing: 2) {
      AnatomyFigurePanel(
        side: .front,
        activeLabels: frontActive,
        primaryLabels: frontPrimary
      )
      AnatomyFigurePanel(
        side: .back,
        activeLabels: backActive,
        primaryLabels: backPrimary
      )
    }
    .frame(height: 190)
  }
}

private struct AnatomyFigurePanel: View {
  let side: WorkoutMuscleHighlight.Side
  let activeLabels: Set<String>
  let primaryLabels: Set<String>

  private var muscles: [MuscleAtlasEntry] {
    BodyMuscleAtlas.muscles(for: side)
  }

  private var activeMuscleIDs: Set<String> {
    BodyMuscleAtlas.activeMuscleIDs(labels: activeLabels, side: side)
  }

  var body: some View {
    GeometryReader { geo in
      let figureRect = BodyMuscleAtlas.figureRect(in: geo.size, side: side)

      ZStack {
        Canvas { context, _ in
          for entry in muscles {
            let path = BodyMuscleAtlas.path(for: entry, in: figureRect, side: side)
            let fill = fillColor(for: entry.id)
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(strokeColor(for: entry.id)), lineWidth: 0.4)
          }
        }

        ForEach(BodyMuscleAtlas.callouts(for: side).filter { shouldShowCallout($0) }) { callout in
          let isActive = activeLabels.contains(callout.label)
          let isPrimary = primaryLabels.contains(callout.label)
          muscleCallout(
            callout: callout,
            isActive: isActive,
            isPrimary: isPrimary,
            figure: figureRect,
            panelSize: geo.size
          )
        }
      }
    }
  }

  private func fillColor(for id: String) -> Color {
    if BodyMuscleAtlas.isStructural(id) { return .white }
    if activeMuscleIDs.contains(id) { return AppTheme.muscleActive }
    return AppTheme.muscleInactive
  }

  private func strokeColor(for id: String) -> Color {
    if BodyMuscleAtlas.isStructural(id) { return AppTheme.muscleOutline.opacity(0.35) }
    return Color.white.opacity(activeMuscleIDs.contains(id) ? 0.7 : 0.45)
  }

  private func shouldShowCallout(_ callout: MuscleCalloutSpec) -> Bool {
    if callout.label == "有氧" || callout.label == "全身" {
      return activeLabels.contains(callout.label)
    }
    return true
  }

  private func muscleCallout(
    callout: MuscleCalloutSpec,
    isActive: Bool,
    isPrimary: Bool,
    figure: CGRect,
    panelSize: CGSize
  ) -> some View {
    let anchor = callout.anchor(in: figure)
    let labelPt = callout.labelPoint(in: panelSize)

    return ZStack {
      Path { path in
        path.move(to: labelPt)
        path.addLine(to: anchor)
      }
      .stroke(AppTheme.muscleLine.opacity(isActive ? 0.55 : 0.32), lineWidth: 0.55)

      Text(callout.label)
        .font(.system(size: 8.5, weight: isActive ? (isPrimary ? .bold : .semibold) : .regular))
        .foregroundStyle(isActive ? Color.primary.opacity(0.88) : AppTheme.muscleLabelInactive)
        .position(labelPt)
    }
  }
}

extension AppTheme {
  static let muscleActive = Color(red: 0.29, green: 0.36, blue: 0.47)
  static let muscleInactive = Color(red: 0.91, green: 0.92, blue: 0.94)
  static let muscleOutline = Color(red: 0.72, green: 0.75, blue: 0.78)
  static let muscleLine = Color(red: 0.75, green: 0.78, blue: 0.82)
  static let muscleLabelInactive = Color(red: 0.68, green: 0.71, blue: 0.75)
  static let muscleHighlight = muscleActive
}
