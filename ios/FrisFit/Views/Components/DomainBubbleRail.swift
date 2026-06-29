import SwiftUI

/// The six top-level domains of the app, replacing the old bottom tab bar.
/// Fixed left-to-right order. Each owns an accent color and SF Symbol.
nonisolated enum AppDomain: Int, CaseIterable, Identifiable {
    case brief, train, fuel, stack, labs, social

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .brief: "Brief"
        case .train: "Train"
        case .fuel: "Fuel"
        case .stack: "Stack"
        case .labs: "Labs"
        case .social: "Social"
        }
    }

    var icon: String {
        switch self {
        case .brief: "sun.max"
        case .train: "figure.run"
        case .fuel: "fork.knife"
        case .stack: "syringe"
        case .labs: "testtube.2"
        case .social: "person.2"
        }
    }

    @MainActor var accent: Color {
        switch self {
        case .brief: PepTheme.teal
        case .train: PepTheme.coral
        case .fuel: PepTheme.amber
        case .stack: PepTheme.tealDeep
        case .labs: PepTheme.blue
        case .social: PepTheme.violet
        }
    }
}

/// Horizontal rail of six domain bubbles that drive the full-screen pager.
/// Active bubble is filled with its accent and glows; the rest are quiet
/// glass circles. Styling pulls from `PepTheme` only.
struct DomainBubbleRail: View {
    @Binding var selection: AppDomain

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppDomain.allCases) { domain in
                bubble(domain)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
    }

    private func bubble(_ domain: AppDomain) -> some View {
        let isActive = selection == domain
        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                selection = domain
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isActive ? domain.accent : PepTheme.cardSurface.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().strokeBorder(
                            isActive ? Color.clear : PepTheme.glassBorderTop.opacity(0.6),
                            lineWidth: 0.5
                        )
                    )
                    .shadow(
                        color: isActive ? domain.accent.opacity(0.35) : .clear,
                        radius: isActive ? 8 : 0,
                        y: isActive ? 2 : 0
                    )
                Image(systemName: domain.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isActive ? PepTheme.invertedText : PepTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(domain.title)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isActive)
    }
}
