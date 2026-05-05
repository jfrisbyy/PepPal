import SwiftUI

struct ProgramCreationView: View {
    @Bindable var viewModel: TrainViewModel
    var activeProtocol: PeptideProtocol? = nil
    var bodyGoal: FitnessGoalType? = nil
    var currentWeight: Double? = nil
    var targetWeight: Double? = nil
    var totalWorkouts: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var showTemplatePicker: Bool = false
    @State private var showAIBuilder: Bool = false
    @State private var showAIBuilderWithSuggestion: SmartProgramSuggestion? = nil
    @State private var selectedAnimation: Int? = nil
    @State private var expandedSuggestionId: UUID? = nil
    @State private var appearAnimated: Bool = false

    private var smartSuggestions: [SmartProgramSuggestion] {
        SmartProgramEngine.generateSuggestions(
            activeProtocol: activeProtocol,
            bodyGoal: bodyGoal,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            workoutsThisWeek: viewModel.workoutsCompletedThisWeek,
            totalWorkouts: totalWorkouts,
            experience: nil
        )
    }

    private var hasUserContext: Bool {
        activeProtocol != nil || bodyGoal != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                        .padding(.horizontal)

                    if !smartSuggestions.isEmpty {
                        forYouSection
                    }

                    buildOptionsSection

                    if hasUserContext {
                        userContextPill
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .appBackground()
            .navigationTitle("")
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
                AIBuildProgramView(
                    viewModel: viewModel,
                    activeProtocol: activeProtocol,
                    bodyGoal: bodyGoal,
                    currentWeight: currentWeight,
                    targetWeight: targetWeight,
                    totalWorkouts: totalWorkouts,
                    preSelectedSuggestion: showAIBuilderWithSuggestion
                )
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    appearAnimated = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text((hasUserContext ? "Personalized" : "New Program").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(hasUserContext ? PepTheme.violet : PepTheme.textSecondary.opacity(0.85))

                if hasUserContext {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.violet.opacity(0.85))
                }

                Spacer(minLength: 8)

                Text("VOL · 01")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textTertiary)
            }

            Text(hasUserContext ? "Crafted for You." : "Build Your Program.")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .kerning(-0.8)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(hasUserContext
                ? "Smart suggestions tuned to your stack, goals, and training history."
                : "Three pathways. One studio. Choose how you want to author your training.")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(2)
                .padding(.top, 2)

            LinearGradient(
                colors: [
                    PepTheme.textPrimary.opacity(0.2),
                    PepTheme.textPrimary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }

    // MARK: - For You Section

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("01 — RECOMMENDED")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.violet.opacity(0.9))
                Text("Tailored to Your Stack")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(smartSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                        suggestionCard(suggestion, index: index)
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 16)
        }
    }

    private func suggestionCard(_ suggestion: SmartProgramSuggestion, index: Int) -> some View {
        let isExpanded = expandedSuggestionId == suggestion.id

        return Button {
            showAIBuilderWithSuggestion = suggestion
            showAIBuilder = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(colors: suggestion.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: suggestion.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)

                        Text(suggestion.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                if let badge = suggestion.badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(suggestion.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(suggestion.badgeColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(suggestion.description)
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("Build This Program")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(suggestion.gradient[0])
                .clipShape(.rect(cornerRadius: 8))
            }
            .padding(14)
            .frame(width: 240, alignment: .leading)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                suggestion.gradient[0].opacity(0.2),
                                PepTheme.glassBorderBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showAIBuilder)
        .onAppear { _ = isExpanded }
        .opacity(appearAnimated ? 1 : 0)
        .offset(y: appearAnimated ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appearAnimated)
    }

    // MARK: - Build Options

    private var buildOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(smartSuggestions.isEmpty ? "01 — PATHWAYS" : "02 — AUTHOR")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                Text(smartSuggestions.isEmpty ? "Choose Your Pathway" : "Or Build Your Own")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .kerning(-0.4)
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                pathCard(
                    index: 0,
                    icon: "square.grid.3x1.below.line.grid.1x2",
                    title: "Design Your Program",
                    subtitle: hasUserContext
                        ? "Personalized from your profile — refine and compose"
                        : "Tailored to your goals, schedule, and equipment",
                    gradient: [PepTheme.violet, PepTheme.violet.opacity(0.6)],
                    badge: hasUserContext ? "PERSONALIZED" : "TAILORED"
                ) {
                    showAIBuilderWithSuggestion = nil
                    showAIBuilder = true
                }

                pathCard(
                    index: 1,
                    icon: "square.grid.2x2.fill",
                    title: "Choose a Template",
                    subtitle: "PPL, Upper/Lower, Bro Split, Full Body & more",
                    gradient: [PepTheme.teal, PepTheme.teal.opacity(0.6)],
                    badge: "FASTEST"
                ) {
                    showTemplatePicker = true
                }

                pathCard(
                    index: 2,
                    icon: "doc.badge.plus",
                    title: "Build from Scratch",
                    subtitle: "Full control over every detail",
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
    }

    // MARK: - User Context Pill

    private var userContextPill: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTEXT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textTertiary)

            HStack(spacing: 12) {
                if let proto = activeProtocol {
                    HStack(spacing: 4) {
                        Image(systemName: "syringe.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(proto.goal.color)
                        Text(proto.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("· \(proto.currentPhase.rawValue)")
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    }
                }

                if let goal = bodyGoal {
                    HStack(spacing: 4) {
                        Image(systemName: goal.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(goal.color)
                        Text(goal.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                if let cw = currentWeight, cw > 0 {
                    Text("\(String(format: "%.0f", cw)) lbs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
    }

    // MARK: - Path Card

    private func pathCard(
        index: Int,
        icon: String,
        title: String,
        subtitle: String,
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
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
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
