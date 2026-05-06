import SwiftUI

struct HomeTrainingCard: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var showProgramCreation: Bool
    var onStartWorkout: () -> Void

    @State private var isTrainingCollapsed: Bool = false
    @State private var showEditProgram: Bool = false
    @State private var editProgramTrainVM: TrainViewModel? = nil

    var body: some View {
        let hasProgram = viewModel.activeProgram != nil
        let hasRec = viewModel.trainingRecommendation != nil
        let showSection = hasProgram || hasRec

        Group {
            if showSection {
                VStack(spacing: 0) {
                    cardChrome
                    if !isTrainingCollapsed,
                       viewModel.isPlanExpanded,
                       !viewModel.todaysPlan.isRestDay,
                       viewModel.activeProgram != nil {
                        ExpandedPlanContentView(
                            viewModel: viewModel,
                            onStartWorkout: onStartWorkout
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
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
    }

    private var cardChrome: some View {
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
        .padding(.vertical, 2)
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
}
