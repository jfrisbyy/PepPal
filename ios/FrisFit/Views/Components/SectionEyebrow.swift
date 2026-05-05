import SwiftUI

/// Small-caps editorial eyebrow used as a section label inside cards
/// and across magazine-style screens. Replaces bold filled-icon
/// section headers with restrained, typography-led labels.
struct SectionEyebrow: View {
    let title: String
    let number: String?
    let accent: Color
    let trailing: AnyView?

    init(_ title: String, number: String? = nil, accent: Color = PepTheme.textSecondary) {
        self.title = title
        self.number = number
        self.accent = accent
        self.trailing = nil
    }

    init<Trailing: View>(_ title: String, number: String? = nil, accent: Color = PepTheme.textSecondary, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.number = number
        self.accent = accent
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let number {
                Text(number)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.9))
                Text("—")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 8)

            if let trailing { trailing }
        }
    }
}

#Preview {
    ZStack {
        PepTheme.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 20) {
            SectionEyebrow("Quick Reference", number: "01", accent: PepTheme.teal)
            SectionEyebrow("Key Facts", number: "02", accent: PepTheme.blue)
            SectionEyebrow("Trending")
        }
        .padding()
    }
}
