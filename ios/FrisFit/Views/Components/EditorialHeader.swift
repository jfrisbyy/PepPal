import SwiftUI

/// Magazine-style header used at the top of premium screens.
///
/// - Eyebrow line in tracked, small-caps sans
/// - Large display headline in serif
/// - Hairline rule beneath
///
/// ```swift
/// EditorialHeader(eyebrow: "TUESDAY · MAY 5", title: "Good evening, Alex")
/// ```
struct EditorialHeader: View {
    let eyebrow: String
    let title: String
    var trailing: AnyView? = nil

    init(eyebrow: String, title: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = nil
    }

    init<Trailing: View>(eyebrow: String, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.85))

                    Text(title)
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .kerning(-0.6)
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 12)

                if let trailing { trailing }
            }

            // Hairline rule — fades from accent to clear
            LinearGradient(
                colors: [
                    PepTheme.textPrimary.opacity(0.18),
                    PepTheme.textPrimary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        EditorialHeader(eyebrow: "Tuesday · May 5", title: "Good evening, Alex")
            .padding()
    }
}
