import CoreGraphics
import SwiftUI

// Muscle path data adapted from vulovix/body-muscles (Apache-2.0).
// https://github.com/vulovix/body-muscles

struct MuscleAtlasEntry: Codable, Identifiable {
  let id: String
  let name: String
  let path: String
}

struct MuscleCalloutSpec: Identifiable {
  let id: String
  let label: String
  let anchorX: CGFloat
  let anchorY: CGFloat
  let labelX: CGFloat
  let labelY: CGFloat
  let muscleIDs: [String]

  init(
    label: String,
    anchorX: CGFloat,
    anchorY: CGFloat,
    labelX: CGFloat,
    labelY: CGFloat,
    muscleIDs: [String]
  ) {
    self.id = label
    self.label = label
    self.anchorX = anchorX
    self.anchorY = anchorY
    self.labelX = labelX
    self.labelY = labelY
    self.muscleIDs = muscleIDs
  }

  func anchor(in figure: CGRect) -> CGPoint {
    CGPoint(x: figure.minX + anchorX * figure.width, y: figure.minY + anchorY * figure.height)
  }

  func labelPoint(in panel: CGSize) -> CGPoint {
    CGPoint(x: labelX * panel.width, y: labelY * panel.height)
  }
}

enum BodyMuscleAtlas {
  private static let frontDisplayViewBox = CGRect(x: 0, y: 2, width: 35, height: 84)
  private static let backDisplayViewBox = CGRect(x: 37, y: 2, width: 35, height: 84)
  private static let verticalSquash: CGFloat = 0.90

  static let frontMuscles: [MuscleAtlasEntry] = load("MuscleAtlasFront")
  static let backMuscles: [MuscleAtlasEntry] = load("MuscleAtlasBack")

  static let frontCallouts: [MuscleCalloutSpec] = [
    .init(label: "上胸", anchorX: 0.50, anchorY: 0.22, labelX: 0.50, labelY: 0.05,
          muscleIDs: ["chest-upper-left", "chest-upper-right"]),
    .init(label: "中下胸", anchorX: 0.50, anchorY: 0.30, labelX: 0.93, labelY: 0.27,
          muscleIDs: ["chest-lower-left", "chest-lower-right"]),
    .init(label: "前束", anchorX: 0.28, anchorY: 0.22, labelX: 0.05, labelY: 0.17,
          muscleIDs: ["shoulder-front-left", "shoulder-front-right"]),
    .init(label: "中束", anchorX: 0.72, anchorY: 0.22, labelX: 0.95, labelY: 0.17,
          muscleIDs: ["shoulder-side-left", "shoulder-side-right"]),
    .init(label: "二头", anchorX: 0.20, anchorY: 0.34, labelX: 0.04, labelY: 0.35,
          muscleIDs: ["biceps-left", "biceps-right"]),
    .init(label: "小臂", anchorX: 0.15, anchorY: 0.47, labelX: 0.04, labelY: 0.47,
          muscleIDs: ["forearm-left", "forearm-right"]),
    .init(label: "腹部", anchorX: 0.50, anchorY: 0.40, labelX: 0.50, labelY: 0.55,
          muscleIDs: [
            "abs-upper-left", "abs-upper-right", "abs-lower-left", "abs-lower-right",
            "serratus-anterior-left", "serratus-anterior-right", "obliques-left", "obliques-right"
          ]),
    .init(label: "股四", anchorX: 0.40, anchorY: 0.62, labelX: 0.05, labelY: 0.64,
          muscleIDs: ["quads-left", "quads-right"]),
    .init(label: "小腿", anchorX: 0.38, anchorY: 0.82, labelX: 0.05, labelY: 0.84,
          muscleIDs: ["tibialis-anterior-left", "tibialis-anterior-right"]),
    .init(label: "有氧", anchorX: 0.50, anchorY: 0.36, labelX: 0.50, labelY: 0.05,
          muscleIDs: cardioFrontIDs),
    .init(label: "全身", anchorX: 0.50, anchorY: 0.36, labelX: 0.50, labelY: 0.05,
          muscleIDs: fullBodyFrontIDs)
  ]

