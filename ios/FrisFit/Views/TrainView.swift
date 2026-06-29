import SwiftUI

struct TrainView: View {
    @State private var viewModel = TrainViewModel()
    @State private var homeViewModel = HomeViewModel()
    @State private var bodyGoalViewModel = BodyGoalViewModel()
    @State private var runVM = RunningViewModel.shared
    @State private var cyclingVM = CyclingViewModel.shared
    @State private var bbVM = BasketballViewModel.shared
    @State private var swimVM = SwimmingViewModel.shared
    @State private var soccerVM = SoccerViewModel.shared
    @State private var tennisVM = TennisViewModel.shared
    @State private var volleyballVM = VolleyballViewModel.shared
    @State private var pickleVM = PickleballViewModel.shared
    @State private var maVM = MartialArtsViewModel.shared
    @State private var showLibrary: Bool = false
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var showSportSelector: Bool = false
    @State private var showSportLog: Bool = false
    @State private var selectedSport: Sport = .basketball
    @State private var isLoading: Bool = true
    @State private var expandedItemId: UUID? = nil
    @State private var showAnalyticsDetail: Bool = false
    @State private var showProgramCreation: Bool = false
    @State private var showLiveRun: Bool = false
    @State private var showLiveRide: Bool = false
    @State private var showProgressSheet: Bool = false
    @State private var showRoutines: Bool = false
    @State private var showRoutineEditor: Bool = false
    @State private var routineStore = RoutineStore.shared
    @State private var scrollOffset: CGFloat = 0
    @State private var energyBalanceViewModel = EnergyBalanceViewModel()
    @State private var showStepDetail: Bool = false
    @State private var showLogActivity: Bool = false
    @State private var showActivity: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    SkeletonTrainView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        EptiLogoMark(size: 38)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        if viewModel.availableModes.count > 1 {
                            modeTabBar
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                        }

