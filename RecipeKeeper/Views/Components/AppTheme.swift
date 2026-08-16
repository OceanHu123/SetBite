import SwiftUI
import UIKit

enum AppTheme {
  static let accent = Color(red: 0.95, green: 0.40, blue: 0.26)
  static let accentSoft = Color(red: 1.0, green: 0.93, blue: 0.88)
  static let pageBackground = Color(red: 0.99, green: 0.95, blue: 0.92)
  static let cardBackground = Color.white
  static let secondaryCardFill = Color(red: 1.0, green: 0.92, blue: 0.88)
  static let waterCardFill = Color(red: 0.88, green: 0.95, blue: 0.94)
  static let waterFill = Color(red: 0.32, green: 0.70, blue: 0.92).opacity(0.88)

  static let cardRadius: CGFloat = 24
  static let chipRadius: CGFloat = 22
  static let cardShadow = Color.black.opacity(0.10)
  static let cardShadowRadius: CGFloat = 16
  static let cardShadowY: CGFloat = 6
  static let cardBorder = Color.clear
  static let cardBorderWidth: CGFloat = 0

  static let pageGradient = LinearGradient(
    colors: [
      Color(red: 1.0, green: 0.94, blue: 0.90),
      Color(red: 0.99, green: 0.96, blue: 0.93),
      Color(red: 0.97, green: 0.93, blue: 0.90)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let heroGradient = LinearGradient(
    colors: [
      Color(red: 0.99, green: 0.58, blue: 0.32),
      Color(red: 0.92, green: 0.32, blue: 0.22)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static func titleFont(size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  static func bodyFont(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }
}

extension View {
  func appPageBackground() -> some View {
    background {
      AppTheme.pageGradient
        .ignoresSafeArea()
    }
  }

  func appCardStyle() -> some View {
    modifier(AppCardStyleModifier())
  }

  func dismissKeyboardOnTap() -> some View {
    modifier(DismissKeyboardModifier())
  }

  func keyboardDoneToolbar() -> some View {
    toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button(L10n.done) {
          KeyboardDismiss.dismiss()
        }
      }
    }
  }
}

private struct AppCardStyleModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        AppTheme.cardBackground,
        in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
      )
      .shadow(
        color: AppTheme.cardShadow,
        radius: AppTheme.cardShadowRadius,
        y: AppTheme.cardShadowY
      )
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
  var cornerRadius: CGFloat? = nil

  private var resolvedRadius: CGFloat {
    cornerRadius ?? 18
  }

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
    .clipShape(RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
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
