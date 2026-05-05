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
    @State private var showLibrary: Bool = false
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var showSportSelector: Bool = false
    @State private var showSportLog: Bool = false
    @State private var selectedSport: Sport = .basketball
    @State private var isLoading: Bool = true
    @State private var expandedItemId: UUID? = nil
    @State private var showAllRecovery: Bool = false
    @State private var showAnalyticsDetail: Bool = false
    @State private var showProgramCreation: Bool = false
    @State private var showLiveRun: Bool = false
    @State private var showLiveRide: Bool = false
    @State private var showBasketballGameLog: Bool = false
    @State private var showProgressSheet: Bool = false
    @State private var showRoutines: Bool = false
    @State private var showRoutineEditor: Bool = false
    @State private var routineStore = RoutineStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    SkeletonTrainView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        inlineHeader
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .padding(.bottom, 8)

                        if viewModel.availableModes.count > 1 {
                            modeTabBar
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                        }

                        if viewModel.currentMode.type == .main {
                            mainContent
                                .transition(.opacity)
                        } else if viewModel.currentMode.type == .running {
                            RunningDashboardView(
                                runVM: runVM,
                                accentColor: viewModel.currentMode.type.color
                            ) {
                                showLiveRun = true
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        } else if viewModel.currentMode.type == .cycling {
                            CyclingDashboardView(
                                cyclingVM: cyclingVM,
                                accentColor: viewModel.currentMode.type.color
                            ) {
                                showLiveRide = true
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        } else if viewModel.currentMode.type == .basketball {
                            BasketballDashboardView(
                                bbVM: bbVM,
                                accentColor: viewModel.currentMode.type.color
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        } else if viewModel.currentMode.type == .swimming {
                            SwimmingDashboardView(
                                swimVM: swimVM,
                                accentColor: viewModel.currentMode.type.color
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        } else if viewModel.currentMode.type == .soccer {
                            SoccerDashboardView(
                                soccerVM: soccerVM,
                                accentColor: viewModel.currentMode.type.color
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        } else if viewModel.currentMode.type == .tennis {
                            TennisDashboardView(
                                tennisVM: tennisVM,
                                accentColor: viewModel.currentMode.type.color
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        } else {
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
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                        }
                    }
                }
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

            .navigationDestination(isPresented: $showLiveRun) {
                LiveRunView(runVM: runVM)
            }
            .navigationDestination(isPresented: $showLiveRide) {
                LiveRideView(cyclingVM: cyclingVM)
            }
            .navigationDestination(isPresented: $cyclingVM.showRideDetail) {
                if let ride = cyclingVM.selectedRide {
                    RideDetailView(ride: ride, bike: cyclingVM.bikeForRide(ride))
                }
            }
            .sheet(isPresented: $cyclingVM.showCyclingSettings) {
                CyclingSettingsView(cyclingVM: cyclingVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $cyclingVM.showBikeManager) {
                CyclingSettingsView(cyclingVM: cyclingVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $runVM.showRunDetail) {
                if let run = runVM.selectedRun {
                    RunDetailView(run: run, shoe: runVM.shoeForRun(run))
                }
            }
            .sheet(isPresented: $runVM.showRunSettings) {
                RunningSettingsView(runVM: runVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $runVM.showShoeManager) {
                RunningSettingsView(runVM: runVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showGameLog) {
                BasketballGameLogSheet(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showShotChart) {
                BasketballShotChartView(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showDrillLibrary) {
                BasketballDrillLibraryView(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showPracticePlanBuilder) {
                BasketballDrillLibraryView(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $swimVM.showSwimSettings) {
                SwimSettingsView(swimVM: swimVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $swimVM.showDrillLibrary) {
                SwimDrillLibraryView(swimVM: swimVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $swimVM.showWorkoutBuilder) {
                SwimWorkoutBuilderView(swimVM: swimVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $runVM.showWorkoutBuilder) {
                RunningWorkoutBuilderView(runVM: runVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $cyclingVM.showWorkoutBuilder) {
                CyclingWorkoutBuilderView(cyclingVM: cyclingVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $soccerVM.showWorkoutBuilder) {
                SoccerWorkoutBuilderView(soccerVM: soccerVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $tennisVM.showWorkoutBuilder) {
                TennisWorkoutBuilderView(tennisVM: tennisVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $swimVM.showCSSTest) {
                SwimSettingsView(swimVM: swimVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $swimVM.showSwimDetail) {
                if let swim = swimVM.selectedSwim {
                    SwimDetailView(swim: swim)
                }
            }
            .navigationDestination(isPresented: $bbVM.showGameDetail) {
                if let game = bbVM.selectedGame {
                    BasketballGameDetailView(game: game)
                }
            }
            .sheet(isPresented: $soccerVM.showGameLog) {
                SoccerGameLogSheet(soccerVM: soccerVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $soccerVM.showDrillLibrary) {
                SoccerDrillLibraryView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $soccerVM.showSettings) {
                SoccerSettingsView(soccerVM: soccerVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $soccerVM.showMatchDetail) {
                if let match = soccerVM.selectedMatch {
                    SoccerGameDetailView(match: match)
                }
            }
            .sheet(isPresented: $tennisVM.showMatchLog) {
                TennisGameLogSheet(tennisVM: tennisVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $tennisVM.showDrillLibrary) {
                TennisDrillLibraryView()
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $tennisVM.showLiveScorer) {
                TennisLiveScorerView(tennisVM: tennisVM)
            }
            .navigationDestination(isPresented: $tennisVM.showMatchDetail) {
                if let match = tennisVM.selectedMatch {
                    TennisMatchDetailView(match: match)
                }
            }
            .onAppear {
                viewModel.loadAllData()
                homeViewModel.loadProtocolsFromSupabase()
                bodyGoalViewModel.loadData()
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

    // MARK: - Inline Header (scrolls away)

    private var inlineHeader: some View {
        HStack {
            Spacer()
            Button {
                viewModel.showModeSelectorSheet = true
            } label: {
                Image(systemName: viewModel.currentMode.type.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(viewModel.currentMode.type.color)
                    .frame(width: 34, height: 34)
                    .background(viewModel.currentMode.type.color.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 38)
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

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 20) {
            todayWorkoutSection
            routinesSection
            SportCoachCard(sport: .main, accent: PepTheme.teal)
            statTilesSection
            progressStripSection
            libraryButton
            historySection
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
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
    }

    // MARK: - Routines Section

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Routines", number: "02", accent: PepTheme.teal) {
                Button {
                    showRoutines = true
                } label: {
                    Text(routineStore.routines.isEmpty ? "MANAGE" : "SEE ALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            if routineStore.routines.isEmpty {
                routinesEmptyState
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(routineStore.routines.prefix(6)) { routine in
                            Button {
                                startWorkoutFromRoutine(routine)
                            } label: {
                                routineCompactCard(routine)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showRoutineEditor = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PepTheme.teal)
                                Text("New Routine")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                            }
                            .frame(width: 150, height: 100)
                            .background(PepTheme.teal.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [4]))
                                    .foregroundStyle(PepTheme.teal.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }
        }
    }

    private var routinesEmptyState: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal.opacity(0.8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save your favorites")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Log a workout and tap Save as Routine to reuse it with one tap.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    showRoutineEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("New Routine")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(PepTheme.teal.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showRoutines = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Programs")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func routineCompactCard(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(routine.muscleGroups.prefix(3), id: \.self) { muscle in
                    Image(systemName: muscle.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 22, height: 22)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(Circle())
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal)
            }

            Text(routine.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Label("\(routine.exercises.count)", systemImage: "dumbbell.fill")
                Text("·")
                Label("\(routine.estimatedMinutes)m", systemImage: "clock")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(PepTheme.textSecondary)
        }
        .padding(12)
        .frame(width: 170, height: 100, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
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

    // MARK: - Stat Tiles (condensed)

    private var statTilesSection: some View {
        let insight = viewModel.weeklyInsight
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            consistencyTile
            statTile(icon: "figure.strengthtraining.traditional", label: "Sessions", value: "\(insight.totalSessions)", color: PepTheme.teal)
            statTile(icon: "scalemass.fill", label: "Volume", value: viewModel.formattedVolume(insight.totalVolume), color: PepTheme.violet)
            statTile(icon: "flame.fill", label: "Calories", value: "\(insight.totalCaloriesBurned)", color: .orange)
        }
    }

    private var consistencyTile: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 5)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: viewModel.consistencyProgress)
                    .stroke(PepTheme.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(viewModel.workoutsCompletedThisWeek)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.workoutsCompletedThisWeek)/\(viewModel.weeklyWorkoutGoal)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Consistency")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func statTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .kerning(-0.3)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer(minLength: 0)
            LinearGradient(
                colors: [color.opacity(0.5), color.opacity(0.0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Progress Strip

    private var progressStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Progress", number: "03", accent: PepTheme.teal) {
                Button {
                    showProgressSheet = true
                } label: {
                    Text("SEE ALL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(viewModel.personalRecords.prefix(5)) { pr in
                        progressPRCard(pr)
                    }
                    ForEach(viewModel.muscleRecoveryItems.prefix(4)) { item in
                        progressRecoveryCard(item)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func progressPRCard(_ pr: TrainPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pr.isNew ? "NEW PR" : "PR")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.amber)

            Text(pr.exerciseName)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text("\(Int(pr.weight)) lbs × \(pr.reps)")
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
        .padding(12)
        .frame(width: 140, height: 100, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PepTheme.amber.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func progressRecoveryCard(_ item: MuscleRecoveryItem) -> some View {
        let color: Color = switch item.status {
        case .recovered: .green
        case .recovering: .orange
        case .fatigued: .red
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("RECOVERY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(color)

            Text(item.muscle.rawValue)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(item.status.rawValue)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(width: 140, height: 100, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Today's Workout

    private var todayWorkoutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("01 — TODAY'S SESSION")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.9))
                        Text(viewModel.todayDayName)
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .kerning(-0.4)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
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

                if viewModel.isRestDay {
                    restDayContent
                } else if !viewModel.todayWorkoutDays.isEmpty {
                    todayWorkoutsContent
                } else {
                    noProgamContent
                }
            }
        }
    }

    private var restDayContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundStyle(.green.opacity(0.8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Day")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Recovery is where growth happens. Stay hydrated and stretch.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.06))
            .clipShape(.rect(cornerRadius: 10))

            secondaryActionsRow
        }
    }

    private var todayWorkoutsContent: some View {
        VStack(spacing: 14) {
            ForEach(Array(viewModel.todayWorkoutDays.enumerated()), id: \.element.id) { idx, day in
                todayExercisesList(day, showDivider: idx < viewModel.todayWorkoutDays.count - 1)
            }
        }
    }

    private func todayExercisesList(_ day: ProgramDay, showDivider: Bool = false) -> some View {
        let isLastDay = !showDivider
        return VStack(spacing: 8) {
            HStack {
                if let tod = day.timeOfDay {
                    HStack(spacing: 4) {
                        Image(systemName: tod.icon)
                            .font(.system(size: 10))
                        Text(tod.label.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(PepTheme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PepTheme.amber.opacity(0.12))
                    .clipShape(Capsule())
                }
                Text(day.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(day.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            ForEach(day.exercises) { exercise in
                HStack(spacing: 10) {
                    Image(systemName: exercise.primaryMuscle.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.teal.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(exercise.targetSets) sets × \(exercise.targetRepsMin)-\(exercise.targetRepsMax) reps")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    let trend = viewModel.progressiveOverloadTrend(for: exercise.exerciseName)
                    Text(trend)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(trend == "↑" ? .green : trend == "↓" ? .red : PepTheme.textSecondary)
                }
                .padding(.vertical, 4)
            }

            Button {
                startWorkoutFromDay(day)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("Begin Workout")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .padding(.top, 4)
            .sensoryFeedback(.impact(weight: .medium), trigger: sessionManager.showActiveWorkout)

            if isLastDay {
                secondaryActionsRow
                    .padding(.top, 2)
            }

            if showDivider {
                Divider()
                    .background(PepTheme.glassBorderTop)
                    .padding(.top, 4)
            }
        }
    }

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

    private var noProgamContent: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 28))
                    .foregroundStyle(PepTheme.teal.opacity(0.6))
                Text("No Active Program")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Set up a training program to get started")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                startEmptyWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Log a Workout")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: sessionManager.showActiveWorkout)

            Button {
                showRoutines = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 14, weight: .semibold))
                    Text(routineStore.routines.isEmpty ? "Browse Routines" : "Start from Routine")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(PepTheme.teal.opacity(0.12))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(PepTheme.teal.opacity(0.3), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            secondaryActionsRow
        }
    }

    // MARK: - Secondary actions (merged into hero)

    private var secondaryActionsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("OR")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textTertiary)
                Rectangle()
                    .fill(PepTheme.glassBorderTop)
                    .frame(height: 0.5)
            }

            HStack(spacing: 8) {
                editorialQuickAction(
                    eyebrow: "01",
                    title: "Quick",
                    subtitle: "Workout",
                    icon: "bolt.fill",
                    accent: PepTheme.teal
                ) { startEmptyWorkout() }

                editorialQuickAction(
                    eyebrow: "02",
                    title: "Log",
                    subtitle: "Sport",
                    icon: "sportscourt.fill",
                    accent: .orange
                ) { showSportSelector = true }

                editorialQuickAction(
                    eyebrow: "03",
                    title: "New",
                    subtitle: "Program",
                    icon: "plus.rectangle.on.folder",
                    accent: PepTheme.violet
                ) { showProgramCreation = true }
            }
        }
        .padding(.top, 6)
    }

    private func editorialQuickAction(
        eyebrow: String,
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(eyebrow)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textTertiary)
                    Spacer(minLength: 4)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accent.opacity(0.25), PepTheme.glassBorderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.impact(weight: .light), trigger: sessionManager.showActiveWorkout)
    }

    // MARK: - Consistency Ring

    private var consistencyRingSection: some View {
        GlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(PepTheme.elevated, lineWidth: 8)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: viewModel.consistencyProgress)
                        .stroke(
                            AngularGradient(
                                colors: [PepTheme.teal, PepTheme.teal.opacity(0.4), PepTheme.teal],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(viewModel.workoutsCompletedThisWeek)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(PepTheme.teal)
                        Text("/\(viewModel.weeklyWorkoutGoal)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Consistency")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("\(viewModel.workoutsCompletedThisWeek) of \(viewModel.weeklyWorkoutGoal) sessions completed")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)

                    if viewModel.workoutsCompletedThisWeek >= viewModel.weeklyWorkoutGoal {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                            Text("Goal reached!")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.green)
                    } else {
                        Text("\(viewModel.weeklyWorkoutGoal - viewModel.workoutsCompletedThisWeek) more to hit your goal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PepTheme.amber)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Weekly Insights

    private var weeklyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HeadlineText(text: "This Week")
                Spacer()
            }

            let insight = viewModel.weeklyInsight
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                insightTile(icon: "figure.strengthtraining.traditional", label: "Sessions", value: "\(insight.totalSessions)", color: PepTheme.teal)
                insightTile(icon: "scalemass.fill", label: "Volume", value: viewModel.formattedVolume(insight.totalVolume), color: PepTheme.teal)
                insightTile(icon: "clock.fill", label: "Avg Duration", value: "\(insight.avgDuration)m", color: PepTheme.violet)
                insightTile(icon: "flame.fill", label: "Calories", value: "\(insight.totalCaloriesBurned)", color: .orange)
            }


        }
    }

    private func insightTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
            }
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PepTheme.amber)
                HeadlineText(text: "Personal Records")
                Spacer()
            }

            let newPRs = viewModel.personalRecords.filter(\.isNew)
            if !newPRs.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(newPRs) { pr in
                            prCard(pr)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            ForEach(viewModel.personalRecords) { pr in
                prRow(pr)
            }
        }
    }

    private func prCard(_ pr: TrainPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.amber)
                Text("NEW PR")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(PepTheme.amber)
                    .tracking(1)
            }

            Text(pr.exerciseName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)

            Text("\(Int(pr.weight)) lbs × \(pr.reps)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.amber)

            if let prev = pr.previousBest {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("+\(Int(pr.weight - prev)) lbs")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.green)
            }
        }
        .padding(14)
        .frame(width: 160, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PepTheme.amber.opacity(0.08), PepTheme.cardSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func prRow(_ pr: TrainPersonalRecord) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(pr.isNew ? PepTheme.amber : PepTheme.glassBorderTop)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text(pr.dateAchieved.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Text("\(Int(pr.weight)) lbs")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(pr.isNew ? PepTheme.amber : PepTheme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Weekly Volume Chart

    private var weeklyVolumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(PepTheme.teal)
                HeadlineText(text: "Weekly Volume")
                Spacer()
            }

            let volumes = viewModel.weeklyMuscleVolumes
            ForEach(volumes) { vol in
                HStack(spacing: 10) {
                    Image(systemName: vol.muscle.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.teal.opacity(0.7))
                        .frame(width: 24)

                    Text(vol.muscle.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        let fraction = vol.targetSets > 0 ? min(CGFloat(vol.setsCompleted) / CGFloat(vol.targetSets), 1.0) : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PepTheme.elevated)
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    fraction >= 1.0
                                        ? AnyShapeStyle(.green.opacity(0.8))
                                        : fraction >= 0.6
                                            ? AnyShapeStyle(PepTheme.teal)
                                            : AnyShapeStyle(PepTheme.amber)
                                )
                                .frame(width: max(geo.size.width * fraction, 4), height: 10)
                        }
                    }
                    .frame(height: 10)

                    Text("\(vol.setsCompleted)/\(vol.targetSets)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(16)
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
    }

    // MARK: - Muscle Recovery

    private var muscleRecoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(.green)
                HeadlineText(text: "Recovery Status")
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showAllRecovery.toggle()
                    }
                } label: {
                    Text(showAllRecovery ? "Less" : "See All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            let items = showAllRecovery ? viewModel.muscleRecoveryItems : Array(viewModel.muscleRecoveryItems.prefix(4))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    recoveryCell(item)
                }
            }
        }
    }

    private func recoveryCell(_ item: MuscleRecoveryItem) -> some View {
        let color: Color = switch item.status {
        case .recovered: .green
        case .recovering: .orange
        case .fatigued: .red
        }

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: item.status.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.muscle.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                Text(item.status.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(10)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Warmup

    private var warmupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.flexibility")
                    .foregroundStyle(.orange)
                HeadlineText(text: "Warm-up")
                Spacer()
                Text(viewModel.todayWorkoutDay != nil ? "For today" : "General")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            ForEach(viewModel.warmupExercises) { warmup in
                HStack(spacing: 12) {
                    Image(systemName: warmup.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.orange.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(.orange.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(warmup.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(warmup.type.rawValue)
                            .font(.system(size: 10))
                            .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Text(warmup.durationOrReps)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [.orange.opacity(0.12), PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                startEmptyWorkout()
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("QUICK · OPEN STUDIO")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(.black.opacity(0.55))
                        Text("Start a Workout")
                            .font(.system(size: 19, weight: .semibold, design: .serif))
                            .kerning(-0.3)
                            .foregroundStyle(.black)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: PepTheme.teal.opacity(0.25), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.scalePrimary)
            .sensoryFeedback(.impact(weight: .medium), trigger: sessionManager.showActiveWorkout)

            HStack(spacing: 10) {
                Button {
                    showProgramCreation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.rectangle.on.folder")
                            .font(.body)
                        Text("New Program")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.scale)

                Button {
                    showSportSelector = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sportscourt.fill")
                            .font(.body)
                        Text("Log Sport")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [PepTheme.elevated, PepTheme.elevated.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.25), PepTheme.glassBorderBottom],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.scale)
            }
        }
    }

    // MARK: - Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HeadlineText(text: "My Templates")
                Spacer()
                Button { } label: {
                    Text("See All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.teal)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.templates) { template in
                        templateCard(template)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        Button { } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(template.muscleGroups.prefix(3)) { muscle in
                        Image(systemName: muscle.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 26, height: 26)
                            .background(PepTheme.teal.opacity(0.12))
                            .clipShape(Circle())
                    }
                }

                Text(template.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(template.exerciseCount)", systemImage: "dumbbell")
                    Text("·")
                    Label("\(template.estimatedMinutes)m", systemImage: "clock")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .frame(width: 160, alignment: .leading)
            .background(PepTheme.cardSurface)
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
        .buttonStyle(.scale)
    }

    // MARK: - Library Button

    private var libraryButton: some View {
        Button {
            showLibrary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercise Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Browse \(ExerciseLibrary.all.count) exercises")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(16)
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
        .buttonStyle(.scale)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Activity History", number: "04", accent: PepTheme.teal) {
                Button { } label: {
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
                ForEach(viewModel.combinedHistory.prefix(6)) { item in
                    combinedHistoryRow(item)
                }
            }
        }
    }

    private func combinedHistoryRow(_ item: CombinedHistoryItem) -> some View {
        let isExpanded = expandedItemId == item.id
        let accentColor = item.isSportSession ? (item.sportSession?.sport.color ?? PepTheme.teal) : PepTheme.teal

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                expandedItemId = isExpanded ? nil : item.id
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    if let session = item.sportSession {
                        ZStack {
                            Circle()
                                .fill(session.sport.color.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: session.sport.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(session.sport.color)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text(dayAbbreviation(item.date))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(dayNumber(item.date))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                        .frame(width: 40)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)

                            if let session = item.sportSession {
                                Text(session.sessionType.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(session.sport.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(session.sport.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 10) {
                            Label("\(item.durationMinutes)m", systemImage: "clock")
                            if item.totalVolume > 0 {
                                Label(viewModel.formattedVolume(item.totalVolume), systemImage: "scalemass")
                            }
                            if let session = item.sportSession {
                                Label("\(session.intensity)/10", systemImage: "flame")
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(12)

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
                            : (item.isSportSession
                                ? (item.sportSession?.sport.color ?? PepTheme.glassBorderTop).opacity(0.15)
                                : PepTheme.glassBorderTop.opacity(0.4)),
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
                        Text("SET")
                            .frame(width: 32, alignment: .leading)
                        Text("WEIGHT")
                            .frame(maxWidth: .infinity)
                        Text("REPS")
                            .frame(maxWidth: .infinity)
                        Text("VOL")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))

                    ForEach(exercise.sets) { set in
                        HStack(spacing: 0) {
                            Text("\(set.setNumber)")
                                .frame(width: 32, alignment: .leading)
                            Text("\(Int(set.weight)) lbs")
                                .frame(maxWidth: .infinity)
                            Text("\(set.reps)")
                                .frame(maxWidth: .infinity)
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

    // MARK: - Helpers

    private func startWorkoutFromProgram(_ program: TrainingProgram) {
        guard let day = viewModel.todayWorkoutDay ?? program.days.first else { return }
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
