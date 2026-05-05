import SwiftUI

/// Magazine-style section header used between major content groupings.
///
/// - Tracked, small-caps eyebrow (number + label)
/// - Serif display title
/// - Optional small-caps meta text on the trailing edge
/// - Hairline rule beneath, fading to clear
///
/// ```swift
/// EditorialSectionHeader(eyebrow: "01 — Today", title: "Plan & Protocol")
/// EditorialSectionHeader(eyebrow: "03", title: "Energy", meta: "Tue · May 5")
/// ```
struct EditorialSectionHeader: View {
    let eyebrow: String
    var title: String? = nil
    var meta: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))

                Spacer(minLength: 8)

                if let meta {
                    Text(meta.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textTertiary)
                }
            }

            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            LinearGradient(
                colors: [
                    PepTheme.textPrimary.opacity(0.16),
                    PepTheme.textPrimary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.top, 2)
        }
    }
}

#Preview {
    ZStack {
        PepTheme.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 40) {
            EditorialSectionHeader(eyebrow: "01 — Today")
            EditorialSectionHeader(eyebrow: "02 — Composition", meta: "Tue · May 5")
            EditorialSectionHeader(eyebrow: "03 — Activity")
        }
        .padding()
    }
}
