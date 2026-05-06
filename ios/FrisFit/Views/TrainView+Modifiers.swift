import SwiftUI

// MARK: - Modifier groups to reduce TrainView body type depth
// The runtime crashes with excessive recursion in Swift type-metadata
// decoding when a single body chains 30+ generic modifiers (.sheet,
// .navigationDestination, etc.). Splitting into ViewModifier structs
// keeps each generic chain shallow.

struct TrainViewBasketballSheets: ViewModifier {
    @Bindable var bbVM: BasketballViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $bbVM.showRunLog) {
                BasketballLogRunSheet(bbVM: bbVM)
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
            .sheet(isPresented: $bbVM.showSettings) {
                BasketballSettingsView(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showGoalsEditor) {
                BasketballGoalsEditorView(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showWeeklyFocus) {
                BasketballWeeklyFocusView(bbVM: bbVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $bbVM.showDrillDetail) {
                if let drill = bbVM.selectedDrill {
                    BasketballDrillDetailView(drill: drill, bbVM: bbVM)
                        .presentationDetents([.large])
                }
            }
            .fullScreenCover(item: $bbVM.runningDrill) { drill in
                BasketballGuidedDrillView(drill: drill, bbVM: bbVM)
            }
            .fullScreenCover(item: $bbVM.runningPlan) { plan in
                BasketballPlanRunnerView(plan: plan, bbVM: bbVM)
            }
            .navigationDestination(isPresented: $bbVM.showGameDetail) {
                if let game = bbVM.selectedGame {
                    BasketballGameDetailView(game: game)
                }
            }
            .navigationDestination(isPresented: $bbVM.showRunDetail) {
                if let game = bbVM.selectedGame {
                    BasketballRunDetailView(game: game, bbVM: bbVM)
                }
            }
    }
}

struct TrainViewRunCyclingSwimSheets: ViewModifier {
    @Bindable var runVM: RunningViewModel
    @Bindable var cyclingVM: CyclingViewModel
    @Bindable var swimVM: SwimmingViewModel
    @Binding var showLiveRun: Bool
    @Binding var showLiveRide: Bool

    func body(content: Content) -> some View {
        content
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
            .sheet(isPresented: $runVM.showWorkoutBuilder) {
                RunningWorkoutBuilderView(runVM: runVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $cyclingVM.showWorkoutBuilder) {
                CyclingWorkoutBuilderView(cyclingVM: cyclingVM)
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
            .sheet(isPresented: $swimVM.showCSSTest) {
                SwimSettingsView(swimVM: swimVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $swimVM.showSwimDetail) {
                if let swim = swimVM.selectedSwim {
                    SwimDetailView(swim: swim)
                }
            }
    }
}

struct TrainViewSoccerTennisSheets: ViewModifier {
    @Bindable var soccerVM: SoccerViewModel
    @Bindable var tennisVM: TennisViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $soccerVM.showWorkoutBuilder) {
                SoccerWorkoutBuilderView(soccerVM: soccerVM)
                    .presentationDetents([.large])
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
            .sheet(isPresented: $tennisVM.showWorkoutBuilder) {
                TennisWorkoutBuilderView(tennisVM: tennisVM)
                    .presentationDetents([.large])
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
    }
}

struct TrainViewVolleyPickleMASheets: ViewModifier {
    @Bindable var volleyballVM: VolleyballViewModel
    @Bindable var pickleVM: PickleballViewModel
    @Bindable var maVM: MartialArtsViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $volleyballVM.showMatchLog) {
                VolleyballGameLogSheet(volleyballVM: volleyballVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $volleyballVM.showDrillLibrary) {
                VolleyballDrillLibraryView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $volleyballVM.showSettings) {
                VolleyballSettingsView(volleyballVM: volleyballVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $volleyballVM.showWorkoutBuilder) {
                VolleyballWorkoutBuilderView(volleyballVM: volleyballVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $volleyballVM.showMatchDetail) {
                if let match = volleyballVM.selectedMatch {
                    VolleyballMatchDetailView(match: match)
                }
            }
            .sheet(isPresented: $pickleVM.showMatchLog) {
                PickleballGameLogSheet(pickleVM: pickleVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $pickleVM.showDrillLibrary) {
                PickleballDrillLibraryView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $pickleVM.showSettings) {
                PickleballSettingsView(pickleVM: pickleVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $pickleVM.showWorkoutBuilder) {
                PickleballWorkoutBuilderView(pickleVM: pickleVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $pickleVM.showMatchDetail) {
                if let match = pickleVM.selectedMatch {
                    PickleballMatchDetailView(match: match)
                }
            }
            .sheet(isPresented: $maVM.showSessionLog) {
                MartialArtsSessionLogSheet(maVM: maVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $maVM.showDrillLibrary) {
                MartialArtsDrillLibraryView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $maVM.showSettings) {
                MartialArtsSettingsView(maVM: maVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $maVM.showWorkoutBuilder) {
                MartialArtsWorkoutBuilderView(maVM: maVM)
                    .presentationDetents([.large])
            }
            .navigationDestination(isPresented: $maVM.showSessionDetail) {
                if let session = maVM.selectedSession {
                    MartialArtsSessionDetailView(session: session)
                }
            }
    }
}

extension View {
    func trainBasketballSheets(bbVM: BasketballViewModel) -> some View {
        modifier(TrainViewBasketballSheets(bbVM: bbVM))
    }

    func trainRunCyclingSwimSheets(
        runVM: RunningViewModel,
        cyclingVM: CyclingViewModel,
        swimVM: SwimmingViewModel,
        showLiveRun: Binding<Bool>,
        showLiveRide: Binding<Bool>
    ) -> some View {
        modifier(TrainViewRunCyclingSwimSheets(
            runVM: runVM,
            cyclingVM: cyclingVM,
            swimVM: swimVM,
            showLiveRun: showLiveRun,
            showLiveRide: showLiveRide
        ))
    }

    func trainSoccerTennisSheets(
        soccerVM: SoccerViewModel,
        tennisVM: TennisViewModel
    ) -> some View {
        modifier(TrainViewSoccerTennisSheets(soccerVM: soccerVM, tennisVM: tennisVM))
    }

    func trainVolleyPickleMASheets(
        volleyballVM: VolleyballViewModel,
        pickleVM: PickleballViewModel,
        maVM: MartialArtsViewModel
    ) -> some View {
        modifier(TrainViewVolleyPickleMASheets(
            volleyballVM: volleyballVM,
            pickleVM: pickleVM,
            maVM: maVM
        ))
    }
}
