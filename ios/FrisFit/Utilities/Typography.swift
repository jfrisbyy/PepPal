import SwiftUI

struct DisplayText: View {
    let text: String
    var color: Color = FrisTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .foregroundStyle(color)
    }
}

struct TitleText: View {
    let text: String
    var color: Color = FrisTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(color)
    }
}

struct HeadlineText: View {
    let text: String
    var color: Color = FrisTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(color)
    }
}

struct SubheadText: View {
    let text: String
    var color: Color = FrisTheme.textSecondary

    var body: some View {
        Text(text)
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(color)
    }
}

struct BodyText: View {
    let text: String
    var color: Color = FrisTheme.textPrimary

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(color)
    }
}

struct CaptionText: View {
    let text: String
    var color: Color = FrisTheme.textSecondary

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }
}
