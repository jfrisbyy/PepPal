import SwiftUI

struct PregnancyGateStepView: View {
    @Bindable var state: OnboardingState
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(PepTheme.amber.opacity(0.16))
                            .frame(width: 56, height: 56)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(PepTheme.amber)
                    }
                    Text("One more thing")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Are you currently pregnant or nursing?")
                        .font(.headline)
                        .foregroundStyle(PepTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("We ask so we can keep compound-tracking surfaces locked while you're pregnant or nursing — for everyone's safety. You can flip this in Settings any time.")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    answerCard(value: false, title: "No", subtitle: "I'm not currently pregnant or nursing.", icon: "checkmark.circle.fill")
                    answerCard(value: true, title: "Yes", subtitle: "Keep compound surfaces locked for now.", icon: "lock.fill")
                }

                Spacer(minLength: 8)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(state.isPregnantOrNursing != nil ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(state.isPregnantOrNursing == nil)
                .animation(.easeInOut(duration: 0.2), value: state.isPregnantOrNursing)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func answerCard(value: Bool, title: String, subtitle: String, icon: String) -> some View {
        let isSelected = state.isPregnantOrNursing == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                state.isPregnantOrNursing = value
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? PepTheme.teal.opacity(0.18) : PepTheme.elevated.opacity(0.6))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? PepTheme.teal : PepTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface.opacity(isSelected ? 0.95 : 0.65))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? PepTheme.teal.opacity(0.6) : PepTheme.glassBorderBottom,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
