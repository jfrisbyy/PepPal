import SwiftUI
import Combine

struct ProtocolDetailView: View {
    @State private var viewModel: ProtocolDetailViewModel
    @State private var unitStore = UnitPreferenceStore.shared
    @State private var focusedCompoundName: String
    @State private var homeViewModel = HomeViewModel()
    @State private var todaysPlanVM = TodaysPlanViewModel.shared
    @State private var editingBatchCompound: ProtocolCompound? = nil
    @State private var showTitrationBuilder: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var nowTick: Date = Date()
    @State private var compareCyclesPayload: CompareCyclesPayload?
    @State private var isLoadingCompare: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let countdownTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(protocolData: PeptideProtocol, initialCompoundName: String? = nil) {
        _viewModel = State(initialValue: ProtocolDetailViewModel(protocolData: protocolData))
        let resolved = initialCompoundName
            ?? protocolData.compounds.first?.compoundName
            ?? ""
        _focusedCompoundName = State(initialValue: resolved)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                protocolHeader
                if !viewModel.protocolData.compounds.isEmpty {
                    ProtocolPharmacologyHero(
                        protocolData: viewModel.protocolData,
                        focusedCompoundName: $focusedCompoundName,
                        onDoseTapped: { dose, compoundName in
                            if let entry = viewModel.protocolData.doseLog.first(where: {
                                $0.compoundName == compoundName &&
                                !$0.wasSkipped &&
                                abs($0.timestamp.timeIntervalSince(dose.time)) < 1
                            }) {
                                viewModel.editingDose = entry
                            }
                        }
                    )
                    if let insight = protocolInsight {
                        AIInsightStrip(content: insight, color: PepTheme.teal)
                    }
                }
                MedicalDisclaimerBanner(compact: true)
                proactiveInsightsSection
                interactionsSection
                nextDoseAction
                cycleTimelineSection
                doseLogSection
                if viewModel.hasInjectableCompound {
                    injectionSiteSection
                }
                reconstitutionSection
                sideEffectSection

                if viewModel.isWeightLoss {
                    titrationSection
                    weightLossTrackingSection
                } else if viewModel.currentTitrationSchedule != nil {
                    titrationSection
                }
                if viewModel.isHealing {
                    healingTrackingSection
                }
                if viewModel.isMuscleGrowth {
                    muscleGrowthTrackingSection
                }
                if viewModel.isCognitive {
                    cognitiveTrackingSection
                }
                if viewModel.isTanning {
                    tanningTrackingSection
                }

                supplySection
                vialsSection
                sideEffectTrendSection
                batchInfoSection
                supplementStackSection
                notesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, newValue in
            scrollOffset = newValue
        }
        .appBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            floatingBackButton
                .padding(.top, 6)
                .padding(.leading, 14)
                .opacity(floatingChromeOpacity)
                .scaleEffect(floatingChromeScale, anchor: .topLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: floatingChromeScale)
                .animation(.easeOut(duration: 0.18), value: floatingChromeOpacity)
        }
        .overlay(alignment: .topTrailing) {
            floatingMenuButton
                .padding(.top, 6)
                .padding(.trailing, 14)
                .opacity(floatingChromeOpacity)
                .scaleEffect(floatingChromeScale, anchor: .topTrailing)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: floatingChromeScale)
                .animation(.easeOut(duration: 0.18), value: floatingChromeOpacity)
        }
        .onReceive(countdownTimer) { date in
            nowTick = date
        }
        .alert("Archive Protocol?", isPresented: $viewModel.showArchiveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Archive") {
                viewModel.archiveProtocol()
                dismiss()
            }
        } message: {
            Text("This protocol will be marked as inactive. You can reactivate it anytime from Protocol History.")
        }
        .alert("Delete Protocol?", isPresented: $viewModel.showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteProtocol()
            }
        } message: {
            Text("This will permanently remove this protocol and all associated data. This action cannot be undone.")
        }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
        .sheet(isPresented: $viewModel.showLogDoseSheet) {
            LogDoseSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showSideEffectSheet) {
            LogSideEffectSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showAddSupplementSheet) {
            AddSupplementSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showAddNoteSheet) {
            AddNoteSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showReconCalculator) {
            ReconstitutionCalculatorView()
        }
        .sheet(isPresented: $viewModel.showSkipDoseSheet) {
            SkipDoseSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showCostSheet) {
            CostTrackingSheet(protocolData: viewModel.protocolData)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.exportURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(item: $viewModel.editingDose) { dose in
            EditDoseSheet(viewModel: viewModel, dose: dose)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingBatchCompound) { compound in
            EditCompoundBatchSheet(compound: compound) { vendor, batch, manufacture, expiration in
                homeViewModel.updateCompoundBatch(
                    protocolId: viewModel.protocolData.id,
                    compoundId: compound.id,
                    vendorName: vendor,
                    batchNumber: batch,
                    manufactureDate: manufacture,
                    expirationDate: expiration
                )
                if let idx = viewModel.protocolData.compounds.firstIndex(where: { $0.id == compound.id }) {
                    var updated = viewModel.protocolData.compounds[idx]
                    updated.vendorName = vendor
                    updated.batchNumber = batch
                    updated.manufactureDate = manufacture
                    updated.expirationDate = expiration
                    viewModel.protocolData.compounds[idx] = updated
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTitrationBuilder) {
            TitrationBuilderView(
                protocolId: viewModel.protocolData.id,
                compoundName: viewModel.protocolData.compounds.first?.compoundName ?? viewModel.protocolData.name,
                existing: viewModel.currentTitrationSchedule
            ) { schedule in
                viewModel.saveTitrationSchedule(schedule)
            }
        }
        .onAppear {
            viewModel.refreshFromSupabase()
        }
        .navigationDestination(item: $compareCyclesPayload) { payload in
            CycleComparisonView(cycles: payload.cycles)
        }
    }

    /// Loads all protocols from the user's history (or demo bundle) and pushes
    /// the comparison view pre-loaded with this cycle.
    private func openCycleCompare() async {
        guard !isLoadingCompare else { return }
        isLoadingCompare = true
        defer { isLoadingCompare = false }
        let all = (try? await ProtocolService.shared.fetchProtocols()) ?? []
        var combined = all
        if !combined.contains(where: { $0.id == viewModel.protocolData.id }) {
            combined.insert(viewModel.protocolData, at: 0)
        }
        let ordered: [PeptideProtocol] = {
            // Current cycle first, then everything else by most-recent start.
            let current = combined.first(where: { $0.id == viewModel.protocolData.id })
            let others = combined.filter { $0.id != viewModel.protocolData.id }
                .sorted { $0.startDate > $1.startDate }
            return [current].compactMap { $0 } + others
        }()
        compareCyclesPayload = CompareCyclesPayload(cycles: ordered)
    }

    private var vialsSection: some View {
        ProtocolVialsSection(protocolData: viewModel.protocolData)
    }

    /// Per-protocol editorial insight shown beneath the pharmacology chart.
    /// Filters the global protocol module to lines that mention this protocol's
    /// compounds (or the protocol name) so each detail view shows its own take.
    private var protocolInsight: String? {
        guard let raw = todaysPlanVM.moduleContent(for: "protocol"), !raw.isEmpty else { return nil }
        let compoundNames = viewModel.protocolData.compounds.map { $0.compoundName }
        let protocolName = viewModel.protocolData.name
        let needles = (compoundNames + [protocolName]).filter { !$0.isEmpty }
        guard !needles.isEmpty else { return raw }

        // Split into sentences and keep ones that reference this protocol/compounds.
        let sentences = raw
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let matched = sentences.filter { sentence in
            needles.contains { sentence.localizedCaseInsensitiveContains($0) }
        }
        let scoped = matched.isEmpty ? sentences : matched
        let joined = scoped.prefix(3).joined(separator: ". ")
        return joined.isEmpty ? raw : joined + "."
    }

    private var proactiveInsightsSection: some View {
        Group {
            if !viewModel.proactiveInsights.isEmpty {
                ProactiveInsightsBanner(insights: viewModel.proactiveInsights)
            }
        }
    }

    private var interactionsSection: some View {
        Group {
            if !viewModel.drugInteractions.isEmpty {
                CollapsibleEditorialSection(
                    eyebrow: "Compound Interactions",
                    meta: "Watch",
                    storageKey: "protocol.interactions"
                ) {
                    InteractionWarningsView(interactions: viewModel.drugInteractions)
                }
            }
        }
    }

    // MARK: - Protocol Header (editorial)

    private var protocolHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.protocolData.goal.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(viewModel.protocolData.goal.color.opacity(0.9))
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.45))
                Text("DAY \(viewModel.protocolData.currentDay)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }

            Text(viewModel.protocolData.name)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)

            LinearGradient(
                colors: [
                    PepTheme.textPrimary.opacity(0.18),
                    PepTheme.textPrimary.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)

            HStack(alignment: .center, spacing: 12) {
                headerStat(label: "Phase", value: viewModel.protocolData.currentPhase.rawValue.uppercased())
                headerDivider
                headerStat(label: "Next Dose", value: nextDoseCountdownText, isNumeric: false, monospaced: true)
                headerDivider
                headerStat(label: "Logged", value: totalLoggedText, isNumeric: false, monospaced: true)
                headerDivider
                headerStat(label: "Compounds", value: "\(viewModel.protocolData.compounds.count)", isNumeric: true)
                headerDivider
                headerStat(label: "Doses", value: "\(viewModel.protocolData.doseLog.filter { !$0.wasSkipped }.count)", isNumeric: true)
            }
        }
        .padding(.vertical, 6)
        .padding(.top, 40) // Leave room for floating back/menu buttons.
    }

    // MARK: - Floating Top Buttons

    private var floatingBackButton: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(PepTheme.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.6))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: false)
    }

    private var floatingMenuButton: some View {
        Menu {
            Button { viewModel.showReconCalculator = true } label: {
                Label("Reconstitution Calculator", systemImage: "function")
            }

            Button { viewModel.showCostSheet = true } label: {
                Label("Cost Tracking", systemImage: "dollarsign.circle")
            }

            Button { viewModel.exportCSV() } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }

            Button { Task { await openCycleCompare() } } label: {
                Label("Compare to past cycle", systemImage: "chart.line.uptrend.xyaxis")
            }

            Menu {
                ForEach(viewModel.protocolData.compounds, id: \.compoundName) { compound in
                    Picker(compound.compoundName, selection: Binding(
                        get: { unitStore.effectiveUnit(for: compound.compoundName) },
                        set: { unitStore.setUnit($0, for: compound.compoundName) }
                    )) {
                        Text("mcg").tag(CompoundUnit.mcg)
                        Text("mg").tag(CompoundUnit.mg)
                    }
                }
            } label: {
                Label("Display Units", systemImage: "ruler")
            }

            if viewModel.protocolData.isActive {
                Button {
                    viewModel.showArchiveConfirm = true
                } label: {
                    Label("Archive Protocol", systemImage: "archivebox")
                }
            } else {
                Button {
                    viewModel.reactivateProtocol()
                } label: {
                    Label("Reactivate Protocol", systemImage: "play.circle")
                }
            }

            Button(role: .destructive) {
                viewModel.showDeleteConfirm = true
            } label: {
                Label("Delete Protocol", systemImage: "trash")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(PepTheme.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.6))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
    }

    private var floatingChromeScale: CGFloat {
        let progress = min(max(scrollOffset / 80, 0), 1)
        return 1.0 - 0.10 * progress
    }

    private var floatingChromeOpacity: Double {
        let progress = min(max(Double(scrollOffset) / 80, 0), 1)
        return 1.0 - 0.35 * progress
    }

    // MARK: - Header Stat Helpers

    /// Friendly countdown to the next dose (e.g. "in 3h 20m" / "Now" / "—").
    private var nextDoseCountdownText: String {
        _ = nowTick // re-evaluate on tick
        guard let next = viewModel.smartNextDose ?? viewModel.protocolData.nextDose else { return "—" }
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let comps = cal.dateComponents([.hour, .minute], from: next.timeOfDay)
        guard let scheduled = cal.date(bySettingHour: comps.hour ?? 8, minute: comps.minute ?? 0, second: 0, of: today) else {
            return "—"
        }
        let target = scheduled < now ? scheduled.addingTimeInterval(86_400) : scheduled
        let interval = target.timeIntervalSince(now)
        if interval <= 60 { return "Now" }
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours <= 0 { return "\(minutes)m" }
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d"
        }
        return "\(hours)h \(minutes)m"
    }

    /// Cumulative non-skipped dose total across the cycle, formatted in the
    /// dominant compound's preferred unit.
    private var totalLoggedText: String {
        let logged = viewModel.protocolData.doseLog.filter { !$0.wasSkipped }
        guard !logged.isEmpty else { return "0" }
        // Group by compound, render the single biggest contributor's total in
        // its own preferred unit so the header stays compact and meaningful.
        let totals = Dictionary(grouping: logged, by: { $0.compoundName })
            .mapValues { $0.reduce(0.0) { $0 + $1.doseMcg } }
        guard let top = totals.max(by: { $0.value < $1.value }) else { return "0" }
        return CompoundUnitHelper.displayDoseShort(top.value, for: top.key)
    }

    private var headerDivider: some View {
        Rectangle()
            .fill(PepTheme.textPrimary.opacity(0.08))
            .frame(width: 0.5, height: 28)
    }

    private func headerStat(label: String, value: String, isNumeric: Bool = false, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(
                    isNumeric
                        ? .system(.title3, design: .serif, weight: .semibold)
                        : (monospaced
                           ? .system(size: 13, weight: .semibold, design: .monospaced)
                           : .system(size: 11, weight: .semibold))
                )
                .tracking(isNumeric || monospaced ? 0 : 1.4)
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary.opacity(0.85))
        }
        .frame(minWidth: 0)
    }

    // MARK: - Next Dose Action

    private var nextDoseAction: some View {
        Group {
            if let nextDose = viewModel.smartNextDose ?? viewModel.protocolData.nextDose {
                HStack(spacing: 10) {
                    Button { viewModel.showLogDoseSheet = true } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(PepTheme.teal.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "syringe.fill")
                                    .font(.title3)
                                    .foregroundStyle(PepTheme.teal)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Log Next Dose")
                                    .font(.system(.headline, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("\(CompoundUnitHelper.displayDoseShort(nextDose.doseMcg, for: nextDose.compoundName)) \(nextDose.compoundName)")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.08), PepTheme.teal.opacity(0.03)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .overlay(PepTheme.cardSurface.opacity(0.85))
                        )
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(PepTheme.teal.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.scale)
                    .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.showLogDoseSheet)

                    Button { viewModel.showSkipDoseSheet = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(PepTheme.amber)
                            Text("Skip")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .frame(width: 60, height: 80)
                        .background(PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(PepTheme.amber.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.scale)
                }
            }
        }
    }

    private var adherenceRing: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: viewModel.overallAdherence)
                    .stroke(viewModel.adherenceColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(viewModel.overallAdherence * 100))%")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(viewModel.adherenceColor)
            }
            Text("Adherence")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    // MARK: - Cycle Timeline

    private var cycleTimelineSection: some View {
        Group {
            if viewModel.protocolData.hasPhases || viewModel.protocolData.totalWeeks != nil {
                CollapsibleEditorialSection(
                    eyebrow: "Cycle Timeline",
                    storageKey: "protocol.timeline"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 4) {
                            Text("Day \(viewModel.protocolData.currentDay)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            if let tw = viewModel.protocolData.totalWeeks {
                                Text("of \(tw * 7)")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            } else {
                                Text("\u{2014} Ongoing")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            if viewModel.protocolData.totalWeeks != nil {
                                Text("\(Int(viewModel.cycleProgressFraction * 100))% complete")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(PepTheme.teal)
                            }
                        }

                        if viewModel.protocolData.hasPhases {
                            phaseProgressBar
                            phaseLabels
                        }
                    }
                }
            }
        }
    }

    private var phaseProgressBar: some View {
        let proto = viewModel.protocolData
        let lw = proto.loadingWeeks ?? 0
        let mw = proto.maintenanceWeeks ?? 0
        let tw = proto.taperingWeeks ?? 0
        let ow = proto.offCycleWeeks ?? 0
        let total = max(1, lw + mw + tw + ow)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    if lw > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.loading.color.opacity(0.3))
                            .frame(width: geo.size.width * CGFloat(lw) / CGFloat(total))
                    }
                    if mw > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.maintenance.color.opacity(0.3))
                            .frame(width: geo.size.width * CGFloat(mw) / CGFloat(total))
                    }
                    if tw > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.tapering.color.opacity(0.3))
                            .frame(width: geo.size.width * CGFloat(tw) / CGFloat(total))
                    }
                    if ow > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CyclePhase.offCycle.color.opacity(0.3))
                            .frame(width: geo.size.width * CGFloat(ow) / CGFloat(total))
                    }
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(viewModel.protocolData.currentPhase.color)
                    .frame(width: max(4, geo.size.width * viewModel.cycleProgressFraction), height: 10)

                Circle()
                    .fill(viewModel.protocolData.currentPhase.color)
                    .frame(width: 14, height: 14)
                    .shadow(color: viewModel.protocolData.currentPhase.color.opacity(0.5), radius: 4)
                    .offset(x: max(0, geo.size.width * viewModel.cycleProgressFraction - 7))
            }
        }
        .frame(height: 14)
    }

    private var phaseLabels: some View {
        HStack(spacing: 6) {
            ForEach([
                (CyclePhase.loading, viewModel.protocolData.loadingWeeks ?? 0),
                (CyclePhase.maintenance, viewModel.protocolData.maintenanceWeeks ?? 0),
                (CyclePhase.tapering, viewModel.protocolData.taperingWeeks ?? 0),
                (CyclePhase.offCycle, viewModel.protocolData.offCycleWeeks ?? 0),
            ], id: \.0) { phase, weeks in
                if weeks > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(phase.color)
                            .frame(width: 6, height: 6)
                        Text("\(phase.rawValue) \(weeks)w")
                            .font(.system(size: 10, weight: viewModel.protocolData.currentPhase == phase ? .bold : .medium))
                            .foregroundStyle(viewModel.protocolData.currentPhase == phase ? PepTheme.textPrimary : PepTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Dose Log Section

    private var doseLogSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Dose History",
            storageKey: "protocol.doseLog",
            trailingAction: {
                Button { viewModel.showLogDoseSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(PepTheme.textPrimary.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        ) {
            if viewModel.sortedDoseLog.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "syringe")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        Text("No doses logged yet")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.sortedDoseLog.prefix(10).enumerated()), id: \.element.id) { index, dose in
                        Button {
                            viewModel.editingDose = dose
                        } label: {
                            doseLogRow(dose)
                        }
                        .buttonStyle(.plain)
                        if index < min(viewModel.sortedDoseLog.count, 10) - 1 {
                            Divider().overlay(PepTheme.separatorColor).padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    private func doseLogRow(_ dose: DoseLogEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PepTheme.teal.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.teal)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(CompoundUnitHelper.displayDoseShort(dose.doseMcg, for: dose.compoundName)) \(dose.compoundName)")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(dose.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("·")
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(dose.injectionSite.shortName)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                if !dose.notes.isEmpty {
                    Text(dose.notes)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Injection Site Rotation

    private var injectionSiteSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Injection Site Rotation",
            storageKey: "protocol.sites"
        ) {
            VStack(spacing: 14) {
                InjectionBodyMapView(viewModel: viewModel)

                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(PepTheme.teal)
                    Text("Next suggested: **\(viewModel.suggestedNextSite.rawValue)**")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.teal.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))

                HStack(spacing: 12) {
                    legendDot(color: .green, label: "Rotated")
                    legendDot(color: .yellow, label: "Recent")
                    legendDot(color: .red, label: "Overused")
                    legendDot(color: .gray.opacity(0.3), label: "Unused")
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(PepTheme.textSecondary)
        }
    }

    // MARK: - Reconstitution Section

    private var reconstitutionSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Reconstitution Calculator",
            storageKey: "protocol.recon",
            defaultExpanded: false
        ) {
            VStack(spacing: 12) {
                reconInput(label: "Vial Size", placeholder: "5", unit: "mg", text: $viewModel.reconPeptideMg, icon: "pill.fill", color: PepTheme.teal)
                reconInput(label: "BAC Water", placeholder: "2", unit: "mL", text: $viewModel.reconWaterMl, icon: "drop.fill", color: PepTheme.blue)
                reconInput(label: "Desired Dose", placeholder: "250", unit: "mcg", text: $viewModel.reconDesiredMcg, icon: "syringe.fill", color: .orange)

                if let conc = viewModel.reconConcentration {
                    VStack(spacing: 8) {
                        reconResult(label: "Concentration", value: String(format: "%.0f mcg/mL", conc), color: PepTheme.teal)
                        if let units = viewModel.reconUnits {
                            reconResult(label: "Draw", value: String(format: "%.1f units", units), color: .orange)
                        }
                    }
                    .padding(12)
                    .background(PepTheme.teal.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.reconConcentration != nil)
        }
    }

    private func reconInput(label: String, placeholder: String, unit: String, text: Binding<String>, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(width: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func reconResult(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Side Effect Section

    private var sideEffectSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Side Effects",
            storageKey: "protocol.sideEffects",
            trailingAction: {
                Button { viewModel.showSideEffectSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(PepTheme.textPrimary.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        ) {
            if viewModel.protocolData.sideEffectLog.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        Text("No side effects logged")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.protocolData.sideEffectLog.prefix(5)) { entry in
                        HStack(spacing: 10) {
                            severityIndicator(entry.severity)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.effect)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(entry.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Spacer()
                            Text(severityLabel(entry.severity))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(severityColor(entry.severity))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(severityColor(entry.severity).opacity(0.12))
                                .clipShape(.capsule)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func severityIndicator(_ severity: Int) -> some View {
        Circle()
            .fill(severityColor(severity))
            .frame(width: 10, height: 10)
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }

    private func severityLabel(_ severity: Int) -> String {
        switch severity {
        case 1: return "Mild"
        case 2: return "Moderate"
        case 3: return "Significant"
        default: return "Severe"
        }
    }

    // MARK: - Titration Section (Weight Loss)

    private var titrationSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Titration Schedule",
            storageKey: "protocol.titration",
            trailingAction: {
                Button {
                    showTitrationBuilder = true
                } label: {
                    Text(viewModel.currentTitrationSchedule == nil && !viewModel.titrationSteps.isEmpty ? "CUSTOMIZE" : "EDIT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.teal)
                }
                .buttonStyle(.plain)
            }
        ) {
            VStack(spacing: 0) {
                if viewModel.titrationSteps.isEmpty {
                    Button {
                        showTitrationBuilder = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16, weight: .medium))
                            Text("Add titration plan")
                                .font(.system(.subheadline, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(PepTheme.teal)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(Array(viewModel.titrationSteps.enumerated()), id: \.element.id) { index, step in
                    Button { viewModel.toggleTitrationStep(step) } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(step.isCompleted ? .green : PepTheme.elevated)
                                .frame(width: 28, height: 28)
                            if step.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Week \(step.weekNumber)")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(step.label)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        Text(CompoundUnitHelper.displayDoseShort(step.doseMcg, for: viewModel.protocolData.compounds.first?.compoundName ?? ""))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(step.isCompleted ? .green : PepTheme.textSecondary)
                    }
                    .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: step.isCompleted)

                    if index < viewModel.titrationSteps.count - 1 {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(step.isCompleted ? .green.opacity(0.3) : PepTheme.elevated)
                                .frame(width: 2, height: 16)
                                .padding(.leading, 13)
                            Spacer()
                        }
                    }
                }
                .onTapGesture {}
                .contentShape(.rect)
            }
        }
    }

    // MARK: - Weight Loss Tracking

    private var weightLossTrackingSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Weight Loss Tracking",
            storageKey: "protocol.weightLoss"
        ) {
            VStack(spacing: 14) {
                DailyRatingRow(label: "Appetite", icon: "fork.knife", category: "appetite", viewModel: viewModel)
                DailyRatingRow(label: "Food Noise", icon: "brain.head.profile", category: "foodNoise", viewModel: viewModel)
                DailyRatingRow(label: "GI Comfort", icon: "stomach", category: "giComfort", viewModel: viewModel)
            }
        }
    }

    // MARK: - Healing Tracking

    private var healingTrackingSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Recovery Tracking",
            storageKey: "protocol.healing"
        ) {
            VStack(spacing: 14) {
                DailyRatingRow(label: "Pain Level", icon: "bolt.fill", category: "pain", viewModel: viewModel)
                DailyRatingRow(label: "Mobility", icon: "figure.walk", category: "mobility", viewModel: viewModel)
                DailyRatingRow(label: "Training Readiness", icon: "figure.run", category: "trainingReadiness", viewModel: viewModel)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recovery Milestones")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)

                    ForEach(viewModel.recoveryMilestones) { milestone in
                        Button { viewModel.toggleMilestone(milestone) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: milestone.isAchieved ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(milestone.isAchieved ? .green : PepTheme.textSecondary)
                                Text(milestone.title)
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(milestone.isAchieved ? PepTheme.textSecondary : PepTheme.textPrimary)
                                    .strikethrough(milestone.isAchieved)
                                Spacer()
                            }
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: milestone.isAchieved)
                    }
                }
            }
        }
    }

    // MARK: - Muscle Growth Tracking

    private var muscleGrowthTrackingSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Muscle & GH Tracking",
            storageKey: "protocol.muscle"
        ) {
            VStack(spacing: 14) {
                DailyRatingRow(label: "Sleep Quality", icon: "moon.fill", category: "sleepQuality", viewModel: viewModel)
                DailyRatingRow(label: "Water Retention", icon: "drop.fill", category: "waterRetention", viewModel: viewModel)

                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(PepTheme.teal)
                    Text("Track body measurements and IGF-1 levels in your bloodwork section")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(10)
                .background(PepTheme.teal.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Cognitive Tracking

    private var cognitiveTrackingSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Cognitive Tracking",
            storageKey: "protocol.cognitive"
        ) {
            VStack(spacing: 14) {
                DailyRatingRow(label: "Focus", icon: "scope", category: "focus", viewModel: viewModel)
                DailyRatingRow(label: "Mental Clarity", icon: "sparkle", category: "clarity", viewModel: viewModel)
                DailyRatingRow(label: "Anxiety", icon: "waveform.path.ecg", category: "anxiety", viewModel: viewModel)
                DailyRatingRow(label: "Motivation", icon: "bolt.fill", category: "motivation", viewModel: viewModel)
                DailyRatingRow(label: "Mood", icon: "face.smiling", category: "mood", viewModel: viewModel)
            }
        }
    }

    // MARK: - Tanning Tracking

    private var tanningTrackingSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Tanning & Cosmetic",
            storageKey: "protocol.tanning"
        ) {
            VStack(spacing: 14) {
                DailyRatingRow(label: "Nausea", icon: "stomach", category: "tanNausea", viewModel: viewModel)
                DailyRatingRow(label: "Flushing", icon: "thermometer.high", category: "flushing", viewModel: viewModel)

                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(PepTheme.amber)
                    Text("Monitor moles and freckles for any changes. Take weekly comparison photos under consistent lighting.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .lineSpacing(2)
                }
                .padding(10)
                .background(PepTheme.amber.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Supply & Side Effect Trend

    private var supplySection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Supply Tracker",
            storageKey: "protocol.supply"
        ) {
            VStack(spacing: 10) {
                ForEach(viewModel.protocolData.compounds) { compound in
                    let s = viewModel.supplyEstimate(for: compound)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(compound.compoundName)
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            if let days = s.daysUntilExpiration {
                                HStack(spacing: 4) {
                                    Image(systemName: days < 30 ? "exclamationmark.triangle.fill" : "clock")
                                        .font(.system(size: 10))
                                    Text(days < 0 ? "Expired" : "\(days)d left")
                                        .font(.system(.caption2, design: .rounded, weight: .bold))
                                }
                                .foregroundStyle(days < 30 ? .red : PepTheme.textSecondary)
                            }
                        }

                        if let mg = s.mgRemaining, let vial = s.vialSizeMg, vial > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(format: "%.2f mg remaining", mg))
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Spacer()
                                    if let doses = s.dosesRemaining {
                                        Text("~\(doses) doses left")
                                            .font(.system(.caption, weight: .semibold))
                                            .foregroundStyle(doses < 3 ? .red : PepTheme.teal)
                                    }
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(PepTheme.elevated).frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(mg / vial < 0.2 ? Color.red : PepTheme.teal)
                                            .frame(width: geo.size.width * CGFloat(max(0, min(1, mg / vial))), height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }
                        } else {
                            Text("Set vial size in compound info to track supply")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private var sideEffectTrendSection: some View {
        Group {
            if viewModel.sideEffectTrend.count >= 2 {
                CollapsibleEditorialSection(
                    eyebrow: "Side Effect Trend",
                    storageKey: "protocol.sideEffectTrend"
                ) {
                    SideEffectTrendChart(points: viewModel.sideEffectTrend)
                        .frame(height: 140)
                }
            }
        }
    }

    // MARK: - Batch Info

    private var batchInfoSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Batch & Source",
            storageKey: "protocol.batch",
            defaultExpanded: false
        ) {
            VStack(spacing: 10) {
                ForEach(viewModel.protocolData.compounds) { compound in
                    Button {
                        editingBatchCompound = compound
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(compound.compoundName)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(hasBatchInfo(compound) ? "Edit" : "Add")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(PepTheme.teal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PepTheme.teal.opacity(0.12))
                                .clipShape(.capsule)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                batchDetail(label: "Vendor", value: compound.vendorName ?? "Not set")
                                batchDetail(label: "Batch #", value: compound.batchNumber ?? "Not set")
                                batchDetail(label: "Manufactured", value: compound.manufactureDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not set")
                                batchDetail(label: "Expiration", value: compound.expirationDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not set")
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: editingBatchCompound?.id == compound.id)
                }
            }
        }
    }

    private func hasBatchInfo(_ compound: ProtocolCompound) -> Bool {
        compound.vendorName != nil || compound.batchNumber != nil || compound.manufactureDate != nil || compound.expirationDate != nil
    }

    private func batchDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Text(value)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Supplement Stack

    private var supplementStackSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Supplement Stack",
            storageKey: "protocol.supplements",
            trailingAction: {
                Button { viewModel.showAddSupplementSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(PepTheme.textPrimary.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        ) {
            if viewModel.protocolData.supplements.isEmpty {
                HStack {
                    Spacer()
                    Text("No supplements added")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.protocolData.supplements) { supplement in
                        HStack(spacing: 10) {
                            Image(systemName: "pill.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                            Text(supplement.name)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            if !supplement.dose.isEmpty {
                                Text(supplement.dose)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                            Text(supplement.frequency)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        CollapsibleEditorialSection(
            eyebrow: "Notes",
            storageKey: "protocol.notes",
            trailingAction: {
                Button { viewModel.showAddNoteSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(PepTheme.textPrimary.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        ) {
            if viewModel.notes.isEmpty {
                HStack {
                    Spacer()
                    Text("No notes yet")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.notes.prefix(5)) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.timestamp, style: .date)
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text(note.text)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }
}