  static let backCallouts: [MuscleCalloutSpec] = [
    .init(label: "斜方", anchorX: 0.50, anchorY: 0.15, labelX: 0.50, labelY: 0.05,
          muscleIDs: [
            "traps-upper-left", "traps-mid-left", "traps-lower-left",
            "traps-upper-right", "traps-mid-right", "traps-lower-right"
          ]),
    .init(label: "后束", anchorX: 0.28, anchorY: 0.22, labelX: 0.05, labelY: 0.17,
          muscleIDs: ["deltoid-rear-left", "deltoid-rear-right"]),
    .init(label: "中束", anchorX: 0.72, anchorY: 0.22, labelX: 0.95, labelY: 0.17, muscleIDs: []),
    .init(label: "背部", anchorX: 0.50, anchorY: 0.30, labelX: 0.94, labelY: 0.30,
          muscleIDs: [
            "lats-upper-left", "lats-mid-left", "lats-lower-left",
            "lats-upper-right", "lats-mid-right", "lats-lower-right"
          ]),
    .init(label: "下背", anchorX: 0.50, anchorY: 0.42, labelX: 0.94, labelY: 0.42,
          muscleIDs: [
            "lower-back-erectors-left", "lower-back-ql-left",
            "lower-back-erectors-right", "lower-back-ql-right", "spine"
          ]),
    .init(label: "三头", anchorX: 0.20, anchorY: 0.34, labelX: 0.04, labelY: 0.35,
          muscleIDs: [
            "triceps-long-left", "triceps-lateral-left",
            "triceps-long-right", "triceps-lateral-right"
          ]),
    .init(label: "臀部", anchorX: 0.50, anchorY: 0.50, labelX: 0.50, labelY: 0.58,
          muscleIDs: [
            "gluteus-medius-left", "gluteus-maximus-left",
            "gluteus-medius-right", "gluteus-maximus-right"
          ]),
    .init(label: "腘绳", anchorX: 0.40, anchorY: 0.64, labelX: 0.05, labelY: 0.66,
          muscleIDs: [
            "hamstrings-medial-left", "hamstrings-lateral-left",
            "hamstrings-medial-right", "hamstrings-lateral-right"
          ]),
    .init(label: "小腿", anchorX: 0.38, anchorY: 0.82, labelX: 0.05, labelY: 0.84,
          muscleIDs: [
            "calves-gastroc-medial-left", "calves-gastroc-lateral-left", "calves-soleus-left",
            "calves-gastroc-medial-right", "calves-gastroc-lateral-right", "calves-soleus-right"
          ])
  ]

  static func muscles(for side: WorkoutMuscleHighlight.Side) -> [MuscleAtlasEntry] {
    side == .front ? frontMuscles : backMuscles
  }

  static func viewBox(for side: WorkoutMuscleHighlight.Side) -> CGRect {
    side == .front ? frontDisplayViewBox : backDisplayViewBox
  }

  static func figureRect(in panelSize: CGSize, side: WorkoutMuscleHighlight.Side) -> CGRect {
    let viewBox = viewBox(for: side)
    let aspect = viewBox.width / viewBox.height

    let maxWidth = panelSize.width * 0.72
    let maxHeight = panelSize.height * 0.90

    var width = maxWidth
    var height = width / aspect
    if height > maxHeight {
      height = maxHeight
      width = height * aspect
    }

    height *= verticalSquash

    return CGRect(
      x: (panelSize.width - width) / 2,
      y: panelSize.height * 0.05,
      width: width,
      height: height
    )
  }

  static func callouts(for side: WorkoutMuscleHighlight.Side) -> [MuscleCalloutSpec] {
    side == .front ? frontCallouts : backCallouts
  }

  static func path(for entry: MuscleAtlasEntry, in rect: CGRect, side: WorkoutMuscleHighlight.Side) -> Path {
    SVGPathParser.path(d: entry.path, in: rect, viewBox: viewBox(for: side))
  }

  static func activeMuscleIDs(labels: Set<String>, side: WorkoutMuscleHighlight.Side) -> Set<String> {
    let specs = callouts(for: side)
    return Set(specs.filter { labels.contains($0.label) }.flatMap(\.muscleIDs))
  }

  static func isStructural(_ id: String) -> Bool {
    if id == "spine" || id == "nape" { return true }
    let markers = ["head", "face", "hand", "foot", "knee", "elbow", "neck"]
    return markers.contains { id.contains($0) }
  }

  private static let cardioFrontIDs = [
    "chest-upper-left", "chest-upper-right", "chest-lower-left", "chest-lower-right",
    "abs-upper-left", "abs-upper-right", "abs-lower-left", "abs-lower-right",
    "quads-left", "quads-right", "shoulder-front-left", "shoulder-front-right"
  ]

  private static let fullBodyFrontIDs: [String] = {
    frontMuscles.map(\.id).filter { !isStructural($0) }
  }()

  private static func load(_ name: String) -> [MuscleAtlasEntry] {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let entries = try? JSONDecoder().decode([MuscleAtlasEntry].self, from: data)
    else { return [] }
    return entries
  }
}
