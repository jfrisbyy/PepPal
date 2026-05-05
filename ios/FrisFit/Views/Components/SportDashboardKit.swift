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

// MARK: - Editorial Sport Header

/// Editorial hero used at the top of every sport dashboard.
/// Kicker (uppercase tracked sport name) · serif title · subtitle · hairline rule · serif stat columns with hairline dividers.
struct EditorialSportHeader<Trailing: View>: View {
    let kicker: String
    let title: String
    let subtitle: String
    let accent: Color
    let stats: [EditorialStat]
    @ViewBuilder let trailing: () -> Trailing

    init(
        kicker: String,
        title: String,
        subtitle: String,
        accent: Color,
        stats: [EditorialStat],
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.stats = stats
        self.trailing = trailing
    }

    var body: some View {
        PepSportCard(accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(kicker.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.0)
                        .foregroundStyle(accent.opacity(0.9))
                    Spacer()
                    trailing()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .kerning(-0.4)
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                LinearGradient(
                    colors: [PepTheme.textPrimary.opacity(0.16), PepTheme.textPrimary.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 0.5)

                if !stats.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { idx, stat in
                            VStack(spacing: 4) {
                                Text(stat.value)
                                    .font(.system(.title3, design: .serif, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(stat.label.uppercased())
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)

                            if idx < stats.count - 1 {
                                Rectangle()
                                    .fill(PepTheme.shimmerHighlight)
                                    .frame(width: 0.5, height: 28)
                            }
                        }
                    }
                }
            }
        }
    }
}

nonisolated struct EditorialStat: Sendable {
    let value: String
    let label: String
    init(_ value: String, _ label: String) {
        self.value = value
        self.label = label
    }
}

// MARK: - Editorial Card Border

struct EditorialCardBorder: ViewModifier {
    let accent: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: accent.map { [$0.opacity(0.16), PepTheme.glassBorderBottom] }
                                ?? [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    func editorialCard(accent: Color? = nil, cornerRadius: CGFloat = 16) -> some View {
        modifier(EditorialCardBorder(accent: accent, cornerRadius: cornerRadius))
    }
}

// MARK: - Editorial Section Heading

/// Refined section heading: small uppercase kicker, serif title, hairline rule.
struct EditorialSectionHeading: View {
    let kicker: String
    let title: String
    let accent: Color
    var trailing: AnyView? = nil

    init(kicker: String, title: String, accent: Color, trailing: AnyView? = nil) {
        self.kicker = kicker
        self.title = title
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(kicker.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(accent.opacity(0.85))
                Spacer(minLength: 8)
                if let trailing { trailing }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .kerning(-0.2)
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            LinearGradient(
                colors: [accent.opacity(0.30), accent.opacity(0.0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)
        }
    }
}

// MARK: - Editorial Primary Button

/// Quiet, confident primary action button matching the editorial aesthetic.
struct EditorialPrimaryButton: View {
    let title: String
    let icon: String?
    let accent: Color
    let action: () -> Void

    init(_ title: String, icon: String? = "play.fill", accent: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .tracking(0.3)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [accent, accent.opacity(0.85)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: accent.opacity(0.30), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.scalePrimary)
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
