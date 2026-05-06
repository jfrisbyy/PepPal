import SwiftUI

/// Editorial wordmark for "epti" — lowercase, tightly tracked sans, with a
/// single accent dot in the brand green. Designed to sit quietly in the
/// top-left safe area of the home dashboard.
///
/// ```swift
/// EptiLogoMark()
/// ```
struct EptiLogoMark: View {
    var size: CGFloat = 22
    var color: Color = PepTheme.textPrimary
    var dotColor: Color = Color(red: 0.16, green: 0.82, blue: 0.55)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.28) {
            Text("epti")
                .font(.system(size: size, weight: .bold, design: .default))
                .kerning(-0.6)
                .foregroundStyle(color)

            Circle()
                .fill(dotColor)
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(y: -size * 0.02)
                .shadow(color: dotColor.opacity(0.55), radius: size * 0.18, x: 0, y: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("epti")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 28) {
            EptiLogoMark()
            EptiLogoMark(size: 32, color: .white)
            EptiLogoMark(size: 44, color: .white)
        }
    }
}