                        if viewModel.currentMode.type == .main {
                            mainContent
                                .transition(.opacity)
                        } else {
                            sportModeContent
                                .padding(.horizontal)
                                .padding(.bottom, 24)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .overlay(alignment: .topTrailing) {
                trainModesPill
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            .appBackground(accent: PepTheme.coral)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.showModeSelectorSheet) {
                TrainModeSelectorSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showLibrary) {
                ExerciseLibraryView()
            }
            .fullScreenCover(isPresented: $viewModel.showProgramBuilder) {
                ProgramBuilderView(viewModel: viewModel)
            }
            .sheet(isPresented: $showProgramCreation) {
                ProgramCreationView(
                    viewModel: viewModel,
                    activeProtocol: homeViewModel.activeProtocol,
                    bodyGoal: bodyGoalViewModel.currentGoal,
                    currentWeight: bodyGoalViewModel.currentWeight > 0 ? bodyGoalViewModel.currentWeight : nil,
                    targetWeight: bodyGoalViewModel.targetWeight > 0 ? bodyGoalViewModel.targetWeight : nil,
                    totalWorkouts: viewModel.workoutHistory.count
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $viewModel.showProgramManagement) {
                ProgramManagementView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showSportSelector) {
                SportSelectorView { sport in
                    selectedSport = sport
                    showSportSelector = false
                    showSportLog = true
                }
            }
            .sheet(isPresented: $showSportLog) {
                SportSessionLogView(sport: selectedSport) { session in
                    viewModel.addSportSession(session)
                }
            }
            .trainRunCyclingSwimSheets(
                runVM: runVM,
                cyclingVM: cyclingVM,
                swimVM: swimVM,
                showLiveRun: $showLiveRun,
                showLiveRide: $showLiveRide
            )
            .trainBasketballSheets(bbVM: bbVM)
            .trainSoccerTennisSheets(soccerVM: soccerVM, tennisVM: tennisVM)
            .trainVolleyPickleMASheets(volleyballVM: volleyballVM, pickleVM: pickleVM, maVM: maVM)
            .sheet(isPresented: $showProgressSheet) {
                TrainProgressSheet(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showRoutines) {
                RoutinesListView(trainViewModel: viewModel)
            }
            .sheet(isPresented: $showRoutineEditor) {
                RoutineEditorView()
                    .presentationDetents([.large])
            }
            .onAppear {
                viewModel.loadAllData()
                homeViewModel.loadProtocolsFromSupabase()
                homeViewModel.onAppear()
                bodyGoalViewModel.loadData()
                energyBalanceViewModel.loadData()
                if isLoading {
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Floating Modes Pill

    private var trainModesPill: some View {
        FloatingNavPill(scrollOffset: scrollOffset, accent: viewModel.currentMode.type.color) {
            Button {
                viewModel.showModeSelectorSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.currentMode.type.icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Modes")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundStyle(viewModel.currentMode.type.color)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: viewModel.showModeSelectorSheet)
        }
    }

    // MARK: - Mode Tab Bar

    private var modeTabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableModes) { mode in
                    let isActive = viewModel.currentMode.id == mode.id
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.switchMode(mode)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.type.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(mode.name)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isActive ? .black : PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isActive ? mode.type.color : PepTheme.elevated)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isActive)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    // MARK: - Main Content (streamlined)

    private var mainContent: some View {
        VStack(spacing: 24) {
            todayHero
            weeklyStripSection
            progressTilesSection
            activitySection
            SportCoachCard(sport: .main, accent: PepTheme.teal)
            libraryRow
            historySection
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .navigationDestination(isPresented: $showActivity) {
            ActivityView(viewModel: energyBalanceViewModel)
        }
        .sheet(isPresented: $showLogActivity) {
            LogActivitySheet()
                .presentationDetents([.large])
        }
        .onChange(of: showActivity) { _, isShowing in
            if !isShowing {
                Task { await energyBalanceViewModel.refresh() }
            }
        }
    }

    // MARK: - Activity (relocated from Home)

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Activity")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            StepsModuleCardView(
                healthKit: homeViewModel.healthKit,
                stepsCalories: energyBalanceViewModel.stepsCalories,
                showStepDetail: $showStepDetail
            )
            DailyActivityCard(
                viewModel: energyBalanceViewModel,
                onLogActivity: { showLogActivity = true },
                onTapActivity: { showActivity = true }
            )
        }
    }

    // MARK: - Today Hero (unified)

    private var todayHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Eyebrow + program chip
            HStack(alignment: .center) {
                heroEyebrow
                Spacer()
                if let program = viewModel.activeProgram {
                    Button {
                        viewModel.showProgramManagement = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(program.name)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Headline
            Text(headlineText)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .kerning(-0.6)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            accentRule

            // Body
            heroBody
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.teal.opacity(0.18), PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var heroEyebrow: some View {
        HStack(spacing: 8) {
            Text("01")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PepTheme.teal.opacity(0.9))
            Text("—")
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
            Text("TODAY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
        }
    }

    private var headlineText: String {
        if viewModel.isRestDay { return "Rest Day" }
        if !viewModel.todayWorkoutDays.isEmpty { return viewModel.todayDayName }
        if !routineStore.routines.isEmpty { return "Choose a Routine" }
        return "Quick Start"
    }

    @ViewBuilder
    private var heroBody: some View {
        if viewModel.isRestDay {
            restDayBody
        } else if !viewModel.todayWorkoutDays.isEmpty {
            todayProgramBody
        } else if !routineStore.routines.isEmpty {
            todayRoutinesBody
        } else {
            todayQuickStartBody
        }
    }

    private var restDayBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green.opacity(0.85))
                Text("Recovery is where growth happens. Stay hydrated and stretch.")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            primaryCTA(title: "Log a Workout Anyway", icon: "bolt.fill") {
                startEmptyWorkout()
            }
        }
    }

    private var todayProgramBody: some View {
        VStack(spacing: 18) {
            ForEach(Array(viewModel.todayWorkoutDays.enumerated()), id: \.element.id) { idx, day in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        if let tod = day.timeOfDay {
                            HStack(spacing: 4) {
                                Image(systemName: tod.icon)
                                    .font(.system(size: 9))
                                Text(tod.label.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1.0)
                            }
                            .foregroundStyle(PepTheme.amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PepTheme.amber.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        Text(day.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(day.exercises.count) ex")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(day.exercises.enumerated()), id: \.element.id) { exIdx, exercise in
                            exerciseRow(exercise)
                            if exIdx < day.exercises.count - 1 {
                                Rectangle()
                                    .fill(PepTheme.glassBorderTop.opacity(0.5))
                                    .frame(height: 0.5)
                                    .padding(.leading, 38)
                            }
                        }
                    }

                    primaryCTA(title: "Begin Workout", icon: "play.fill") {
                        startWorkoutFromDay(day)
                    }

                    if idx < viewModel.todayWorkoutDays.count - 1 {
                        accentRule.padding(.top, 4)
                    }
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ProgramExercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.primaryMuscle.icon)
                .font(.system(size: 11))
                .foregroundStyle(PepTheme.teal.opacity(0.75))
                .frame(width: 26, height: 26)
                .background(PepTheme.teal.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.exerciseName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text("\(exercise.targetSets) × \(exercise.targetRepsMin)–\(exercise.targetRepsMax)")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            let trend = viewModel.progressiveOverloadTrend(for: exercise.exerciseName)
            Text(trend)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(trend == "↑" ? .green : trend == "↓" ? .red : PepTheme.textTertiary)
        }
        .padding(.vertical, 7)
    }

    private var todayRoutinesBody: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(routineStore.routines.prefix(3).enumerated()), id: \.element.id) { idx, routine in
                    Button {
                        startWorkoutFromRoutine(routine)
                    } label: {
                        routineEditorialRow(routine)
                    }
                    .buttonStyle(.plain)
                    if idx < min(routineStore.routines.count, 3) - 1 {
                        Rectangle()
                            .fill(PepTheme.glassBorderTop.opacity(0.5))
                            .frame(height: 0.5)
                    }
                }
            }

            HStack(spacing: 10) {
                primaryCTA(title: "Quick Workout", icon: "bolt.fill") {
                    startEmptyWorkout()
                }
                ghostCTA(title: "All Routines", icon: "list.bullet") {
                    showRoutines = true
                }
            }
        }
    }

