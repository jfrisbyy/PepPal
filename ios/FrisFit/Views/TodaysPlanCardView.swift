import SwiftUI

struct TodaysPlanCardView: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var todaysPlanVM: TodaysPlanViewModel
    @Binding var showProgramCreation: Bool
    var onStartWorkout: () -> Void
    var onTriggerPlanFetch: (_ forceRefresh: Bool) -> Void
    var onChatAboutThis: (String) -> Void = { _ in }

    @State private var isPlanMinimized: Bool = false
    @State private var isInsightCollapsed: Bool = false
    @State private var isTrainingCollapsed: Bool = false
    @State private var isDailyTasksCollapsed: Bool = true
    @State private var isBriefCollapsed: Bool = false
    @State private var collapsedTaskCategories: Set<String> = []
    @State private var showAddTask: Bool = false
    @State private var showProtocolReason: UUID? = nil
    @State private var showPepChat: Bool = false
    @State private var pepChatPlanContext: String? = nil
    @State private var showEditProgram: Bool = false
    @State private var editProgramTrainVM: TrainViewModel? = nil

    var body: some View {
        VStack(spacing: 0) {
            mainCard
            expandedTrainingContent
        }
        .fullScreenCover(isPresented: $showPepChat) {
            PepChatView(planContext: pepChatPlanContext)
        }
        .onChange(of: showPepChat) { _, isShowing in
            if !isShowing {
                pepChatPlanContext = nil
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddEditTaskView(viewModel: viewModel)
        }
        .sheet(isPresented: $showEditProgram, onDismiss: {
            viewModel.reloadActiveProgram()
            editProgramTrainVM = nil
        }) {
            if let program = viewModel.activeProgram, let trainVM = editProgramTrainVM {
                NavigationStack {
                    ProgramDetailView(program: program, viewModel: trainVM, isActive: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { showEditProgram = false }
                                    .foregroundStyle(PepTheme.teal)
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
        .onPreferenceChange(EditProgramTriggerKey.self) { trigger in
            if trigger {
                let vm = TrainViewModel()
                vm.loadAllData()
                editProgramTrainVM = vm
                showEditProgram = true
            }
        }
    }

    private var mainCard: some View {
        VStack(spacing: 0) {
            if viewModel.isSelectedDateToday {
                PlanBriefHeaderView(
                    todaysPlanVM: todaysPlanVM,
                    isCollapsed: $isBriefCollapsed,
                    onRefresh: { onTriggerPlanFetch(true) },
                    onChatAboutThis: { context in onChatAboutThis(context) }
                )
                Rectangle()
                    .fill(PepTheme.violet.opacity(0.12))
                    .frame(height: 0.6)
            }

            planMainHeader

            if !isPlanMinimized {
                VStack(spacing: 0) {
                    trainingSection
                    planDivider
                    DailyTasksSectionView(
                        viewModel: viewModel,
                        isDailyTasksCollapsed: $isDailyTasksCollapsed,
                        collapsedTaskCategories: $collapsedTaskCategories,
                        showAddTask: $showAddTask,
                        showProtocolReason: $showProtocolReason
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, isPlanMinimized ? 0 : 8)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private var expandedTrainingContent: some View {
        if !isPlanMinimized && viewModel.isPlanExpanded && !viewModel.todaysPlan.isRestDay && viewModel.activeProgram != nil {
            VStack(spacing: 8) {
                if let trainingInsight = todaysPlanVM.moduleContent(for: "training") {
                    AIInsightStrip(
                        content: trainingInsight,
                        color: PepTheme.blue,
                        actionLabel: "Start Workout",
                        actionIcon: "figure.strengthtraining.traditional",
                        onAction: { onStartWorkout() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                expandedPlanContent
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if !isPlanMinimized && viewModel.isPlanExpanded && viewModel.todaysPlan.isRestDay {
            if let trainingInsight = todaysPlanVM.moduleContent(for: "training") {
                AIInsightStrip(content: trainingInsight, color: PepTheme.blue)
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Plan Main Header

    private var planMainHeader: some View {
        PlanMainHeaderView(
            viewModel: viewModel,
            todaysPlanVM: todaysPlanVM,
            isPlanMinimized: $isPlanMinimized,
            showPepChat: $showPepChat,
            onTriggerPlanFetch: onTriggerPlanFetch
        )
    }

    // MARK: - Plan Divider

    private var planDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }

    // MARK: - AI Insight Section

    private var insightSection: some View {
        PlanInsightSectionView(
            todaysPlanVM: todaysPlanVM,
            isInsightCollapsed: $isInsightCollapsed,
            showPepChat: $showPepChat,
            pepChatPlanContext: $pepChatPlanContext
        )
    }

    // MARK: - Training Section

    private var trainingSection: some View {
        PlanTrainingSectionView(
            viewModel: viewModel,
            isTrainingCollapsed: $isTrainingCollapsed,
            showProgramCreation: $showProgramCreation,
            onEditProgram: {
                let vm = TrainViewModel()
                vm.loadAllData()
                editProgramTrainVM = vm
                showEditProgram = true
            }
        )
    }

    // MARK: - Expanded Plan Content

    private var expandedPlanContent: some View {
        ExpandedPlanContentView(
            viewModel: viewModel,
            onStartWorkout: onStartWorkout
        )
    }
}

// MARK: - Plan Main Header

struct PlanMainHeaderView: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var todaysPlanVM: TodaysPlanViewModel
    @Binding var isPlanMinimized: Bool
    @Binding var showPepChat: Bool
    var onTriggerPlanFetch: (_ forceRefresh: Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            PepAvatar(size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.isSelectedDateToday ? "Today's Plan" : "Plan")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    if viewModel.hasProtocolDeck {
                        HStack(spacing: 3) {
                            Image(systemName: "pill.fill")
                                .font(.system(size: 7, weight: .bold))
                            Text("RX")
                                .font(.system(size: 8, weight: .heavy))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.capsule)
                    }
                }

                if isPlanMinimized {
                    minimizedSubtitle
                } else if let date = todaysPlanVM.lastFetchDate {
                    Text(planTimeAgo(from: date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            if todaysPlanVM.isBackgroundRefreshing {
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(PepTheme.violet.opacity(0.6))
            }

            if !isPlanMinimized {
                headerActions
            }

            if isPlanMinimized {
                planTaskProgressRing
            }

            Image(systemName: isPlanMinimized ? "chevron.right" : "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isPlanMinimized.toggle()
                if isPlanMinimized { viewModel.isPlanExpanded = false }
            }
        }
        .sensoryFeedback(.selection, trigger: isPlanMinimized)
    }

    private var minimizedSubtitle: some View {
        HStack(spacing: 4) {
            Text("\(viewModel.completedCount)/\(viewModel.todaysTasks.count) tasks")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            if !viewModel.todaysPlan.isRestDay, viewModel.activeProgram != nil {
                Text("·")
                    .foregroundStyle(PepTheme.textSecondary)
                Text(viewModel.todaysPlan.name)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var headerActions: some View {
        EmptyView()
    }

    private var planTaskProgressRing: some View {
        let total = viewModel.todaysTasks.count
        let completed = viewModel.completedCount
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 3)
                .frame(width: 28, height: 28)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: progress >= 1.0 ? [PepTheme.teal, PepTheme.teal] : [PepTheme.amber, PepTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(-90))
            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                Text("\(completed)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.amber)
                    .contentTransition(.numericText())
            }
        }
    }

    private func planTimeAgo(from date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "Yesterday"
    }
}

// MARK: - Insight Section

struct PlanInsightSectionView: View {
    @Bindable var todaysPlanVM: TodaysPlanViewModel
    @Binding var isInsightCollapsed: Bool
    @Binding var showPepChat: Bool
    @Binding var pepChatPlanContext: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if !isInsightCollapsed {
                expandedInsight
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var sectionHeader: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                isInsightCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text("AI INSIGHT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .tracking(0.5)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    .rotationEffect(.degrees(isInsightCollapsed ? 0 : 90))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var expandedInsight: some View {
        VStack(alignment: .leading, spacing: 10) {
            if todaysPlanVM.isLoading && !todaysPlanVM.hasPlan {
                planSummaryShimmer
                    .padding(.horizontal, 14)
            } else if let hero = InsightsViewModel.shared.hero {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hero.headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(hero.body)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.75))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)

                fullInsightsStrip(evidenceCount: hero.evidence.count)
                    .padding(.horizontal, 14)

                pepChatAboutThisStrip
                    .padding(.horizontal, 14)
            } else if todaysPlanVM.hasPlan && !todaysPlanVM.summary.isEmpty {
                Text(todaysPlanVM.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)

                fullInsightsStrip(evidenceCount: 0)
                    .padding(.horizontal, 14)

                pepChatAboutThisStrip
                    .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 10)
        .onAppear { InsightsViewModel.shared.refreshIfNeeded() }
    }

    private func fullInsightsStrip(evidenceCount: Int) -> some View {
        Button {
            NotificationCenter.default.post(name: .switchToInsightsTab, object: nil)
        } label: {
            HStack(spacing: 8) {
                if evidenceCount > 0 {
                    Text("\(evidenceCount) data point\(evidenceCount == 1 ? "" : "s") checked")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                }
                Text("See full insights")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.teal.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(PepTheme.teal.opacity(0.08))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var planSummaryShimmer: some View {
        VStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 10)
                    .frame(maxWidth: i == 1 ? 180 : .infinity, alignment: .leading)
            }
        }
    }

    private var pepChatAboutThisStrip: some View {
        Button {
            pepChatPlanContext = buildPlanContextString()
            showPepChat = true
        } label: {
            HStack(spacing: 8) {
                PepNavAvatar(size: 22)

                Text("Chat about this")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.violet.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(PepTheme.violet.opacity(0.08))
            .clipShape(.capsule)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showPepChat)
    }

    private func buildPlanContextString() -> String {
        var parts: [String] = []
        parts.append("Summary: \(todaysPlanVM.summary)")
        for module in todaysPlanVM.modules {
            parts.append("[\(module.title)] \(module.content)")
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Training Section

private struct EditProgramTriggerKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct PlanTrainingSectionView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var isTrainingCollapsed: Bool
    @Binding var showProgramCreation: Bool
    var onEditProgram: () -> Void = {}

    var body: some View {
        let hasProgram = viewModel.activeProgram != nil
        let hasRec = viewModel.trainingRecommendation != nil
        let showSection = hasProgram || hasRec

        Group {
            if showSection {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader(hasProgram: hasProgram)

                    if !isTrainingCollapsed {
                        expandedContent(hasProgram: hasProgram)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func sectionHeader(hasProgram: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                isTrainingCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PepTheme.blue)
                Text("TRAINING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .tracking(0.5)

                if isTrainingCollapsed && hasProgram {
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text(viewModel.todaysPlan.isRestDay ? "Rest Day" : viewModel.todaysPlan.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if hasProgram {
                    Button {
                        onEditProgram()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                            .frame(width: 22, height: 22)
                            .background(PepTheme.elevated.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    .rotationEffect(.degrees(isTrainingCollapsed ? 0 : 90))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func expandedContent(hasProgram: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasProgram {
                if viewModel.allActivePrograms.count > 1 {
                    programSwitcherStrip
                        .padding(.horizontal, 14)
                }

                if viewModel.multiActiveEnabled && viewModel.showAllActiveOnToday && viewModel.allActivePrograms.count > 1 {
                    multiProgramSummaries
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            viewModel.isPlanExpanded.toggle()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            if viewModel.todaysPlan.isRestDay {
                                restDayContent
                            } else {
                                workoutPlanSummary
                            }
                        }
                    }
                    .buttonStyle(.scale)
                    .padding(.horizontal, 14)
                }
            } else if let rec = viewModel.trainingRecommendation {
                protocolTrainingSuggestion(rec)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 10)
    }

    private var programSwitcherStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.allActivePrograms) { program in
                            programChip(program)
                        }
                    }
                }
                if viewModel.multiActiveEnabled {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            viewModel.showAllActiveOnToday.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.showAllActiveOnToday ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(viewModel.showAllActiveOnToday ? PepTheme.teal : PepTheme.textSecondary)
                            .frame(width: 28, height: 24)
                            .background((viewModel.showAllActiveOnToday ? PepTheme.teal : PepTheme.textSecondary).opacity(0.12))
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.showAllActiveOnToday ? "Show single program" : "Show all active programs")
                }
            }
        }
    }

    private func programChip(_ program: TrainingProgram) -> some View {
        let isSelected = viewModel.activeProgram?.id == program.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.selectDisplayedProgram(program.id)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: program.type.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(program.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isSelected ? PepTheme.teal : PepTheme.elevated.opacity(0.7))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var multiProgramSummaries: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.todaysPlans, id: \.program.id) { entry in
                multiProgramRow(program: entry.program, plan: entry.plan)
            }
        }
        .padding(.horizontal, 14)
    }

    private func multiProgramRow(program: TrainingProgram, plan: WorkoutPlan) -> some View {
        let isFocused = viewModel.activeProgram?.id == program.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.selectDisplayedProgram(program.id)
                viewModel.isPlanExpanded = isFocused ? !viewModel.isPlanExpanded : true
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: program.type.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                    Text(program.name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
                        .tracking(0.6)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isFocused {
                        Text("FOCUS")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(PepTheme.teal.opacity(0.14))
                            .clipShape(.capsule)
                    }
                }
                if plan.isRestDay {
                    HStack(spacing: 8) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.amber)
                        Text("Rest Day")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(plan.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 10) {
                        statChip(icon: "dumbbell.fill", text: "\(plan.exercises) ex")
                        statChip(icon: "clock.fill", text: "\(plan.estimatedMinutes)m")
                        let totalSets = plan.planExercises.reduce(0) { $0 + $1.sets }
                        if totalSets > 0 {
                            statChip(icon: "square.stack.3d.up.fill", text: "\(totalSets) sets")
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .background(PepTheme.elevated.opacity(isFocused ? 0.7 : 0.4))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isFocused ? PepTheme.teal.opacity(0.35) : PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.scale)
    }

    private var workoutPlanSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            compactHeaderRow
            compactStatsRow
        }
    }

    private var compactHeaderRow: some View {
        HStack(spacing: 6) {
            Text(viewModel.todaysPlan.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let program = viewModel.activeProgram {
                Text("·")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                Text("W\(program.currentWeek) \(dayPositionLabel(program: program))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: viewModel.isPlanExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
        }
    }

    private var compactStatsRow: some View {
        HStack(spacing: 10) {
            statChip(icon: "dumbbell.fill", text: "\(viewModel.todaysPlan.exercises) ex")
            statChip(icon: "clock.fill", text: "\(viewModel.todaysPlan.estimatedMinutes)m")
            if let sets = totalSetsCount() {
                statChip(icon: "square.stack.3d.up.fill", text: "\(sets) sets")
            }
            let muscles = primaryMuscles()
            if let first = muscles.first {
                Text(muscles.count > 1 ? "\(first) +\(muscles.count - 1)" : first)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PepTheme.elevated.opacity(0.7))
                    .clipShape(.capsule)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var programContextLine: some View {
        if let program = viewModel.activeProgram {
            HStack(spacing: 6) {
                Text(program.name.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
                    .tracking(0.6)
                    .lineLimit(1)

                Text("·")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))

                Text("WEEK \(program.currentWeek)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.teal.opacity(0.85))
                    .tracking(0.6)

                Text("·")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))

                Text(dayPositionLabel(program: program))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.75))
                    .tracking(0.6)
            }
        }
    }

    private var dayTitleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(viewModel.todaysPlan.name)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)

            Image(systemName: viewModel.isPlanExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
        }
    }

    @ViewBuilder
    private var muscleFocusStrip: some View {
        let muscles = primaryMuscles()
        if !muscles.isEmpty {
            HStack(spacing: 5) {
                ForEach(muscles, id: \.self) { muscle in
                    Text(muscle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(PepTheme.elevated.opacity(0.7))
                        .clipShape(.capsule)
                }
            }
        }
    }

    private var workoutStatsRow: some View {
        HStack(spacing: 14) {
            statChip(icon: "dumbbell.fill", text: "\(viewModel.todaysPlan.exercises) exercises")
            statChip(icon: "clock.fill", text: "\(viewModel.todaysPlan.estimatedMinutes) min")
            if let sets = totalSetsCount() {
                statChip(icon: "square.stack.3d.up.fill", text: "\(sets) sets")
            }
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
    }

    private func primaryMuscles() -> [String] {
        let names = viewModel.todaysPlan.planExercises.map(\.muscle)
        var seen: Set<String> = []
        var ordered: [String] = []
        for n in names where !n.isEmpty {
            if seen.insert(n).inserted { ordered.append(n) }
        }
        return Array(ordered.prefix(4))
    }

    private func totalSetsCount() -> Int? {
        let sets = viewModel.todaysPlan.planExercises.reduce(0) { $0 + $1.sets }
        return sets > 0 ? sets : nil
    }

    private func dayPositionLabel(program: TrainingProgram) -> String {
        guard let todayIndex = viewModel.todaysPlan.splitDays.firstIndex(where: { $0.isToday }) else {
            return ""
        }
        let trainingDays = program.days.count
        return "DAY \(todayIndex + 1)/\(trainingDays)"
    }

    private var splitDayStrip: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.todaysPlan.splitDays) { day in
                Text(day.name)
                    .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(day.isToday ? PepTheme.invertedText : (day.isRest ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textSecondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        day.isToday ? PepTheme.teal : PepTheme.elevated.opacity(day.isRest ? 0.4 : 1)
                    )
                    .clipShape(.capsule)
            }
        }
        .padding(.top, 2)
    }

    private var restDayContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundStyle(PepTheme.amber)
                Text("Rest Day")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            if let tip = viewModel.todaysPlan.recoveryTip {
                Text(tip)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
    }

    private func protocolTrainingSuggestion(_ rec: (title: String, message: String, icon: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: rec.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.blue)
                    .frame(width: 32, height: 32)
                    .background(PepTheme.blue.opacity(0.12))
                    .clipShape(Circle())
                Text(rec.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            Text(rec.message)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(name: .linkedTaskQuickAction, object: nil, userInfo: ["action": LinkedTaskQuickAction.startWorkout.label])
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Log Workout")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.teal)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)

                Button {
                    showProgramCreation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 11, weight: .bold))
                        Text("Browse Routines")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PepTheme.blue.opacity(0.1))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Expanded Plan Content

struct ExpandedPlanContentView: View {
    @Bindable var viewModel: HomeViewModel
    var onStartWorkout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            splitDayStripExpanded
                .padding(.horizontal, 16)
                .padding(.top, 10)

            VStack(spacing: 8) {
                ForEach(Array(viewModel.todaysPlan.planExercises.enumerated()), id: \.element.id) { index, exercise in
                    planExerciseRow(exercise, index: index + 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            if viewModel.isSelectedDateToday {
                actionButtons
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .padding(.top, -8)
    }

    private var splitDayStripExpanded: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.todaysPlan.splitDays) { day in
                VStack(spacing: 4) {
                    Text("D\(day.dayIndex + 1)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(day.isToday ? PepTheme.teal : PepTheme.textSecondary.opacity(0.5))
                    Text(day.name)
                        .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? PepTheme.invertedText : (day.isRest ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textPrimary.opacity(0.7)))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            day.isToday ? PepTheme.teal : PepTheme.elevated.opacity(day.isRest ? 0.3 : 0.7)
                        )
                        .clipShape(.rect(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func planExerciseRow(_ exercise: PlanExercise, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.teal.opacity(0.6))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: exercise.equipmentIcon)
                            .font(.system(size: 9))
                        Text(exercise.muscle)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(PepTheme.textSecondary)

                    Text("\(exercise.sets) × \(exercise.repsMin)-\(exercise.repsMax)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PepTheme.teal.opacity(0.8))
                }
            }

            Spacer()

            Text("\(exercise.sets)s")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PepTheme.elevated)
                .clipShape(.capsule)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(PepTheme.elevated.opacity(0.4))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onStartWorkout()
            } label: {
                Text("Start Workout")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scalePrimary)

            Button {
                viewModel.showEditSplit = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Edit Split")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.teal.opacity(0.25), lineWidth: 0.5)
                )
            }
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}
