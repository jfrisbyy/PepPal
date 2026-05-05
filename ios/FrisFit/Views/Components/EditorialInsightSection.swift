import SwiftUI

/// Premium editorial-style insight panel surfaced on category full pages
/// (Nutrition, Activity, Body). Renders the AI-generated category narrative
/// from `TodaysPlanViewModel` with a serif headline, tracked eyebrow,
/// accent rule, and a "last updated" timestamp. Shows a subtle shimmer
/// while a refresh is in flight.
struct EditorialInsightSection: View {
    let eyebrow: String
    let title: String
    let content: String?
    let accent: Color
    var isRefreshing: Bool = false
    var lastUpdated: Date?

    @State private var shimmerPhase: CGFloat = -0.6

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.55), accent.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.75)

            bodyContent

            footer
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .background(
            ZStack {
                PepTheme.cardSurface
                LinearGradient(
                    colors: [accent.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.22), accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(accent)
                .frame(width: 2, height: 36)
                .padding(.top, 18)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(eyebrow)
                        .font(.system(.caption2, weight: .heavy))
                        .tracking(3.2)
                        .foregroundStyle(accent)
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(width: 18, height: 1)
                }
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRefreshing)
            }
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let text = content, !text.isEmpty {
            Text(text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(PepTheme.textPrimary.opacity(0.88))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isRefreshing ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.4), value: isRefreshing)
        } else if isRefreshing {
            shimmerLines
        } else {
            Text("Log a meal, workout, or weigh-in and your read will land here.")
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
        }
    }

    private var shimmerLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([0.92, 0.78, 0.55], id: \.self) { width in
                shimmerBar(widthFraction: width)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.6
            }
        }
    }

    private func shimmerBar(widthFraction: CGFloat) -> some View {
        GeometryReader { geo in
            let w = geo.size.width * widthFraction
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.10))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.0),
                                accent.opacity(0.35),
                                accent.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: w * 0.45)
                    .offset(x: w * shimmerPhase)
                    .clipShape(Capsule())
            }
            .frame(width: w, height: 10)
        }
        .frame(height: 10)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "clock")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .symbolEffect(.rotate, options: .repeating, isActive: isRefreshing)
            Text(footerText)
                .font(.system(.caption2, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
            Spacer()
        }
    }

    private var footerText: String {
        if isRefreshing { return "Refreshing your read…" }
        guard let last = lastUpdated else { return "Awaiting first read" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: last, relativeTo: Date()))"
    }
}
