import SwiftUI

// MARK: - Display serif (premium editorial feel for hero numbers & headlines)

extension Font {
    /// Geometric serif used for big numbers and hero titles.
    /// Uses New York (system serif) at large sizes — feels like Apple Watch / Apple Fitness.
    static func pepDisplay(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Rounded sans used for UI body / labels.
    static func pepUI(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Monospaced figure font for chart axes and dense numerics.
    static func pepMono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Hero display (big stat / hero balance numbers)

struct DisplayText: View {
    let text: String
    var size: CGFloat = 56
    var weight: Font.Weight = .semibold
    var color: Color = PepTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.pepDisplay(size: size, weight: weight))
            .foregroundStyle(color)
            .kerning(-0.5)
    }
}

/// Large screen / section title (uses display serif for editorial feel).
struct TitleText: View {
    let text: String
    var color: Color = PepTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.pepDisplay(size: 30, weight: .semibold))
            .foregroundStyle(color)
            .kerning(-0.3)
    }
}

/// Editorial section eyebrow — small-caps, tracked, no large title.
/// This is the universal section header across the app: replaces the
/// previous rounded-sans headline so every screen inherits the magazine feel.
struct HeadlineText: View {
    let text: String
    var color: Color = PepTheme.textPrimary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .default))
            .tracking(2.0)
            .foregroundStyle(color.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

struct SubheadText: View {
    let text: String
    var color: Color = PepTheme.textSecondary

    var body: some View {
        Text(text)
            .font(.pepUI(size: 14, weight: .medium))
            .foregroundStyle(color)
    }
}

struct BodyText: View {
    let text: String
    var color: Color = PepTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.pepUI(size: 15, weight: .regular))
            .foregroundStyle(color)
            .lineSpacing(2)
    }
}

struct CaptionText: View {
    let text: String
    var color: Color = PepTheme.textSecondary

    var body: some View {
        Text(text)
            .font(.pepUI(size: 12, weight: .medium))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .kerning(0.6)
    }
}

/// Small label without uppercasing (for inline metadata).
struct MetaText: View {
    let text: String
    var color: Color = PepTheme.textTertiary

    var body: some View {
        Text(text)
            .font(.pepUI(size: 12, weight: .medium))
            .foregroundStyle(color)
    }
}
