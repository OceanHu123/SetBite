import SwiftData
import SwiftUI

/// Sheet wrapper with presentation chrome.
struct WaterAddSheet: View {
  var body: some View {
    WaterAddContent()
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
      .presentationCornerRadius(28)
  }
}

struct WaterAddContent: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WaterLog.createdAt, order: .reverse) private var allLogs: [WaterLog]
  var showsDoneButton: Bool = true

  private var todayLogs: [WaterLog] {
    allLogs.filter { Calendar.current.isDateInToday($0.createdAt) }
  }

  private var todayMl: Double {
    todayLogs.reduce(0) { $0 + $1.amountMl }
  }

  private var targetMl: Double { AppSettings.dailyWaterTargetMl }

  private var fillProgress: CGFloat {
    guard targetMl > 0 else { return 0 }
    return CGFloat(min(1, todayMl / targetMl))
  }

  var body: some View {
    VStack(spacing: 0) {
      // Title row — sit below sheet drag indicator
      HStack(alignment: .center) {
        Text(L10n.waterTitle)
          .font(AppTheme.bodyFont(size: 17, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer(minLength: 12)

        if showsDoneButton {
          Button(L10n.done) { dismiss() }
            .font(AppTheme.bodyFont(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.accent)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .padding(.bottom, 8)

      VStack(spacing: 4) {
        Text("\(Int(todayMl.rounded())) / \(Int(targetMl.rounded())) ml")
          .font(AppTheme.titleFont(size: 28, weight: .bold))
          .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.72))
          .monospacedDigit()

        Text(L10n.waterGoal)
          .font(AppTheme.bodyFont(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.top, 2)

      RealisticWaterBottleView(progress: fillProgress)
        .frame(width: 150, height: 280)
        .padding(.top, 10)
        .padding(.bottom, 8)

      HStack(spacing: 12) {
        ForEach([100, 250, 500], id: \.self) { amount in
          Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
              addWater(Double(amount))
            }
          } label: {
            Text("+\(amount)")
              .font(AppTheme.bodyFont(size: 15, weight: .bold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .foregroundStyle(.white)
              .background(
                LinearGradient(
                  colors: [
                    Color(red: 0.28, green: 0.62, blue: 0.92),
                    Color(red: 0.18, green: 0.48, blue: 0.82)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                in: Capsule()
              )
              .shadow(color: Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.35), radius: 8, y: 4)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(
      LinearGradient(
        colors: [
          Color(red: 0.93, green: 0.97, blue: 1.0),
          Color(red: 0.98, green: 0.99, blue: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
  }

  private func addWater(_ amount: Double) {
    modelContext.insert(WaterLog(amountMl: amount))
    try? modelContext.save()
  }
}

/// Compact tappable vertical water progress bar beside the calorie ring.
struct WaterVerticalBar: View {
  let todayMl: Int
  let targetMl: Int
  let action: () -> Void

  private var progress: CGFloat {
    guard targetMl > 0 else { return 0 }
    return CGFloat(min(1, Double(todayMl) / Double(targetMl)))
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: "drop.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(red: 0.25, green: 0.58, blue: 0.88))

        GeometryReader { geo in
          let fillHeight = geo.size.height * progress
          ZStack(alignment: .bottom) {
            Capsule()
              .fill(Color(.systemGray5))
            Capsule()
              .fill(
                LinearGradient(
                  colors: [
                    Color(red: 0.35, green: 0.72, blue: 0.98),
                    Color(red: 0.18, green: 0.52, blue: 0.88)
                  ],
                  startPoint: .bottom,
                  endPoint: .top
                )
              )
              .frame(height: max(progress > 0 ? 6 : 0, fillHeight))
              .animation(.easeInOut(duration: 0.35), value: progress)
          }
        }
        .frame(width: 10, height: 120)

        Text("\(todayMl)")
          .font(AppTheme.bodyFont(size: 11, weight: .bold))
          .foregroundStyle(Color(red: 0.2, green: 0.5, blue: 0.75))
          .monospacedDigit()

        Text("ml")
          .font(AppTheme.bodyFont(size: 9, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.waterReminder)
    .accessibilityValue("\(todayMl) / \(targetMl) ml")
  }
}

/// Previous bottle look the user preferred (glass shell + dual wave fill).
struct RealisticWaterBottleView: View {
  let progress: CGFloat
  @State private var wavePhase: CGFloat = 0
  @State private var bubblePhase: CGFloat = 0

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height

      ZStack {
        Ellipse()
          .fill(Color.black.opacity(0.08))
          .frame(width: w * 0.55, height: 12)
          .offset(y: h * 0.46)

        BottleSilhouette()
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.18),
                Color(red: 0.85, green: 0.93, blue: 0.98).opacity(0.35)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay {
            BottleSilhouette()
              .stroke(
                LinearGradient(
                  colors: [
                    Color.white.opacity(0.95),
                    Color(red: 0.55, green: 0.72, blue: 0.88).opacity(0.7),
                    Color.white.opacity(0.5)
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 2.2
              )
          }

        ZStack(alignment: .bottom) {
          WaterWaveLayer(
            progress: progress,
            phase: wavePhase,
            amplitude: 5,
            color: Color(red: 0.25, green: 0.62, blue: 0.95).opacity(0.55)
          )
          WaterWaveLayer(
            progress: progress,
            phase: wavePhase + .pi,
            amplitude: 3.5,
            color: Color(red: 0.35, green: 0.75, blue: 1.0).opacity(0.72)
          )

          if progress > 0.05 {
            BubbleField(phase: bubblePhase, progress: progress)
              .frame(height: max(20, (h - 36) * progress))
          }
        }
        .clipShape(BottleSilhouette())
        .padding(3)

        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(0.75), Color.white.opacity(0)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: w * 0.08, height: h * 0.45)
          .offset(x: -w * 0.22, y: h * 0.02)

        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.45, green: 0.72, blue: 0.95),
                Color(red: 0.28, green: 0.55, blue: 0.85)
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: w * 0.30, height: 16)
          .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .stroke(Color.white.opacity(0.35), lineWidth: 1)
          )
          .offset(y: -h * 0.42)
      }
      .frame(width: w, height: h)
    }
    .onAppear {
      withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
        wavePhase = .pi * 2
      }
      withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
        bubblePhase = 1
      }
    }
  }
}

private struct WaterWaveLayer: View {
  let progress: CGFloat
  let phase: CGFloat
  let amplitude: CGFloat
  let color: Color

  var body: some View {
    GeometryReader { geo in
      let fillHeight = max(0, (geo.size.height - 28) * progress)
      WaveShape(phase: phase, amplitude: amplitude, progress: progress)
        .fill(color)
        .frame(height: geo.size.height)
        .mask(alignment: .bottom) {
          Rectangle()
            .frame(height: fillHeight + amplitude * 2)
        }
    }
  }
}

private struct WaveShape: Shape {
  var phase: CGFloat
  var amplitude: CGFloat
  var progress: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(phase, progress) }
    set {
      phase = newValue.first
      progress = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let midY = rect.height * (1 - progress)

    path.move(to: CGPoint(x: 0, y: rect.height))
    path.addLine(to: CGPoint(x: 0, y: midY))

    let steps = max(Int(rect.width / 4), 20)
    for i in 0...steps {
      let x = rect.width * CGFloat(i) / CGFloat(steps)
      let relative = CGFloat(i) / CGFloat(steps)
      let y = midY + sin(relative * .pi * 2 + phase) * amplitude
      path.addLine(to: CGPoint(x: x, y: y))
    }

    path.addLine(to: CGPoint(x: rect.width, y: rect.height))
    path.closeSubpath()
    return path
  }
}

private struct BubbleField: View {
  let phase: CGFloat
  let progress: CGFloat

  var body: some View {
    GeometryReader { geo in
      let bubbles: [(CGFloat, CGFloat, CGFloat)] = [
        (0.25, 0.2, 4),
        (0.55, 0.45, 3),
        (0.72, 0.28, 5),
        (0.38, 0.65, 2.5),
        (0.62, 0.78, 3.5)
      ]
      ZStack {
        ForEach(0..<bubbles.count, id: \.self) { i in
          let b = bubbles[i]
          let drift = (phase + CGFloat(i) * 0.17).truncatingRemainder(dividingBy: 1)
          Circle()
            .stroke(Color.white.opacity(0.55), lineWidth: 1)
            .background(Circle().fill(Color.white.opacity(0.18)))
            .frame(width: b.2, height: b.2)
            .position(
              x: geo.size.width * b.0,
              y: geo.size.height * (1 - ((b.1 + drift * 0.35).truncatingRemainder(dividingBy: 1)))
            )
        }
      }
      .opacity(Double(min(1, progress * 1.4)))
    }
  }
}

private struct BottleSilhouette: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let neckW = rect.width * 0.34
    let corner: CGFloat = min(20, rect.width * 0.18)
    let left = rect.minX + rect.width * 0.12
    let right = rect.maxX - rect.width * 0.12
    let top = rect.minY + rect.height * 0.14
    let bottom = rect.maxY - rect.height * 0.03
    let neckLeft = rect.midX - neckW / 2
    let neckRight = rect.midX + neckW / 2

    path.move(to: CGPoint(x: neckLeft, y: rect.minY + rect.height * 0.02))
    path.addLine(to: CGPoint(x: neckRight, y: rect.minY + rect.height * 0.02))
    path.addLine(to: CGPoint(x: neckRight, y: top))
    path.addLine(to: CGPoint(x: right, y: top + rect.height * 0.06))
    path.addLine(to: CGPoint(x: right, y: bottom - corner))
    path.addQuadCurve(
      to: CGPoint(x: right - corner, y: bottom),
      control: CGPoint(x: right, y: bottom)
    )
    path.addLine(to: CGPoint(x: left + corner, y: bottom))
    path.addQuadCurve(
      to: CGPoint(x: left, y: bottom - corner),
      control: CGPoint(x: left, y: bottom)
    )
    path.addLine(to: CGPoint(x: left, y: top + rect.height * 0.06))
    path.addLine(to: CGPoint(x: neckLeft, y: top))
    path.closeSubpath()
    return path
  }
}

struct WaterIntakeView: View {
  var body: some View {
    WaterAddContent(showsDoneButton: false)
  }
}
