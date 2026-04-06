import SwiftUI

struct TrainView: View {
    @State private var viewModel = TrainViewModel()
    @State private var runVM = RunningViewModel.shared
    @State private var cyclingVM = CyclingViewModel.shared
    @State private var bbVM = BasketballViewModel.shared
    @State private var swimVM = SwimmingViewModel.shared
    @State private var soccerVM = SoccerViewModel.shared
    @State private var tennisVM = TennisViewModel.shared
    @State private var showLibrary: Bool = false
    @State private var showActiveWorkout: Bool = false
    @State private var activeWorkoutExercises: [WorkoutExercise] = []
    @State private var activeWorkoutName: String = ""
    @State private var showSportSelector: Bool = false
    @State private var showSportLog: Bool = false
    @State private var selectedSport: Sport = .basketball
    @State private var isLoading: Bool = true
    @State private var expandedItemId: UUID? = nil
    @State private var showAllRecovery: Bool = false
    @State private var showAnalyticsDetail: Bool = false
    @State private var showLiveRun: Bool = false
    @State private var showLiveRide: Bool = false
    @State private var showBasketballGameLog: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    SkeletonTrainView()
                        .padding(.top, 8)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
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
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                }
            }
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
            .navigationDestination(isPresented: $showActiveWorkout) {
                ActiveWorkoutView(workoutName: activeWorkoutName, exercises: activeWorkoutExercises)
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
            consistencyRingSection
            weeklyInsightsSection
            personalRecordsSection
            weeklyVolumeSection
            muscleRecoverySection
            warmupSection
            actionButtons
            if !viewModel.templates.isEmpty {
                templatesSection
            }
            libraryButton
            historySection
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    // MARK: - Today's Workout

    private var todayWorkoutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption)
                                .foregroundStyle(PepTheme.teal)
                            Text("TODAY'S SESSION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(PepTheme.teal)
                                .tracking(1.2)
                        }
                        Text(viewModel.todayDayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                    Spacer()
                    if let program = viewModel.activeProgram {
                        Text("Week \(program.currentWeek)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(PepTheme.teal.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if viewModel.isRestDay {
                    restDayContent
                } else if let day = viewModel.todayWorkoutDay {
                    todayExercisesList(day)
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
        }
    }

    private func todayExercisesList(_ day: ProgramDay) -> some View {
        VStack(spacing: 8) {
            HStack {
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
                if let program = viewModel.activeProgram {
                    startWorkoutFromProgram(program)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("Begin Workout")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .padding(.top, 4)
        }
    }

    private var noProgamContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(PepTheme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Active Program")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Create a program or start a quick workout")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Button {
                startEmptyWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                    Text("Quick Workout")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
        }
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
        VStack(spacing: 10) {
            Button {
                startEmptyWorkout()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                    Text("Start Empty Workout")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PepTheme.teal)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.scalePrimary)
            .sensoryFeedback(.impact(weight: .medium), trigger: showActiveWorkout)

            HStack(spacing: 10) {
                Button {
                    viewModel.resetBuilder()
                    viewModel.showProgramBuilder = true
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
            HStack {
                HeadlineText(text: "Activity History")
                Spacer()
                Button { } label: {
                    Text("See All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.teal)
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
        activeWorkoutName = day.name
        activeWorkoutExercises = day.exercises.map { pe in
            let exercise = ExerciseLibrary.all.first { $0.id == pe.exerciseId } ?? ExerciseLibrary.all[0]
            return WorkoutExercise(
                exercise: exercise,
                targetSets: pe.targetSets,
                previousWeight: Double.random(in: 95...185),
                previousReps: Int.random(in: 8...12)
            )
        }
        showActiveWorkout = true
    }

    private func startEmptyWorkout() {
        let sampleExercises = Array(ExerciseLibrary.all.prefix(4))
        activeWorkoutName = "Quick Workout"
        activeWorkoutExercises = sampleExercises.map {
            WorkoutExercise(
                exercise: $0,
                targetSets: 3,
                previousWeight: Double.random(in: 65...185),
                previousReps: Int.random(in: 8...12)
            )
        }
        showActiveWorkout = true
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
