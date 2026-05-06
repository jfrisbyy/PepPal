import SwiftUI
import HealthKit

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var appeared: Bool = false
    @State private var showProtocolWizard: Bool = false
    @State private var showReconCalculator: Bool = false
    @State private var showQuickActions: Bool = false
    @State private var showNutrition: Bool = false
    @State private var showActivity: Bool = false
    @State private var showDailyTasks: Bool = false
    @State private var showStepDetail: Bool = false
    @State private var bodyGoalViewModel = BodyGoalViewModel()
    @State private var energyBalanceViewModel = EnergyBalanceViewModel()
    @State private var dateSelectorHeight: CGFloat = 0
    @State private var profileNudgeState = ProfileNudgeState()
    @State private var showEditProfileFromNudge: Bool = false
    @State private var showLogActivity: Bool = false
    @State private var showLogMeal: Bool = false
    @State private var logMealTime: MealTime = .lunch
    @State private var trainViewModel = TrainViewModel()
    @State private var showProgramCreation: Bool = false
    @State private var todaysPlanVM = TodaysPlanViewModel.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var nutritionViewModel = NutritionViewModel.shared
    @State private var showGlobalSearch: Bool = false
    @State private var showPepChatFromBrief: Bool = false
    @State private var pepChatContextFromBrief: String? = nil
    @State private var bloodworkEntries: [BloodworkEntry] = []
    @State private var historicalMealsLoaded: Bool = false
    @State private var showOnboardingSuccessCard: Bool = UserDefaults.standard.bool(forKey: OnboardingManager.successCardPendingKey)
    @State private var showStreakInfo: Bool = false
    @State private var showNotificationCenter: Bool = false
    @State private var notifStore = SmartNotificationStore.shared
    @State private var isCalendarRevealExpanded: Bool = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    SkeletonHomeView()
                        .padding(.top, 56)
                        .transition(.opacity)
                } else {
                    EditorialHeader(
                        eyebrow: editorialEyebrow,
                        title: editorialGreeting,
                        isRevealExpanded: $isCalendarRevealExpanded
                    ) {
                        EditorialCalendarReveal(
                            viewModel: viewModel,
                            isExpanded: $isCalendarRevealExpanded
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 56)
                    .padding(.bottom, 6)
                    Group {
                        switch viewModel.selectedTimePeriod {
                        case .daily:
                            dailyContent
                        case .weekly:
                            VStack(spacing: 20) {
                                WeeklySummaryView(summary: viewModel.weeklySummary, bodyGoalViewModel: bodyGoalViewModel, selectedWeekStart: viewModel.selectedWeekStart, weekSchedule: viewModel.weekSchedule(), programName: viewModel.activeProgram?.name)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        case .monthly:
                            VStack(spacing: 20) {
                                MonthlySummaryView(summary: viewModel.monthlySummary, bodyGoalViewModel: bodyGoalViewModel, selectedMonthDate: viewModel.selectedMonthDate, programSummary: viewModel.monthProgramSummary())
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .refreshable {
                await viewModel.refresh()
                await energyBalanceViewModel.refresh()
            }
            .appBackground(accent: PepTheme.teal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
            .overlay(alignment: .topTrailing) {
                floatingActionPill
                    .padding(.top, 6)
                    .padding(.trailing, 14)
            }
            .onAppear { performHomeAppear() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    triggerPlanFetch()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .supabaseDataChanged)) { note in
                let source = (note.userInfo?["source"] as? String) ?? ""
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    await energyBalanceViewModel.refresh()
                    trainViewModel.loadAllData()
                    handleDataChange(source: source)
                    viewModel.refreshAIDeckIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .linkedTaskQuickAction)) { note in
                guard let label = note.userInfo?["action"] as? String else { return }
                switch label {
                case LinkedTaskQuickAction.logMeal.label:
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour < 10 { logMealTime = .breakfast }
                    else if hour < 14 { logMealTime = .lunch }
                    else if hour < 17 { logMealTime = .snacks }
                    else { logMealTime = .dinner }
                    showLogMeal = true
                case LinkedTaskQuickAction.logActivity.label:
                    showLogActivity = true
                case LinkedTaskQuickAction.startWorkout.label:
                    startWorkoutFromHome()
                case LinkedTaskQuickAction.viewSteps.label:
                    showStepDetail = true
                default:
                    break
                }
            }
            .sheet(isPresented: $viewModel.showEditSplit) {
                EditSplitSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showGlobalSearch) {
                GlobalSearchView()
            }
            .sheet(isPresented: $showNotificationCenter) {
                SmartNotificationCenterView()
            }
            .sheet(isPresented: $showEditProfileFromNudge, onDismiss: {
                Task { await profileNudgeState.checkProfile() }
            }) {
                EditProfileView(viewModel: profileNudgeState.profileViewModel)
            }
            .sheet(isPresented: $showProgramCreation) {
                ProgramCreationView(
                    viewModel: trainViewModel,
                    activeProtocol: viewModel.activeProtocol,
                    bodyGoal: bodyGoalViewModel.currentGoal,
                    currentWeight: bodyGoalViewModel.currentWeight > 0 ? bodyGoalViewModel.currentWeight : nil,
                    targetWeight: bodyGoalViewModel.targetWeight > 0 ? bodyGoalViewModel.targetWeight : nil,
                    totalWorkouts: trainViewModel.workoutHistory.count
                )
            }
            .fullScreenCover(isPresented: $trainViewModel.showProgramBuilder) {
                ProgramBuilderView(viewModel: trainViewModel)
            }
            .fullScreenCover(isPresented: $showPepChatFromBrief) {
                PepChatView(planContext: pepChatContextFromBrief)
            }
            .onChange(of: showPepChatFromBrief) { _, isShowing in
                if !isShowing { pepChatContextFromBrief = nil }
            }
            .onDisappear {}
            .onChange(of: showProgramCreation) { _, isShowing in
                if !isShowing {
                    viewModel.reloadActiveProgram()
                }
            }
            .onChange(of: trainViewModel.showProgramBuilder) { _, isShowing in
                if !isShowing {
                    viewModel.reloadActiveProgram()
                }
            }
            .onChange(of: todaysPlanVM.planResponse?.actionItems.count ?? 0) { _, _ in
                viewModel.aiActionItems = todaysPlanVM.planResponse?.actionItems ?? []
            }
            .onChange(of: viewModel.selectedDate) { _, newValue in
                todaysPlanVM.loadHistoricalBriefing(for: newValue)
            }
            .onAppear {
                todaysPlanVM.loadHistoricalBriefing(for: viewModel.selectedDate)
            }
        }
    }

    // MARK: - Editorial greeting helpers

    private var editorialEyebrow: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: viewModel.selectedDate)
    }

    private var editorialGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        case 17..<22: salutation = "Good evening"
        default: salutation = "Hello"
        }
        let name = viewModel.userFirstName.isEmpty ? "" : ", \(viewModel.userFirstName)"
        return salutation + name
    }

    // MARK: - Daily Content

    private var dailyContent: some View {
        VStack(spacing: 0) {
            // Transient banners (no section header — feel like inline editor's notes)
            VStack(spacing: 16) {
                if !viewModel.isSelectedDateToday {
                    selectedDateBanner
                }
                if showOnboardingSuccessCard {
                    HomeOnboardingSuccessCard(onDismiss: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            showOnboardingSuccessCard = false
                        }
                    })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if !profileNudgeState.isComplete && !profileNudgeState.isDismissed {
                    profileCompletionNudge
                }
                if viewModel.streakManager.streakState == .paused {
                    streakPausedBanner
                } else if viewModel.streakManager.freezeRecentlyUsed {
                    streakFreezeUsedBanner
                }
            }
            .padding(.bottom, hasTransientBanners ? 24 : 0)

            // 01 — Today
            CollapsibleEditorialSection(eyebrow: "01 \u{2014} Today", storageKey: "today") {
                VStack(spacing: 16) {
                    TodaysPlanCardView(
                        viewModel: viewModel,
                        todaysPlanVM: todaysPlanVM,
                        showProgramCreation: $showProgramCreation,
                        onStartWorkout: { startWorkoutFromHome() },
                        onTriggerPlanFetch: { forceRefresh in triggerPlanFetch(forceRefresh: forceRefresh) },
                        onChatAboutThis: { context in
                            pepChatContextFromBrief = context
                            showPepChatFromBrief = true
                        }
                    )
                    ProtocolSectionView(
                        viewModel: viewModel,
                        todaysPlanVM: todaysPlanVM,
                        showProtocolWizard: $showProtocolWizard
                    )
                }
            }
            .padding(.bottom, 40)

            // 02 — Composition
            CollapsibleEditorialSection(eyebrow: "02 \u{2014} Composition", storageKey: "composition") {
                VStack(spacing: 16) {
                    BodyGoalSectionView(viewModel: bodyGoalViewModel)
                }
            }
            .padding(.bottom, 40)

            // 03 — Energy & Movement
            CollapsibleEditorialSection(eyebrow: "03 \u{2014} Activity", storageKey: "activity") {
                VStack(spacing: 16) {
                    DailyActivityCard(viewModel: energyBalanceViewModel, onLogActivity: {
                        showLogActivity = true
                    }, onTapActivity: {
                        showActivity = true
                    })
                    HomeTrainingCard(
                        viewModel: viewModel,
                        trainViewModel: trainViewModel,
                        showProgramCreation: $showProgramCreation,
                        onStartWorkout: { startWorkoutFromHome() }
                    )
                    HomeSleepCard(healthKit: viewModel.healthKit)
                    DailyNutritionCard(viewModel: energyBalanceViewModel, onLogMeal: {
                        let hour = Calendar.current.component(.hour, from: Date())
                        if hour < 10 { logMealTime = .breakfast }
                        else if hour < 14 { logMealTime = .lunch }
                        else if hour < 17 { logMealTime = .snacks }
                        else { logMealTime = .dinner }
                        showLogMeal = true
                    }, onTapNutrition: {
                        showNutrition = true
                    })
                    HomeWaterCard()
                }
            }
            .padding(.bottom, 40)
            .navigationDestination(isPresented: $showNutrition) {
                NutritionView()
            }
            .navigationDestination(isPresented: $showActivity) {
                ActivityView(viewModel: energyBalanceViewModel)
            }
            .onChange(of: showNutrition) { _, isShowing in
                if !isShowing {
                    Task { await energyBalanceViewModel.refresh() }
                }
            }
            .onChange(of: showActivity) { _, isShowing in
                if !isShowing {
                    Task { await energyBalanceViewModel.refresh() }
                }
            }

            // 04 — Apple Health
            if viewModel.healthKit.isAuthorized {
                CollapsibleEditorialSection(eyebrow: "04 \u{2014} Apple Health", storageKey: "appleHealth") {
                    VStack(spacing: 14) {
                        StepsModuleCardView(healthKit: viewModel.healthKit, stepsCalories: energyBalanceViewModel.stepsCalories, showStepDetail: $showStepDetail)
                        HomeAppleHealthSection(healthKit: viewModel.healthKit)
                    }
                }
                .padding(.bottom, 40)
            }

        }
        .monospacedDigit()
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 80)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .sheet(isPresented: $showProtocolWizard) {
            AddVialFlowView { proto in
                viewModel.saveProtocolToSupabase(proto)
            }
        }
        .sheet(isPresented: $showReconCalculator) {
            ReconstitutionCalculatorView()
        }
        .sheet(isPresented: $showLogActivity) {
            LogActivitySheet()
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showLogMeal) {
            CameraMealLogView(mealTime: logMealTime, viewModel: nutritionViewModel)
                .onDisappear {
                    Task { await energyBalanceViewModel.refresh() }
                }
        }
        .sheet(isPresented: $showStreakInfo) {
            StreakInfoSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var streakSectionEyebrow: String {
        viewModel.healthKit.isAuthorized ? "05 \u{2014} Streak" : "04 \u{2014} Streak"
    }

    private var hasTransientBanners: Bool {
        !viewModel.isSelectedDateToday
            || showOnboardingSuccessCard
            || (!profileNudgeState.isComplete && !profileNudgeState.isDismissed)
            || viewModel.streakManager.streakState == .paused
            || viewModel.streakManager.freezeRecentlyUsed
    }

    private var profileCompletionNudge: some View {
        Button {
            showEditProfileFromNudge = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PepTheme.amber.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Complete Your Profile")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Add DOB, sex & height for accurate calorie tracking")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 1)
            )
        }
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    profileNudgeState.isDismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(PepTheme.elevated)
                    .clipShape(Circle())
            }
            .offset(x: 6, y: -6)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }


    // MARK: - Date Header Button

    private var dateHeaderButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                viewModel.isDateSelectorExpanded.toggle()
                if !viewModel.isDateSelectorExpanded {
                    viewModel.isFullCalendarExpanded = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(viewModel.toolbarDateString)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                    .rotationEffect(.degrees(viewModel.isDateSelectorExpanded ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PepTheme.elevated)
            .clipShape(.capsule)
        }
        .sensoryFeedback(.selection, trigger: viewModel.isDateSelectorExpanded)
    }



    // MARK: - Floating Action Pill

    /// Unified floating pill in the top-right corner: search · bell · streak.
    /// Fades and shrinks slightly while the user scrolls so it never blocks text.
    private var floatingActionPill: some View {
        HStack(spacing: 0) {
            Button {
                showGlobalSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showGlobalSearch)

            pillDivider

            Button {
                showNotificationCenter = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: notifStore.unreadCount > 0 ? "bell.badge.fill" : "bell")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(notifStore.unreadCount > 0 ? PepTheme.teal : PepTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .symbolEffect(.bounce, value: notifStore.unreadCount)
                    if notifStore.unreadCount > 0 {
                        Circle()
                            .fill(PepTheme.coral)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 1))
                            .offset(x: -8, y: 8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showNotificationCenter)

            pillDivider

            Button {
                showStreakInfo = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: streakIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(streakIconStyle)
                        .symbolEffect(.pulse, options: .repeating, isActive: viewModel.streakManager.streakState == .active)
                    Text("\(viewModel.quickStats.streakDays)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(viewModel.streakManager.streakState == .broken ? PepTheme.textSecondary : PepTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showStreakInfo)
        }
        .background(
            Capsule()
                .fill(PepTheme.cardSurface)
                .overlay(
                    Capsule().strokeBorder(
                        viewModel.streakManager.streakState == .paused
                            ? PepTheme.amber.opacity(0.6)
                            : PepTheme.glassBorderTop,
                        lineWidth: 0.6
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        )
        .clipShape(.capsule)
        .scaleEffect(pillScale, anchor: .topTrailing)
        .opacity(pillOpacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pillScale)
        .animation(.easeOut(duration: 0.18), value: pillOpacity)
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.08))
            .frame(width: 0.5, height: 18)
    }

    /// 1.0 at the top, easing down to 0.88 once the page is scrolled.
    private var pillScale: CGFloat {
        let progress = min(max(scrollOffset / 80, 0), 1)
        return 1.0 - 0.12 * progress
    }

    /// 1.0 at the top, easing down to 0.7 once the page is scrolled.
    private var pillOpacity: Double {
        let progress = min(max(Double(scrollOffset) / 80, 0), 1)
        return 1.0 - 0.3 * progress
    }

    // MARK: - Notifications Toolbar Icon (legacy — superseded by floatingActionPill)

    private var notificationsToolbarIcon: some View {
        Button {
            showNotificationCenter = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: notifStore.unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(notifStore.unreadCount > 0 ? PepTheme.teal : PepTheme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(PepTheme.cardSurface)
                    .clipShape(.circle)
                    .overlay(Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5))
                    .symbolEffect(.bounce, value: notifStore.unreadCount)
                if notifStore.unreadCount > 0 {
                    Text(notifStore.unreadCount > 9 ? "9+" : "\(notifStore.unreadCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(PepTheme.coral, in: Capsule())
                        .overlay(Capsule().strokeBorder(PepTheme.background, lineWidth: 1))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showNotificationCenter)
    }

    // MARK: - Streak Toolbar Icon

    private var streakToolbarIcon: some View {
        Button {
            showStreakInfo = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: streakIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(streakIconStyle)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.streakManager.streakState == .active)
                Text("\(viewModel.quickStats.streakDays)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.streakManager.streakState == .broken ? PepTheme.textSecondary : PepTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PepTheme.cardSurface)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .strokeBorder(streakBorderColor, lineWidth: viewModel.streakManager.streakState == .paused ? 1.0 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var streakIconName: String {
        switch viewModel.streakManager.streakState {
        case .active, .grace: return "flame.fill"
        case .paused: return "flame"
        case .broken, .dormant: return "flame"
        }
    }

    private var streakIconStyle: AnyShapeStyle {
        switch viewModel.streakManager.streakState {
        case .active:
            return AnyShapeStyle(LinearGradient(colors: [.orange, PepTheme.amber], startPoint: .top, endPoint: .bottom))
        case .grace:
            return AnyShapeStyle(PepTheme.amber.opacity(0.85))
        case .paused:
            return AnyShapeStyle(PepTheme.amber.opacity(0.5))
        case .broken, .dormant:
            return AnyShapeStyle(PepTheme.textSecondary)
        }
    }

    private var streakBorderColor: Color {
        switch viewModel.streakManager.streakState {
        case .paused: return PepTheme.amber.opacity(0.6)
        default: return PepTheme.glassBorderTop
        }
    }

    private var streakPausedBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(PepTheme.amber.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "pause.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PepTheme.amber)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Your \(viewModel.streakManager.streakData.currentStreak)-day streak is paused")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                if let hours = viewModel.streakManager.pausedHoursRemaining {
                    Text("Log anything in the next \(hours)h to save it")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    Text("Log anything today to save it")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.amber.opacity(0.4), lineWidth: 1)
        )
        .onTapGesture { showLogActivity = true }
    }

    private var streakFreezeUsedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "snowflake")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
            Text("Streak Freeze used — you're covered for yesterday")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PepTheme.teal.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Selected Date Banner

    private var selectedDateBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.teal)
            Text(viewModel.selectedDateLabel)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.selectedDate = Date()
                }
            } label: {
                Text("Back to Today")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.teal.opacity(0.2), lineWidth: 0.5)
        )
    }



    // MARK: - Day Summary (shown for past dates)

    private var daySummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                    SubheadText(text: "Day Summary")
                }

                if viewModel.selectedDateActivities.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.title2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            Text("No activity logged")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 16) {
                        if viewModel.selectedDateWorkoutCount > 0 {
                            daySummaryStat(
                                icon: "figure.strengthtraining.traditional",
                                value: "\(viewModel.selectedDateWorkoutCount)",
                                label: viewModel.selectedDateWorkoutCount == 1 ? "Workout" : "Workouts",
                                color: PepTheme.teal
                            )
                        }
                        if viewModel.selectedDateSportCount > 0 {
                            daySummaryStat(
                                icon: "sportscourt.fill",
                                value: "\(viewModel.selectedDateSportCount)",
                                label: viewModel.selectedDateSportCount == 1 ? "Sport" : "Sports",
                                color: PepTheme.teal
                            )
                        }
                    }
                }

                let dayNutrition = viewModel.selectedDateNutrition
                VStack(spacing: 8) {
                    NutritionProgressBar(
                        label: "Calories",
                        current: dayNutrition.caloriesConsumed,
                        target: dayNutrition.caloriesTarget,
                        color: PepTheme.teal
                    )
                    NutritionProgressBar(
                        label: "Protein",
                        current: dayNutrition.proteinConsumed,
                        target: dayNutrition.proteinTarget,
                        color: PepTheme.amber
                    )
                }
            }
        }
    }

    private func daySummaryStat(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }







    private func performHomeAppear() {
        viewModel.onAppear()
        nutritionViewModel.selectedDate = viewModel.selectedDate
        Task { await nutritionViewModel.loadFromSupabaseAsync(date: viewModel.selectedDate, force: true) }
        Task { await viewModel.loadWeeklyHistory() }
        Task { await viewModel.loadMonthlyHistory() }
        energyBalanceViewModel.loadData()
        todaysPlanVM.loadCachedPlan()
        triggerPlanFetch()
        trainViewModel.loadAllData()
        Task { await profileNudgeState.checkProfile() }
        Task { await loadJourneyContext() }
        Task { await JourneyMapStagingStore.stageIfStale() }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            syncInsightsStore()
            viewModel.refreshAIDeckIfNeeded()
        }
    }

    private func syncInsightsStore() {
        let store = InsightsDataStore.shared
        store.update(
            firstName: viewModel.userFirstName,
            activeProtocols: viewModel.allProtocols,
            workoutHistory: trainViewModel.workoutHistory,
            todayMeals: nutritionViewModel.loggedMeals,
            macroTarget: nutritionViewModel.dailyTarget,
            weightEntries: bodyGoalViewModel.weightEntries,
            bodyMeasurements: bodyGoalViewModel.measurements,
            startingWeight: bodyGoalViewModel.startingWeight,
            targetWeight: bodyGoalViewModel.targetWeight,
            bloodwork: bloodworkEntries,
            muscleRecovery: trainViewModel.muscleRecoveryItems,
            weeklyVolumes: trainViewModel.weeklyMuscleVolumes,
            personalRecords: trainViewModel.personalRecords,
            activeProgram: viewModel.activeProgram
        )
        store.ingestDailyMeals(date: Date(), meals: nutritionViewModel.loggedMeals)

        // Cross-domain snapshots so the AI / morning brief / insights see the full picture.
        let vials = VialInventoryStore.shared.vials
        let lowStock = SupplyForecastService.lowStockForecasts(from: viewModel.allProtocols)
        store.updateInventory(vials: vials, lowStock: lowStock)
        store.updateSleep(SleepRecoveryService.shared.correlation)
        store.updateBloodworkInterpretation(BloodworkInterpretationService.shared.interpretation)
        store.updateGoal(
            goalType: bodyGoalViewModel.currentGoal.rawValue,
            adaptiveReason: nutritionViewModel.adaptiveTargetReason
        )
    }

    private func handleDataChange(source: String) {
        syncInsightsStore()
        todaysPlanVM.handleDataChange(
            source: source,
            firstName: viewModel.userFirstName,
            activeProtocol: viewModel.activeProtocol,
            nutrition: viewModel.nutrition,
            nutritionTarget: nutritionViewModel.dailyTarget,
            loggedMeals: nutritionViewModel.loggedMeals,
            recentDailyMeals: recentDailyMealsLast14Days(),
            bodyGoalVM: bodyGoalViewModel,
            todaysPlan: viewModel.todaysPlan,
            activeProgram: viewModel.activeProgram,
            bloodworkEntries: bloodworkEntries,
            streakDays: viewModel.quickStats.streakDays,
            workoutsThisWeek: viewModel.quickStats.workoutsThisWeek,
            workoutHistory: trainViewModel.workoutHistory,
            muscleRecoveryItems: trainViewModel.muscleRecoveryItems,
            weeklyMuscleVolumes: trainViewModel.weeklyMuscleVolumes,
            personalRecords: trainViewModel.personalRecords
        )
    }

    private func recentDailyMealsLast14Days() -> [[LoggedMeal]] {
        let cal = Calendar.current
        let store = InsightsDataStore.shared
        var days: [[LoggedMeal]] = []
        for offset in (1...14).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = cal.startOfDay(for: day)
            if let meals = store.recentMealsByDay[key], !meals.isEmpty {
                days.append(meals)
            }
        }
        return days
    }

    private func loadJourneyContext() async {
        guard AuthService.shared.authState == .signedIn,
              let userId = try? AuthService.shared.currentUserId() else { return }

        do {
            let supaEntries = try await BloodworkService.shared.fetchEntries(userId: userId)
            var loaded: [BloodworkEntry] = []
            for entry in supaEntries {
                guard let entryId = entry.id else { continue }
                let results = (try? await BloodworkService.shared.fetchBiomarkerResults(entryId: entryId)) ?? []
                loaded.append(BloodworkService.shared.toBloodworkEntry(entry, results: results))
            }
            await MainActor.run { self.bloodworkEntries = loaded }
        } catch {
            print("[HomeView] Bloodwork load failed: \(error)")
        }

        if !historicalMealsLoaded {
            let cal = Calendar.current
            let store = InsightsDataStore.shared
            for offset in 1...14 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
                do {
                    let supaMeals = try await NutritionService.shared.fetchLoggedMeals(userId: userId, date: day)
                    let meals = supaMeals.map { NutritionService.shared.toLoggedMeal($0) }
                    await MainActor.run { store.ingestDailyMeals(date: day, meals: meals) }
                } catch {
                    continue
                }
            }
            await MainActor.run {
                self.historicalMealsLoaded = true
                triggerPlanFetch(forceRefresh: true)
            }
        }
    }

    private func triggerPlanFetch(forceRefresh: Bool = false) {
        syncInsightsStore()
        if forceRefresh {
            todaysPlanVM.forceRefresh(
                firstName: viewModel.userFirstName,
                activeProtocol: viewModel.activeProtocol,
                nutrition: viewModel.nutrition,
                nutritionTarget: nutritionViewModel.dailyTarget,
                loggedMeals: nutritionViewModel.loggedMeals,
                recentDailyMeals: recentDailyMealsLast14Days(),
                bodyGoalVM: bodyGoalViewModel,
                todaysPlan: viewModel.todaysPlan,
                activeProgram: viewModel.activeProgram,
                bloodworkEntries: bloodworkEntries,
                streakDays: viewModel.quickStats.streakDays,
                workoutsThisWeek: viewModel.quickStats.workoutsThisWeek,
                workoutHistory: trainViewModel.workoutHistory,
                muscleRecoveryItems: trainViewModel.muscleRecoveryItems,
                weeklyMuscleVolumes: trainViewModel.weeklyMuscleVolumes,
                personalRecords: trainViewModel.personalRecords
            )
        } else {
            todaysPlanVM.refreshForWindowIfDue(
                firstName: viewModel.userFirstName,
                activeProtocol: viewModel.activeProtocol,
                nutrition: viewModel.nutrition,
                nutritionTarget: nutritionViewModel.dailyTarget,
                loggedMeals: nutritionViewModel.loggedMeals,
                recentDailyMeals: recentDailyMealsLast14Days(),
                bodyGoalVM: bodyGoalViewModel,
                todaysPlan: viewModel.todaysPlan,
                activeProgram: viewModel.activeProgram,
                bloodworkEntries: bloodworkEntries,
                streakDays: viewModel.quickStats.streakDays,
                workoutsThisWeek: viewModel.quickStats.workoutsThisWeek,
                workoutHistory: trainViewModel.workoutHistory,
                muscleRecoveryItems: trainViewModel.muscleRecoveryItems,
                weeklyMuscleVolumes: trainViewModel.weeklyMuscleVolumes,
                personalRecords: trainViewModel.personalRecords
            )
        }
    }

    // MARK: - Activity Feed

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HeadlineText(text: "Activity Feed")
                Spacer()
                Button {
                } label: {
                    Text("See All")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            if viewModel.activityFeed.isEmpty {
                EmptyStateView(
                    icon: "person.2.wave.2",
                    title: "No Activity Yet",
                    message: "Add friends to see their workouts here."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.activityFeed) { activity in
                        ActivityFeedRow(activity: activity) {
                            viewModel.toggleLike(for: activity)
                        }

                        if activity.id != viewModel.activityFeed.last?.id {
                            Divider()
                                .overlay(PepTheme.shimmerHighlight)
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(12)
                .background(PepTheme.cardSurface)
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
            }
        }
    }

    // MARK: - Streak Encouragement

    private func streakEncouragementCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                FinnAvatar(size: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pep says...")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.85))
                        .lineSpacing(3)
                }
            }
        }
        .padding(16)
        .background(
            PepTheme.violet.opacity(0.06)
                .overlay(PepTheme.cardSurface.opacity(0.8))
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.violet.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Quick Stats

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatItem(
                icon: "figure.strengthtraining.traditional",
                value: "\(viewModel.quickStats.workoutsThisWeek)",
                label: "This Week",
                iconColor: PepTheme.teal
            )

            quickStatDivider

            QuickStatItem(
                icon: "flame.fill",
                value: "\(viewModel.quickStats.streakDays)",
                label: "Streak",
                iconColor: PepTheme.amber
            )
        }
        .padding(.vertical, 14)
        .background(PepTheme.cardSurface)
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
    }

    private var quickStatDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 1, height: 36)
    }



    private func startWorkoutFromHome() {
        guard let program = viewModel.activeProgram else { return }
        let startOffset = UserDefaults.standard.integer(forKey: "programStartDayOffset")
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let mondayBased = (dayOfWeek + 5) % 7
        let adjusted = (mondayBased - startOffset + 7) % 7
        let day: ProgramDay
        if adjusted < program.days.count {
            day = program.days[adjusted]
        } else if let first = program.days.first {
            day = first
        } else {
            return
        }
        let exercises = day.exercises.map { pe in
            let exercise = ExerciseLibrary.all.first { $0.id == pe.exerciseId } ?? ExerciseLibrary.all[0]
            return WorkoutExercise(
                exercise: exercise,
                targetSets: pe.targetSets,
                previousWeight: Double.random(in: 95...185),
                previousReps: Int.random(in: 8...12)
            )
        }
        WorkoutSessionManager.shared.startSession(name: day.name, exercises: exercises)
    }
}

struct NutritionProgressBar: View {
    let label: String
    let current: Int
    let target: Int
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(current)g / \(target)g")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PepTheme.elevated)
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

struct ActivityFeedRow: View {
    let activity: FriendActivity
    let onLike: () -> Void

    @State private var likeTap: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.3), PepTheme.violet.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(activity.friendName.prefix(1)))
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.friendName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(activity.workoutName)
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                HStack(spacing: 6) {
                    Text(activity.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                onLike()
                likeTap += 1
            } label: {
                Image(systemName: activity.liked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(activity.liked ? .red : PepTheme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: likeTap)
        }
        .padding(.vertical, 8)
    }

}

struct QuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .kerning(-0.3)
                .foregroundStyle(PepTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
