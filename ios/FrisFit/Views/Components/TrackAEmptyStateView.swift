import SwiftUI

/// Reusable Track A empty-state surface — shown inside peptide-related views
/// when `PeptideAccessManager.shared.shouldShowTrackAEmptyState == true`.
///
/// Surfaces remain visible to all users; Track A users see this educational
/// shell with a single "Activate peptide tracking" CTA that runs
/// `PeptideTrackingActivationFlow`.
struct TrackAEmptyStateView<Body: View>: View {
    let surface: PeptideAnalytics.Surface
    let icon: String
    let title: String
    let blurb: String
    let demo: () -> Body
    let onActivated: (() -> Void)?

    @State private var presentingFlow: Bool = false
    @State private var hasLoggedImpression: Bool = false

    init(
        surface: PeptideAnalytics.Surface,
        icon: String,
        title: String,
        blurb: String,
        onActivated: (() -> Void)? = nil,
        @ViewBuilder demo: @escaping () -> Body = { EmptyView() }
    ) {
        self.surface = surface
        self.icon = icon
        self.title = title
        self.blurb = blurb
        self.demo = demo
        self.onActivated = onActivated
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                demoBlock
                cta
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .appBackground()
        .onAppear {
            guard !hasLoggedImpression else { return }
            hasLoggedImpression = true
            PeptideAnalytics.viewedTrackAEmptyState(surface: surface)
        }
        .sheet(isPresented: $presentingFlow) {
            PeptideTrackingActivationFlow(surface: surface) { _ in
                onActivated?()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(PepTheme.teal)

            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text(blurb)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 18))
    }

    @ViewBuilder
    private var demoBlock: some View {
        let demoView = demo()
        if !(demoView is EmptyView) {
            demoView
        }
    }

    private var cta: some View {
        Button {
            presentingFlow = true
        } label: {
            Text("Activate peptide tracking")
                .font(.system(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: PepTheme.teal.opacity(0.35), radius: 18, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

/// Compact inline variant for embedding in cards / sections (e.g.
/// `ProtocolSectionView` on Home) where the full ScrollView shell is overkill.
struct TrackAEmptyStateCard: View {
    let surface: PeptideAnalytics.Surface
    let title: String
    let blurb: String
    var icon: String = "syringe.fill"
    var onActivated: (() -> Void)? = nil

    @State private var presentingFlow: Bool = false
    @State private var hasLoggedImpression: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PepTheme.teal.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Track A")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(blurb)
                .font(.footnote)
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            Button {
                presentingFlow = true
            } label: {
                Text("Activate peptide tracking")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.teal, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 18))
        .onAppear {
            guard !hasLoggedImpression else { return }
            hasLoggedImpression = true
            PeptideAnalytics.viewedTrackAEmptyState(surface: surface)
        }
        .sheet(isPresented: $presentingFlow) {
            PeptideTrackingActivationFlow(surface: surface) { _ in
                onActivated?()
            }
        }
    }
}
