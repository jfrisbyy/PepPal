import SwiftUI

struct PersonaForkStepView: View {
    @Bindable var state: OnboardingState
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How will you use EPTI?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("This shapes the rest of your setup. You can change it any time in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(PersonaTrack.allCases, id: \.self) { track in
                        personaCard(for: track)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onContinue()
            } label: {
                Text("Continue")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(state.personaTrack != nil ? PepTheme.teal : PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(state.personaTrack == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.2), value: state.personaTrack)
        }
    }

    private func personaCard(for track: PersonaTrack) -> some View {
        let isSelected = state.personaTrack == track
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                state.personaTrack = track
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? PepTheme.teal.opacity(0.18) : PepTheme.elevated.opacity(0.6))
                        .frame(width: 52, height: 52)
                    Image(systemName: track.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(track.subtitle)
                        .font(.footnote)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(16)
            .background(PepTheme.cardSurface.opacity(isSelected ? 0.95 : 0.65))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? PepTheme.teal.opacity(0.6) : PepTheme.glassBorderBottom,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(color: isSelected ? PepTheme.teal.opacity(0.18) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
