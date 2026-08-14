import SwiftUI
import UIKit

enum AppTheme {
  static let accent = Color(red: 0.92, green: 0.38, blue: 0.18)
  static let accentSoft = Color(red: 1.0, green: 0.94, blue: 0.9)
  static let pageBackground = Color(red: 0.99, green: 0.97, blue: 0.94)
  static let cardBackground = Color.white
  static let heroGradient = LinearGradient(
    colors: [
      Color(red: 0.98, green: 0.55, blue: 0.22),
      Color(red: 0.86, green: 0.28, blue: 0.18)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

extension View {
  func appPageBackground() -> some View {
    background(AppTheme.pageBackground.ignoresSafeArea())
  }

  func dismissKeyboardOnTap() -> some View {
    modifier(DismissKeyboardModifier())
  }

  func keyboardDoneToolbar() -> some View {
    toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("完成") {
          KeyboardDismiss.dismiss()
        }
      }
    }
  }
}

enum KeyboardDismiss {
  static func dismiss() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil
    )
  }
}

private struct DismissKeyboardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .scrollDismissesKeyboard(.interactively)
      .simultaneousGesture(
        TapGesture().onEnded {
          KeyboardDismiss.dismiss()
        }
      )
  }
}

struct RecipeCoverImage: View {
  let data: Data?
  var height: CGFloat = 200
  var cornerRadius: CGFloat = 16

  var body: some View {
    Group {
      if let data, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          AppTheme.heroGradient
          Image(systemName: "fork.knife")
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }
}

struct ToastBanner: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.subheadline.weight(.medium))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.black.opacity(0.82), in: Capsule())
      .shadow(radius: 8, y: 4)
  }
}
