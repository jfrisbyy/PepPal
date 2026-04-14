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
                VStack(spacing: 20) {
                    headerSection

                    if !smartSuggestions.isEmpty {
                        forYouSection
                    }

                    buildOptionsSection

                    if hasUserContext {
                        userContextPill
                    }
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
        VStack(spacing: 6) {
            if hasUserContext {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.violet)
                    Text("Personalized for you")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PepTheme.violet.opacity(0.1))
                .clipShape(Capsule())
            }

            Text(hasUserContext ? "Your Program" : "Start Your Program")
                .font(.title2.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text(hasUserContext
                ? "Smart suggestions based on your stack, goals & training history"
                : "Choose how you want to build your training program")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 16)
    }

    // MARK: - For You Section

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                Text("Recommended for You")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .textCase(.uppercase)
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                if isExpanded {
                    expandedSuggestionId = nil
                } else {
                    expandedSuggestionId = suggestion.id
                }
            }
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

                if isExpanded {
                    Text(suggestion.description)
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    Button {
                        showAIBuilderWithSuggestion = suggestion
                        showAIBuilder = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("Build This Program")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(suggestion.gradient[0])
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(14)
            .frame(width: isExpanded ? 280 : 220, alignment: .leading)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isExpanded ? suggestion.gradient[0].opacity(0.3) : PepTheme.glassBorderTop,
                                PepTheme.glassBorderBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isExpanded ? 1 : 0.5
                    )
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: expandedSuggestionId)
        .opacity(appearAnimated ? 1 : 0)
        .offset(y: appearAnimated ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appearAnimated)
    }

    // MARK: - Build Options

    private var buildOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !smartSuggestions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Or Build Your Own")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .textCase(.uppercase)
                }
                .padding(.horizontal)
            }

            VStack(spacing: 12) {
                pathCard(
                    index: 0,
                    icon: "sparkles",
                    title: "Build with AI",
                    subtitle: hasUserContext
                        ? "Pre-loaded with your data — just customize"
                        : "Personalized to your goals & schedule",
                    gradient: [PepTheme.violet, PepTheme.violet.opacity(0.6)],
                    badge: hasUserContext ? "AUTO-FILLED" : "SMART"
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
        VStack(spacing: 6) {
            Rectangle()
                .fill(PepTheme.glassBorderTop)
                .frame(height: 0.5)
                .padding(.horizontal)

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
            .padding(.vertical, 8)
            .background(PepTheme.elevated)
            .clipShape(Capsule())
        }
        .padding(.top, 4)
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
