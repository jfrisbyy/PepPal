import SwiftUI

/// Magazine-style header used at the top of premium screens.
///
/// - Eyebrow line in tracked, small-caps sans
/// - Large display headline in serif
/// - Hairline rule beneath
/// - Optional tappable eyebrow with chevron + inline reveal slot
///
/// ```swift
/// EditorialHeader(eyebrow: "TUESDAY · MAY 5", title: "Good evening, Alex")
/// ```
struct EditorialHeader<Reveal: View>: View {
    let eyebrow: String
    let title: String
    var trailing: AnyView? = nil
    var eyebrowTappable: Bool = false
    @Binding var isRevealExpanded: Bool
    let reveal: () -> Reveal

    init(eyebrow: String, title: String) where Reveal == EmptyView {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = nil
        self.eyebrowTappable = false
        self._isRevealExpanded = .constant(false)
        self.reveal = { EmptyView() }
    }

    init<Trailing: View>(
        eyebrow: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) where Reveal == EmptyView {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = AnyView(trailing())
        self.eyebrowTappable = false
        self._isRevealExpanded = .constant(false)
        self.reveal = { EmptyView() }
    }

    /// Tappable-eyebrow variant: a chevron is appended after the eyebrow text and
    /// `reveal` is shown beneath the hairline rule when `isRevealExpanded` is true.
    init(
        eyebrow: String,
        title: String,
        isRevealExpanded: Binding<Bool>,
        @ViewBuilder reveal: @escaping () -> Reveal
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = nil
        self.eyebrowTappable = true
        self._isRevealExpanded = isRevealExpanded
        self.reveal = reveal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    eyebrowView

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

            if eyebrowTappable && isRevealExpanded {
                reveal()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
    }

    @ViewBuilder
    private var eyebrowView: some View {
        if eyebrowTappable {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isRevealExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.teal.opacity(0.9))
                        .rotationEffect(.degrees(isRevealExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isRevealExpanded)
        } else {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
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
