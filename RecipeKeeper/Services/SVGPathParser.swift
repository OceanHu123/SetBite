import CoreGraphics
import SwiftUI

enum SVGPathParser {
  static func path(d: String, in rect: CGRect, viewBox: CGRect) -> Path {
    var result = Path()
    let tokens = tokenize(d)
    guard !tokens.isEmpty else { return result }

    var index = 0
    var command: Character = "M"
    var current = CGPoint.zero
    var start = CGPoint.zero

    func map(_ point: CGPoint) -> CGPoint {
      CGPoint(
        x: rect.minX + (point.x - viewBox.minX) / viewBox.width * rect.width,
        y: rect.minY + (point.y - viewBox.minY) / viewBox.height * rect.height
      )
    }

    func readDouble() -> CGFloat? {
      guard index < tokens.count, let value = Double(tokens[index]) else { return nil }
      index += 1
      return CGFloat(value)
    }

    while index < tokens.count {
      let token = tokens[index]
      if token.count == 1, let letter = token.first, letter.isLetter {
        command = letter
        index += 1
        continue
      }

      switch command {
      case "M":
        guard let x = readDouble(), let y = readDouble() else { break }
        current = CGPoint(x: x, y: y)
        start = current
        result.move(to: map(current))
        command = "L"
      case "m":
        guard let x = readDouble(), let y = readDouble() else { break }
        current = CGPoint(x: current.x + x, y: current.y + y)
        start = current
        result.move(to: map(current))
        command = "l"
      case "L":
        while let x = readDouble(), index < tokens.count, let y = readDouble() {
          current = CGPoint(x: x, y: y)
          result.addLine(to: map(current))
        }
      case "l":
        while let x = readDouble(), index < tokens.count, let y = readDouble() {
          current = CGPoint(x: current.x + x, y: current.y + y)
          result.addLine(to: map(current))
        }
      case "H":
        while let x = readDouble() {
          current = CGPoint(x: x, y: current.y)
          result.addLine(to: map(current))
        }
      case "h":
        while let dx = readDouble() {
          current = CGPoint(x: current.x + dx, y: current.y)
          result.addLine(to: map(current))
        }
      case "V":
        while let y = readDouble() {
          current = CGPoint(x: current.x, y: y)
          result.addLine(to: map(current))
        }
      case "v":
        while let dy = readDouble() {
          current = CGPoint(x: current.x, y: current.y + dy)
          result.addLine(to: map(current))
        }
      case "C":
        while index + 5 < tokens.count,
              let x1 = readDouble(), let y1 = readDouble(),
              let x2 = readDouble(), let y2 = readDouble(),
              let x = readDouble(), let y = readDouble() {
          let c1 = CGPoint(x: x1, y: y1)
          let c2 = CGPoint(x: x2, y: y2)
          current = CGPoint(x: x, y: y)
          result.addCurve(to: map(current), control1: map(c1), control2: map(c2))
        }
      case "c":
        while index + 5 < tokens.count,
              let dx1 = readDouble(), let dy1 = readDouble(),
              let dx2 = readDouble(), let dy2 = readDouble(),
              let dx = readDouble(), let dy = readDouble() {
          let c1 = CGPoint(x: current.x + dx1, y: current.y + dy1)
          let c2 = CGPoint(x: current.x + dx2, y: current.y + dy2)
          current = CGPoint(x: current.x + dx, y: current.y + dy)
          result.addCurve(to: map(current), control1: map(c1), control2: map(c2))
        }
      case "Z", "z":
        result.closeSubpath()
        current = start
      default:
        index += 1
      }
    }

    return result
  }

  private static func tokenize(_ d: String) -> [String] {
    var tokens: [String] = []
    var index = d.startIndex

    while index < d.endIndex {
      let character = d[index]
      if character.isLetter {
        tokens.append(String(character))
        index = d.index(after: index)
      } else if character == "," || character.isWhitespace {
        index = d.index(after: index)
      } else {
        var end = index
        while end < d.endIndex {
          let next = d[end]
          if next.isLetter || next == "," || next.isWhitespace { break }
          end = d.index(after: end)
        }
        tokens.append(String(d[index..<end]))
        index = end
      }
    }

    return tokens
  }
}
