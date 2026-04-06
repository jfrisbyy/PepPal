import SwiftUI

struct ProgramBuilderView: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator

                TabView(selection: $viewModel.currentBuilderStep) {
                    ProgramSetupStep(viewModel: viewModel)
                        .tag(0)

                    ProgramScheduleStep(viewModel: viewModel)
                        .tag(1)

                    ProgramReviewStep(viewModel: viewModel, onComplete: {
                        viewModel.createProgram()
                        dismiss()
                    })
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentBuilderStep)

                bottomBar
            }
            .background(FrisTheme.background.ignoresSafeArea())
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { step in
                Capsule()
                    .fill(step <= viewModel.currentBuilderStep ? FrisTheme.cyan : FrisTheme.elevated)
                    .frame(height: 3)
                    .animation(.spring(duration: 0.3), value: viewModel.currentBuilderStep)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if viewModel.currentBuilderStep > 0 {
                Button {
                    withAnimation { viewModel.currentBuilderStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrisTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FrisTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

            Button {
                if viewModel.currentBuilderStep == 0 {
                    viewModel.initializeDays()
                }
                if viewModel.currentBuilderStep < 2 {
                    withAnimation { viewModel.currentBuilderStep += 1 }
                }
            } label: {
                Text(viewModel.currentBuilderStep == 2 ? "Start Program" : "Continue")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(viewModel.currentBuilderStep == 2 ? .black : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(nextButtonEnabled ? FrisTheme.cyan : FrisTheme.cyan.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(!nextButtonEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            FrisTheme.cardSurface
                .overlay(alignment: .top) {
                    Rectangle().fill(FrisTheme.glassBorderTop).frame(height: 0.5)
                }
        )
    }

    private var nextButtonEnabled: Bool {
        switch viewModel.currentBuilderStep {
        case 0: viewModel.canProceedFromSetup
        case 1: viewModel.canProceedFromSchedule
        default: true
        }
    }
}
