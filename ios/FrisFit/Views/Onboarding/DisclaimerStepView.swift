import SwiftUI

struct DisclaimerStepView: View {
    @Bindable var state: OnboardingState
    let onAccept: () -> Void

    @State private var scrolledToBottom: Bool = false

    private let sections: [(title: String, body: String)] = [
        ("A research & personal-tracking tool", "EPTI is a research and personal-tracking tool. Nothing here is medical advice, diagnosis, treatment, or a recommendation to use any compound, supplement, or training program. Always consult a qualified clinician before starting, modifying, or stopping any compound, supplement, or training program."),
        ("Not medical advice", "Content in EPTI — including compound information, protocol templates, AI chat responses, and dose calculators — is for educational and informational purposes only. It is not medical advice, diagnosis, or treatment and is not a substitute for consultation with a licensed healthcare provider."),
        ("You must be 18 or older", "EPTI is intended for adults 18 years of age or older. By continuing, you confirm that you meet this age requirement."),
        ("Research compounds are not FDA-approved", "Many peptides and compounds referenced in this app are not approved by the FDA (or equivalent regulators) for human use. EPTI does not sell, prescribe, or endorse any compound, vendor, or supplier."),
        ("Talk to your provider", "Always consult a qualified healthcare professional before starting, changing, or stopping any compound, protocol, supplement, diet, or exercise program — especially if you have a medical condition, are pregnant or nursing, or are taking other medications."),
        ("You are responsible for your choices", "You are solely responsible for decisions you make based on information in this app. EPTI and its developers disclaim any liability for outcomes resulting from use of the app or the information it contains."),
        ("Emergencies", "If you are experiencing a medical emergency, call your local emergency number or go to the nearest emergency room. Do not rely on this app for urgent medical decisions.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(PepTheme.amber.opacity(0.16))
                        .frame(width: 56, height: 56)
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(PepTheme.amber)
                }
                Text("Before you continue")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("EPTI is a research and personal-tracking tool — not medical advice. Please read carefully and scroll to the bottom to continue.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(section.body)
                                .font(.footnote)
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(PepTheme.cardSurface.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.glassBorderBottom, lineWidth: 0.5)
                        )
                    }

                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            if !scrolledToBottom {
                                scrolledToBottom = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        .id("bottomMarker")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .mask(
                LinearGradient(
                    colors: [.black, .black, .black, .black, .black.opacity(scrolledToBottom ? 1 : 0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(spacing: 8) {
                if !scrolledToBottom {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.semibold))
                        Text("Scroll to the bottom to continue")
                            .font(.caption)
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                    .transition(.opacity)
                }

                Button {
                    let now = Date()
                    state.disclaimerAcceptedAt = now
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAccept()
                } label: {
                    Text("I understand and agree")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(scrolledToBottom ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!scrolledToBottom)
                .animation(.easeInOut(duration: 0.2), value: scrolledToBottom)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}
