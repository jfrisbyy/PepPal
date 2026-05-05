import SwiftUI

/// Signature button used across the app.
///
/// Three variants: primary (filled accent), secondary (glass), tertiary (text).
/// Every press triggers a light haptic and a subtle scale.
struct PepButton: View {
    enum Variant { case primary, secondary, tertiary }
    enum Size { case small, regular, large }

    let title: String
    var icon: String? = nil
    var variant: Variant = .primary
    var size: Size = .regular
    var accent: Color = PepTheme.teal
    var fullWidth: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    @State private var pressTrigger: Int = 0

    var body: some View {
        Button {
            pressTrigger &+= 1
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foregroundColor)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                }
                Text(title)
                    .font(.pepUI(size: textSize, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: variant == .secondary ? 0.6 : 0)
            )
            .shadow(
                color: variant == .primary ? accent.opacity(0.32) : .clear,
                radius: 12, x: 0, y: 4
            )
        }
        .buttonStyle(ScalePrimaryButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: pressTrigger)
        .disabled(isLoading)
    }

    // MARK: - Variant styling

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [accent, accent.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .secondary:
            ZStack {
                PepTheme.cardSurface
                accent.opacity(0.06)
                LinearGradient(
                    colors: [PepTheme.glassHighlight.opacity(0.5), .clear],
                    startPoint: .top, endPoint: .center
                )
                .blendMode(.plusLighter)
            }
        case .tertiary:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: .white
        case .secondary: PepTheme.textPrimary
        case .tertiary: accent
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: PepTheme.glassBorderTop
        default: .clear
        }
    }

    // MARK: - Size scale

    private var textSize: CGFloat {
        switch size { case .small: 13; case .regular: 15; case .large: 17 }
    }
    private var iconSize: CGFloat {
        switch size { case .small: 12; case .regular: 14; case .large: 16 }
    }
    private var horizontalPadding: CGFloat {
        switch size { case .small: 14; case .regular: 18; case .large: 22 }
    }
    private var verticalPadding: CGFloat {
        switch size { case .small: 8; case .regular: 12; case .large: 15 }
    }
    private var cornerRadius: CGFloat {
        switch size { case .small: 10; case .regular: 14; case .large: 16 }
    }
}

#Preview {
    VStack(spacing: 16) {
        PepButton(title: "Log dose", icon: "plus", action: {})
        PepButton(title: "Restore", variant: .secondary, action: {})
        PepButton(title: "Skip", variant: .tertiary, action: {})
        PepButton(title: "Continue", size: .large, fullWidth: true, action: {})
    }
    .padding()
    .background(PepTheme.background)
}
