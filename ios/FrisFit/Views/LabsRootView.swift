import SwiftUI

/// Thin root container for the Labs domain. Hosts body composition, sleep,
/// and the Apple Health section relocated from the old Home dashboard.
struct LabsRootView: View {
    @State private var viewModel = HomeViewModel()
    @State private var bodyGoalViewModel = BodyGoalViewModel()
    @State private var didLoad: Bool = false

    var body: some View {
        Group {
            ScrollView {
                VStack(spacing: 0) {
                    CollapsibleEditorialSection(eyebrow: "01 \u{2014} Composition", storageKey: "labsComposition") {
                        VStack(spacing: 16) {
                            BodyGoalSectionView(viewModel: bodyGoalViewModel)
                        }
                    }
                    .padding(.bottom, 40)

                    CollapsibleEditorialSection(eyebrow: "02 \u{2014} Sleep", storageKey: "labsSleep") {
                        VStack(spacing: 16) {
                            HomeSleepCard(healthKit: viewModel.healthKit)
                        }
                    }
                    .padding(.bottom, 40)

                    if viewModel.healthKit.isAuthorized {
                        CollapsibleEditorialSection(eyebrow: "03 \u{2014} Apple Health", storageKey: "labsAppleHealth") {
                            VStack(spacing: 14) {
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
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if !didLoad {
                    didLoad = true
                    viewModel.onAppear()
                    bodyGoalViewModel.loadData()
                }
            }
        }
    }
}
