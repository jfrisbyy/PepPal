import SwiftUI

/// Shared visual primitives for every sport dashboard so Running, Cycling,
/// Basketball, and Main feel like one family of screens.
enum SportDashboardKit {}

// MARK: - Unified Card Style

struct PepSportCard<Content: View>: View {
    let accent: Color?
    @ViewBuilder let content: () -> Content

    init(accent: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.accent = accent
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: accent.map { [$0.opacity(0.18), PepTheme.glassBorderBottom] }
                                ?? [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - Section Heading

struct SportSectionHeading: View {
    let icon: String
    let title: String
    let accent: Color
    var trailing: AnyView? = nil

    init(icon: String, title: String, accent: Color, trailing: AnyView? = nil) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let trailing {
                    trailing
                }
            }
            LinearGradient(
                colors: [accent.opacity(0.35), accent.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
    }
}

// MARK: - Hero "Start Session" Button

struct SportHeroButton: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [accent, accent.opacity(0.82)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: accent.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.scalePrimary)
        .sensoryFeedback(.impact(weight: .medium), trigger: pressed)
        .simultaneousGesture(TapGesture().onEnded { pressed.toggle() })
    }
}

// MARK: - Recovery Traffic Light

nonisolated enum RecoverySignal: Sendable {
    case green
    case amber
    case red
    case unknown

    var color: Color {
        switch self {
        case .green: .green
        case .amber: .orange
        case .red: .red
        case .unknown: PepTheme.textSecondary
        }
    }

    var icon: String {
        switch self {
        case .green: "checkmark.seal.fill"
        case .amber: "exclamationmark.triangle.fill"
        case .red: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .green: "Recovered"
        case .amber: "Caution"
        case .red: "Rest"
        case .unknown: "Unknown"
        }
    }

    @MainActor
    static func fromHealthKit() -> RecoverySignal {
        let hk = HealthKitService.shared
        guard hk.isAvailable, hk.isAuthorized else { return .unknown }
        if let score = hk.recoveryScore {
            if score >= 70 { return .green }
            if score >= 50 { return .amber }
            return .red
        }
        return .unknown
    }
}
