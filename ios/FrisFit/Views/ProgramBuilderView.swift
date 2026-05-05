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
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentBuilderStep)

                bottomBar
            }
            .appBackground()
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { step in
                Capsule()
                    .fill(step <= viewModel.currentBuilderStep ? PepTheme.teal : PepTheme.elevated)
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
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }

            Button {
                if viewModel.currentBuilderStep == 0 {
                    viewModel.initializeDays()
                    withAnimation { viewModel.currentBuilderStep += 1 }
                } else {
                    viewModel.createProgram()
                    dismiss()
                    NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
                }
            } label: {
                Text(viewModel.currentBuilderStep == 1 ? "Start Program" : "Continue")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(nextButtonEnabled ? PepTheme.teal : PepTheme.teal.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(!nextButtonEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            PepTheme.cardSurface
                .overlay(alignment: .top) {
                    Rectangle().fill(PepTheme.glassBorderTop).frame(height: 0.5)
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
