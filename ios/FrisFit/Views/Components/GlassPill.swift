import SwiftUI

/// A floating, frosted-glass segmented control. iOS 26 uses real
/// `glassEffect`; older systems fall back to `.ultraThinMaterial` with
/// a hairline highlight so nothing looks broken.
///
/// ```swift
/// GlassPill(selection: $filter, options: Filter.allCases) { Text($0.label) }
/// ```
struct GlassPill<T: Hashable, Label: View>: View {
    @Binding var selection: T
    let options: [T]
    @ViewBuilder let label: (T) -> Label

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    if selection != option {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selection = option
                        }
                    }
                } label: {
                    label(option)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? PepTheme.textPrimary : PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(PepTheme.cardSurface)
                                    .overlay(
                                        Capsule().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
        )
        .modifier(GlassPillEffect())
    }
}

private struct GlassPillEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(in: .capsule)
        } else {
            content
        }
    }
}