    private func routineEditorialRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: -6) {
                ForEach(Array(routine.muscleGroups.prefix(3).enumerated()), id: \.offset) { _, muscle in
                    Image(systemName: muscle.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 24, height: 24)
                        .background(PepTheme.teal.opacity(0.14))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(PepTheme.cardSurface, lineWidth: 1.5))
                }
            }
            .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(routine.exercises.count) ex")
                    Text("·")
                    Text("\(routine.estimatedMinutes)m")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(PepTheme.teal)
        }
        .padding(.vertical, 10)
    }

    private var todayQuickStartBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No active program. Start something quick or build a routine you can reuse.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            primaryCTA(title: "Quick Workout", icon: "bolt.fill") {
                startEmptyWorkout()
            }

            HStack(spacing: 10) {
                ghostCTA(title: "Browse Routines", icon: "list.bullet.rectangle.portrait") {
                    showRoutines = true
                }
                ghostCTA(title: "New Program", icon: "plus.rectangle.on.folder") {
                    showProgramCreation = true
                }
            }
        }
    }

    private var accentRule: some View {
        LinearGradient(
            colors: [PepTheme.teal.opacity(0.45), PepTheme.teal.opacity(0.0)],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 0.6)
    }

    // MARK: - CTAs

    private func primaryCTA(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PepTheme.teal)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.impact(weight: .medium), trigger: sessionManager.showActiveWorkout)
    }

    private func ghostCTA(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(PepTheme.teal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(PepTheme.teal.opacity(0.1))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(PepTheme.teal.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Strip

    private var weeklyStripSection: some View {
        let insight = viewModel.weeklyInsight
        return HStack(spacing: 10) {
            consistencyChip
            weeklyStat(label: "Sessions", value: "\(insight.totalSessions)", accent: PepTheme.teal)
            weeklyStat(label: "Volume", value: viewModel.formattedVolume(insight.totalVolume), accent: PepTheme.violet)
        }
    }

    private var consistencyChip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 4)
                    .frame(width: 38, height: 38)
                Circle()
                    .trim(from: 0, to: viewModel.consistencyProgress)
                    .stroke(PepTheme.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))
                Text("\(viewModel.workoutsCompletedThisWeek)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(viewModel.workoutsCompletedThisWeek)/\(viewModel.weeklyWorkoutGoal)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("WEEK")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func weeklyStat(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .kerning(-0.3)
                .foregroundStyle(PepTheme.textPrimary)
            LinearGradient(
                colors: [accent.opacity(0.5), accent.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Progress Tiles (02)

    private var progressTilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Progress", number: "02", accent: PepTheme.teal) {
                Button {
                    showProgressSheet = true
                } label: {
                    Text("SEE ALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                personalRecordTile
                recoveryTile
            }
        }
    }

    private var personalRecordTile: some View {
        let prs = viewModel.personalRecords
        let latest = prs.first
        return Button {
            showProgressSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(latest?.isNew == true ? "NEW PR" : "PERSONAL RECORD")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.amber)
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.amber.opacity(0.85))
                }

                if let latest {
                    Text(latest.exerciseName)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text("\(Int(latest.weight)) lbs × \(latest.reps)")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("\(prs.count) tracked")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    Text("Log a set to start tracking PRs")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.amber.opacity(0.22), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var recoveryTile: some View {
        let items = viewModel.muscleRecoveryItems
        let worst = items.min { lhs, rhs in
            recoveryRank(lhs.status) < recoveryRank(rhs.status)
        }
        let recoveringCount = items.filter { $0.status != .recovered }.count
        let color: Color = {
            guard let worst else { return .green }
            return statusColor(worst.status)
        }()

        return Button {
            showProgressSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("RECOVERY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 10))
                        .foregroundStyle(color.opacity(0.85))
                }

                if let worst {
                    Text(worst.muscle.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(worst.status.rawValue)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(color)

                    Text("\(recoveringCount) recovering")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                } else {
                    Text("All muscle groups fresh")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func recoveryRank(_ status: MuscleRecoveryStatus) -> Int {
        switch status {
        case .fatigued: 0
        case .recovering: 1
        case .recovered: 2
        }
    }

    private func statusColor(_ status: MuscleRecoveryStatus) -> Color {
        switch status {
        case .recovered: .green
        case .recovering: .orange
        case .fatigued: .red
        }
    }

    // MARK: - Library

    private var libraryRow: some View {
        Button {
            showLibrary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 32, height: 32)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Exercise Library")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(ExerciseLibrary.all.count) exercises")
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(12)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.scale)
    }

    // MARK: - History (compressed)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow("Activity History", number: "03", accent: PepTheme.teal) {
                Button {
                    showProgressSheet = true
                } label: {
                    Text("SEE ALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            if viewModel.combinedHistory.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Activity Yet",
                    message: "Start a workout or log a sport session to build your history.",
                    actionTitle: "Start Workout"
                ) {
                    startEmptyWorkout()
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.combinedHistory.prefix(5)) { item in
                        historyRow(item)
                    }
                }
            }
        }
    }

    private func historyRow(_ item: CombinedHistoryItem) -> some View {
        let isExpanded = expandedItemId == item.id
        let accentColor = item.isSportSession ? (item.sportSession?.sport.color ?? PepTheme.teal) : PepTheme.teal

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                expandedItemId = isExpanded ? nil : item.id
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if let session = item.sportSession {
                        ZStack {
                            Circle()
                                .fill(session.sport.color.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: session.sport.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(session.sport.color)
                        }
                    } else {
                        VStack(spacing: 0) {
                            Text(dayAbbreviation(item.date))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(dayNumber(item.date))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .frame(width: 34)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text("\(item.durationMinutes)m")
                            if item.totalVolume > 0 {
                                Text("·")
                                Text(viewModel.formattedVolume(item.totalVolume))
                            }
                            if let session = item.sportSession {
                                Text("·")
                                Text("\(session.intensity)/10")
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if isExpanded {
                    expandedContent(item: item, accentColor: accentColor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(PepTheme.cardSurface.overlay(isExpanded ? PepTheme.cardOverlay : Color.clear))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isExpanded
                            ? accentColor.opacity(0.2)
                            : PepTheme.glassBorderTop.opacity(0.4),
                        lineWidth: isExpanded ? 0.8 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    private func expandedContent(item: CombinedHistoryItem, accentColor: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PepTheme.glassBorderTop)
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            if let session = item.sportSession {
                sportSessionDetails(session: session)
            } else if !item.exercises.isEmpty {
                workoutExerciseDetails(exercises: item.exercises, accentColor: accentColor)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Session completed")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
    }

    private func workoutExerciseDetails(exercises: [WorkoutHistoryExerciseDetail], accentColor: Color) -> some View {
        VStack(spacing: 10) {
            ForEach(exercises) { exercise in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(accentColor.opacity(0.7))
                        Text(exercise.exerciseName)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Text("\(exercise.sets.count) sets")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    HStack(spacing: 0) {
                        Text("SET").frame(width: 32, alignment: .leading)
                        Text("WEIGHT").frame(maxWidth: .infinity)
                        Text("REPS").frame(maxWidth: .infinity)
                        Text("VOL").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))

                    ForEach(exercise.sets) { set in
                        HStack(spacing: 0) {
                            Text("\(set.setNumber)").frame(width: 32, alignment: .leading)
                            Text("\(Int(set.weight)) lbs").frame(maxWidth: .infinity)
                            Text("\(set.reps)").frame(maxWidth: .infinity)
                            Text("\(Int(set.weight) * set.reps)")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(accentColor.opacity(0.7))
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PepTheme.textPrimary.opacity(0.8))
                    }
                }
                .padding(10)
                .background(PepTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func sportSessionDetails(session: SportSession) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                sportDetailPill(icon: "clock", label: "Duration", value: "\(session.durationMinutes) min")
                sportDetailPill(icon: "flame.fill", label: "Intensity", value: "\(session.intensity)/10")
                sportDetailPill(icon: "tag", label: "Type", value: session.sessionType.rawValue)
            }

            switch session.specificStats {
            case .basketball(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: "\(stats.points)", label: "Points", color: session.sport.color)
                    sportStatCard(value: "\(stats.assists)", label: "Assists", color: session.sport.color)
                    sportStatCard(value: "\(stats.rebounds)", label: "Rebounds", color: session.sport.color)
                }
            case .running(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: String(format: "%.1f mi", stats.distanceMiles), label: "Distance", color: session.sport.color)
                    sportStatCard(value: String(format: "%.1f min/mi", stats.paceMinutesPerMile), label: "Pace", color: session.sport.color)
                }
            case .swimming(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: "\(stats.laps)", label: "Laps", color: session.sport.color)
                    sportStatCard(value: stats.stroke.rawValue, label: "Stroke", color: session.sport.color)
                }
            case .cycling(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: String(format: "%.1f mi", stats.distanceMiles), label: "Distance", color: session.sport.color)
                    sportStatCard(value: String(format: "%.1f mph", stats.averageSpeed), label: "Avg Speed", color: session.sport.color)
                    sportStatCard(value: String(format: "%.0f ft", stats.elevationGain), label: "Elevation", color: session.sport.color)
                }
            case .soccer(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: "\(stats.goals)", label: "Goals", color: session.sport.color)
                    sportStatCard(value: "\(stats.assists)", label: "Assists", color: session.sport.color)
                    sportStatCard(value: String(format: "%.1f km", stats.distanceKm), label: "Distance", color: session.sport.color)
                }
            case .tennis(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: "\(stats.aces)", label: "Aces", color: session.sport.color)
                    sportStatCard(value: "\(stats.winners)", label: "Winners", color: session.sport.color)
                    sportStatCard(value: String(format: "%.0f%%", stats.firstServePercentage), label: "1st Srv%", color: session.sport.color)
                }
            case .volleyball(let stats):
                HStack(spacing: 12) {
                    sportStatCard(value: "\(stats.kills)", label: "Kills", color: session.sport.color)
                    sportStatCard(value: "\(stats.aces)", label: "Aces", color: session.sport.color)
                    sportStatCard(value: "\(stats.blocks)", label: "Blocks", color: session.sport.color)
                }
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func sportDetailPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func sportStatCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 8))
    }

    // MARK: - Sport Mode Content (with editorial header)

    @ViewBuilder
    private var sportModeContent: some View {
        VStack(spacing: 16) {
            sportEditorialHeader

            switch viewModel.currentMode.type {
            case .running:
                RunningDashboardView(
                    runVM: runVM,
                    accentColor: viewModel.currentMode.type.color
                ) {
                    showLiveRun = true
                }
            case .cycling:
                CyclingDashboardView(
                    cyclingVM: cyclingVM,
                    accentColor: viewModel.currentMode.type.color
                ) {
                    showLiveRide = true
                }
            case .basketball:
                BasketballDashboardView(
                    bbVM: bbVM,
                    accentColor: viewModel.currentMode.type.color,
                    firstName: homeViewModel.userFirstName
                )
            case .swimming:
                SwimmingDashboardView(
                    swimVM: swimVM,
                    accentColor: viewModel.currentMode.type.color
                )
            case .soccer:
                SoccerDashboardView(
                    soccerVM: soccerVM,
                    accentColor: viewModel.currentMode.type.color
                )
            case .tennis:
                TennisDashboardView(
                    tennisVM: tennisVM,
                    accentColor: viewModel.currentMode.type.color
                )
            case .volleyball:
                VolleyballDashboardView(
                    volleyballVM: volleyballVM,
                    accentColor: viewModel.currentMode.type.color
                )
            case .pickleball:
                PickleballDashboardView(
                    pickleVM: pickleVM,
                    accentColor: viewModel.currentMode.type.color
                )
            case .martialArts:
                MartialArtsDashboardView(
                    maVM: maVM,
                    accentColor: viewModel.currentMode.type.color
                )
            default:
                SportModeContentView(
                    mode: viewModel.currentMode,
                    viewModel: viewModel
                ) {
                    if let sport = viewModel.currentMode.type.sport {
                        selectedSport = sport
                        showSportLog = true
                    } else {
                        showSportSelector = true
                    }
                }
            }
        }
    }

    private var sportEditorialHeader: some View {
        let mode = viewModel.currentMode
        let accent = mode.type.color
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("01")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.9))
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
                Text(mode.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                Spacer()
            }

            LinearGradient(
                colors: [accent.opacity(0.5), accent.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.6)
        }
    }

    // MARK: - Helpers

    private func startWorkoutFromDay(_ day: ProgramDay) {
        let exercises = day.exercises.map { pe in
            let exercise = ExerciseLibrary.all.first { $0.id == pe.exerciseId } ?? ExerciseLibrary.all[0]
            return WorkoutExercise(
                exercise: exercise,
                targetSets: pe.targetSets,
                previousWeight: Double.random(in: 95...185),
                previousReps: Int.random(in: 8...12)
            )
        }
        sessionManager.startSession(name: day.name, exercises: exercises)
    }

    private func startWorkoutFromRoutine(_ routine: Routine) {
        let exercises: [WorkoutExercise] = routine.exercises.map { pe in
            let exercise = ExerciseLibrary.all.first { $0.id == pe.exerciseId } ?? ExerciseLibrary.all[0]
            return WorkoutExercise(
                exercise: exercise,
                targetSets: pe.targetSets,
                previousWeight: pe.prescribedWeight,
                previousReps: pe.targetRepsMax
            )
        }
        sessionManager.startSession(name: routine.name, exercises: exercises)
        routineStore.markPerformed(routine.id)
    }

    private func startWorkoutFromProgram(_ program: TrainingProgram) {
        guard let day = viewModel.todayWorkoutDay ?? program.days.first else { return }
        startWorkoutFromDay(day)
    }

    private func startEmptyWorkout() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let name = "\(formatter.string(from: Date())) Workout"
        sessionManager.startSession(name: name, exercises: [])
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
