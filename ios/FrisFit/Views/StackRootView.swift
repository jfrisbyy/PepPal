import SwiftUI

/// Thin root container for the Stack domain. Hosts the existing protocol /
/// dosing section (and its add-vial + reconstitution flows) so the dosing
/// content lives in its own full-screen domain rather than on the Brief.
struct StackRootView: View {
    @State private var viewModel = HomeViewModel()
    @State private var todaysPlanVM = TodaysPlanViewModel.shared
    @State private var showProtocolWizard: Bool = false
    @State private var showReconCalculator: Bool = false
    @State private var didLoad: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    EptiLogoMark(size: 38)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    CollapsibleEditorialSection(eyebrow: "01 \u{2014} Protocols", storageKey: "stackProtocols") {
                        ProtocolSectionView(
                            viewModel: viewModel,
                            todaysPlanVM: todaysPlanVM,
                            showProtocolWizard: $showProtocolWizard
                        )
                    }
                }
                .monospacedDigit()
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            .appBackground(accent: PepTheme.tealDeep)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProtocolWizard) {
                AddVialFlowView { proto in
                    viewModel.saveProtocolToSupabase(proto)
                }
            }
            .sheet(isPresented: $showReconCalculator) {
                ReconstitutionCalculatorView()
            }
            .onAppear {
                if !didLoad {
                    didLoad = true
                    viewModel.loadProtocolsFromSupabase()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .supabaseDataChanged)) { _ in
                viewModel.loadProtocolsFromSupabase()
            }
        }
    }
}
