import SwiftUI

struct ProgramCreationView: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showTemplatePicker: Bool = false
    @State private var showAIBuilder: Bool = false
    @State private var selectedAnimation: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    VStack(spacing: 14) {
                        pathCard(
                            index: 0,
                            icon: "square.grid.2x2.fill",
                            title: "Choose a Template",
                            subtitle: "PPL, Upper/Lower, Bro Split, Full Body & more",
                            description: "Pre-built programs with exercises, sets, and reps ready to go. Pick one and start training today.",
                            gradient: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                            badge: "FASTEST"
                        ) {
                            showTemplatePicker = true
                        }

                        pathCard(
                            index: 1,
                            icon: "sparkles",
                            title: "Build with AI",
                            subtitle: "Personalized to your goals & schedule",
                            description: "Answer a few questions and get a custom program built for your body, goals, equipment, and even your peptide protocol.",
                            gradient: [PepTheme.violet, PepTheme.violet.opacity(0.6)],
                            badge: "SMART"
                        ) {
                            showAIBuilder = true
                        }

                        pathCard(
                            index: 2,
                            icon: "doc.badge.plus",
                            title: "Build from Scratch",
                            subtitle: "Full control over every detail",
                            description: "Pick your days, choose exercises from the library, set your own sets and reps. For lifters who know what they want.",
                            gradient: [PepTheme.amber, PepTheme.amber.opacity(0.6)],
                            badge: nil
                        ) {
                            viewModel.resetBuilder()
                            viewModel.showProgramBuilder = true
                            dismiss()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Create Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .fullScreenCover(isPresented: $showTemplatePicker) {
                TemplatePickerView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showAIBuilder) {
                AIBuildProgramView(viewModel: viewModel)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [PepTheme.teal.opacity(0.2), PepTheme.teal.opacity(0.02)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 36))
                    .foregroundStyle(PepTheme.teal)
            }

            Text("Start Your Program")
                .font(.title2.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Choose how you want to build your training program")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 16)
    }

    private func pathCard(
        index: Int,
        icon: String,
        title: String,
        subtitle: String,
        description: String,
        gradient: [Color],
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedAnimation = index
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                action()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(PepTheme.textPrimary)

                            if let badge {
                                Text(badge)
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(gradient[0])
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(gradient[0].opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                selectedAnimation == index ? gradient[0].opacity(0.4) : PepTheme.glassBorderTop,
                                PepTheme.glassBorderBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: selectedAnimation == index ? 1.0 : 0.5
                    )
            )
            .scaleEffect(selectedAnimation == index ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: selectedAnimation)
    }
}
