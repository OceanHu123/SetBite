import Foundation

enum ExerciseBodyCatalog {
  struct Part: Identifiable, Hashable {
    let id: String
    let name: String
    let subparts: [String]

    var displaySubparts: [String] {
      subparts
    }
  }

  static let otherPartName = "其他"
  static let otherSubpartName = "综合"

  static let parts: [Part] = [
    Part(id: "shoulder", name: "肩", subparts: ["前束", "中束", "后束"]),
    Part(id: "chest", name: "胸", subparts: ["上胸", "中胸", "下胸"]),
    Part(id: "back", name: "背", subparts: ["背宽", "背厚"]),
    Part(id: "leg", name: "腿", subparts: ["股四", "腘绳", "臀"]),
    Part(id: "arm", name: "臂", subparts: ["二头", "三头", "前臂"]),
    Part(id: "core", name: "核心", subparts: ["腹", "腰"]),
    Part(id: "cardio", name: "有氧", subparts: ["稳态", "间歇"]),
    Part(id: "other", name: otherPartName, subparts: [otherSubpartName])
  ]

  static var allPartNames: [String] {
    parts.map(\.name)
  }

  static func part(named name: String) -> Part? {
    parts.first { $0.name == name }
  }

  static func defaultSubpart(for partName: String) -> String {
    part(named: partName)?.subparts.first ?? otherSubpartName
  }

  static func isValid(part: String, subpart: String) -> Bool {
    guard let matched = self.part(named: part) else { return part == otherPartName }
    return matched.subparts.contains(subpart)
  }

  static func normalized(part: String, subpart: String) -> (String, String) {
    if let matched = self.part(named: part), matched.subparts.contains(subpart) {
      return (part, subpart)
    }
    if let matched = self.part(named: part) {
      return (part, matched.subparts.first ?? otherSubpartName)
    }
    return (otherPartName, otherSubpartName)
  }
}
