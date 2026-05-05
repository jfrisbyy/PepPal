import SwiftUI

struct ProtocolSectionView: View {
    @Bindable var viewModel: HomeViewModel
    @Bindable var todaysPlanVM: TodaysPlanViewModel
    @Binding var showProtocolWizard: Bool

    @State private var expandedProtocolIds: Set<UUID> = []
    @State private var navDetailProto: ProtocolDetailNavTarget?
    @State private var navJourneyProto: PeptideProtocol?
    @State private var editSchedule: EditScheduleTarget?
    @State private var showManageAll: Bool = false
    @State private var confirmArchive: PeptideProtocol?
    @State private var confirmDelete: PeptideProtocol?
    @State private var showReconCalc: Bool = false
    @State private var reconInitialCompound: String? = nil
    @State private var reconInitialVialSizeMg: Double? = nil
    @State private var showStackBuilder: Bool = false
    @State private var showTitrationPicker: Bool = false
    @State private var titrationTargetProto: PeptideProtocol? = nil
    @State private var titrationBuilder: TitrationBuilderContext? = nil
    @State private var showTrends: Bool = false
    @State private var trendsProto: PeptideProtocol? = nil
    @State private var showVialScanner: Bool = false
    @State private var showIntegrityCheck: Bool = false
    @State private var showAIChat: Bool = false
    @State private var scanHandoff: VialScanHandoff? = nil

    private func protocolMatching(compoundName: String) -> PeptideProtocol? {
        let active = protocols.first(where: { proto in
            proto.isActive && proto.compounds.contains(where: { $0.compoundName.localizedCaseInsensitiveCompare(compoundName) == .orderedSame })
        })
        if let active { return active }
        return protocols.first(where: { proto in
            proto.compounds.contains(where: { $0.compoundName.localizedCaseInsensitiveCompare(compoundName) == .orderedSame })
        })
    }

    private var protocols: [PeptideProtocol] {
        viewModel.allProtocols.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }
            return a.startDate > b.startDate
        }
    }

    var body: some View {
        Group {
            if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
                TrackAEmptyStateCard(
                    surface: .protocols,
                    title: "Protocols",
                    blurb: "A protocol is a structured plan for using a peptide — what compound, how much, how often, for how long. Tracking yours means you can see what works, what doesn't, and how your body responds.",
                    icon: "list.bullet.rectangle.fill"
                )
            } else if protocols.isEmpty {
                startProtocolCard
            } else {
                stackedProtocolsCard
            }
        }
        .navigationDestination(item: $navDetailProto) { target in
            ProtocolDetailView(
                protocolData: target.proto,
                initialCompoundName: target.compoundName
            )
        }
        .navigationDestination(item: $navJourneyProto) { proto in
            ProtocolJourneyView(protocolData: proto)
        }
        .sheet(item: $editSchedule) { target in
            EditCompoundScheduleSheet(
                protocolData: target.proto,
                compound: target.compound,
                onSave: { dose, frequency in
                    viewModel.updateCompoundSchedule(
                        protocolId: target.proto.id,
                        compoundId: target.compound.id,
                        doseMcg: dose,
                        frequency: frequency
                    )
                },
                onDelete: {
                    viewModel.removeCompound(
                        protocolId: target.proto.id,
                        compoundId: target.compound.id
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReconCalc) {
            ReconstitutionCalculatorView(
                initialCompound: reconInitialCompound,
                initialVialSizeMg: reconInitialVialSizeMg
            )
        }
        .sheet(isPresented: $showStackBuilder) {
            PeptideStackBuilderView()
        }
        .sheet(isPresented: $showTitrationPicker) {
            TitrationTemplatePickerView(
                compoundName: titrationTargetProto?.compounds.first?.compoundName,
                onSelectTemplate: { template in
                    if let proto = titrationTargetProto {
                        applyTemplate(template, to: proto)
                    }
                },
                onBuildCustom: {
                    if let proto = titrationTargetProto {
                        openBuilder(for: proto, seed: nil, existing: TitrationScheduleStore.shared.schedule(for: proto.id))
                    }
                }
            )
        }
        .sheet(item: $titrationBuilder) { ctx in
            TitrationBuilderView(
                protocolId: ctx.protocolId,
                compoundName: ctx.compoundName,
                existing: ctx.existing,
                seedFromTemplate: ctx.seed
            ) { schedule in
                viewModel.saveTitrationSchedule(schedule)
            }
        }
        .sheet(item: $trendsProto) { proto in
            NavigationStack { ProtocolTrendsView(protocolData: proto) }
        }
        .sheet(isPresented: $showIntegrityCheck) {
            VialIntegrityCheckView()
        }
        .sheet(isPresented: $showAIChat) {
            NavigationStack { PeptideAIChatView() }
        }
        .fullScreenCover(isPresented: $showVialScanner) {
            VialScannerView { scan, action in
                let prefill = VialScanPrefill(scan: scan)
                switch action {
                case .addToInventory:
                    scanHandoff = VialScanHandoff(kind: .inventory, prefill: prefill)
                case .reconstitute:
                    scanHandoff = VialScanHandoff(kind: .reconstitute, prefill: prefill)
                case .createProtocol:
                    scanHandoff = VialScanHandoff(kind: .protocolSetup, prefill: prefill)
                }
            }
        }
        .sheet(item: $scanHandoff) { handoff in
            switch handoff.kind {
            case .inventory:
                if let proto = protocolMatching(compoundName: handoff.prefill.compoundName) {
                    NavigationStack {
                        ProtocolDetailView(protocolData: proto, initialCompoundName: handoff.prefill.compoundName)
                    }
                } else {
                    ProtocolSetupWizardView(initialCompound: handoff.prefill.compoundName) { newProto in
                        viewModel.saveProtocolToSupabase(newProto)
                    }
                }
            case .reconstitute:
                ReconstitutionCalculatorView(
                    initialCompound: handoff.prefill.compoundName,
                    initialVialSizeMg: handoff.prefill.vialSizeMg
                )
            case .protocolSetup:
                ProtocolSetupWizardView(initialCompound: handoff.prefill.compoundName) { proto in
                    viewModel.saveProtocolToSupabase(proto)
                }
            }
        }
        .sheet(isPresented: $showManageAll) {
            ManageProtocolsSheet(
                viewModel: viewModel,
                onAddNew: {
                    showManageAll = false
                    showProtocolWizard = true
                },
                onOpen: { proto in
                    showManageAll = false
                    navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: nil)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Archive Protocol?", isPresented: Binding(
            get: { confirmArchive != nil },
            set: { if !$0 { confirmArchive = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmArchive = nil }
            Button("Archive") {
                if let p = confirmArchive { viewModel.archiveProtocolFromHome(p) }
                confirmArchive = nil
            }
        } message: {
            Text("This protocol will be marked as inactive. You can reactivate it anytime.")
        }
        .alert("Delete Protocol?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmDelete = nil }
            Button("Delete", role: .destructive) {
                if let p = confirmDelete { viewModel.deleteProtocolFromHome(p) }
                confirmDelete = nil
            }
        } message: {
            Text("This permanently removes the protocol and all its logs.")
        }
    }

    // MARK: - Stacked Protocols Card

    private var stackedProtocolsCard: some View {
        VStack(spacing: 10) {
            let lowStock = SupplyForecastService.lowStockForecasts(from: protocols)
            if !lowStock.isEmpty {
                LowStockBanner(forecasts: lowStock) {
                    if let firstLow = lowStock.first,
                       let proto = protocolMatching(compoundName: firstLow.compoundName) {
                        navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: firstLow.compoundName)
                    } else if let proto = protocols.first {
                        navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: nil)
                    }
                }
            }
            GlassCard(accent: PepTheme.teal) {
                VStack(alignment: .leading, spacing: 14) {
                    headerBar

                    protocolBriefLines

                    VStack(spacing: 0) {
                        ForEach(Array(protocols.enumerated()), id: \.element.id) { idx, proto in
                            if idx > 0 {
                                editorialDivider
                                    .padding(.vertical, 14)
                            }
                            protocolStackRow(proto)
                        }
                    }
                }
            }
        }
    }

    private var editorialDivider: some View {
        Rectangle()
            .fill(PepTheme.textSecondary.opacity(0.15))
            .frame(height: 0.5)
    }

    private func protocolStackRow(_ proto: PeptideProtocol) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            protocolStackHeader(proto)

            if proto.hasPhases {
                phaseProgressBar(proto)
                    .padding(.top, 2)
            }

            if !proto.compounds.isEmpty {
                VStack(spacing: 8) {
                    ForEach(proto.compounds) { compound in
                        compoundRow(proto: proto, compound: compound)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var protocolBriefLines: some View {
        let lines = MorningBriefService.shared.buildLines()
        VStack(spacing: 6) {
            if let dose = lines.dose {
                BriefLineRow(line: dose, icon: "pill.fill")
            }
            if let supply = lines.supply {
                BriefLineRow(line: supply, icon: "shippingbox.fill")
            }
            if let bw = lines.bloodwork {
                BriefLineRow(line: bw, icon: "drop.fill")
            }
        }
    }

    private var stackDivider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(height: 0.5)
    }

    private func protocolStackHeader(_ proto: PeptideProtocol) -> some View {
        Button {
            navDetailProto = ProtocolDetailNavTarget(
                proto: proto,
                compoundName: proto.compounds.first?.compoundName
            )
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(proto.name)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        if !proto.isActive {
                            Text("ENDED")
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(PepTheme.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(PepTheme.elevated)
                                .clipShape(.capsule)
                        } else if proto.hasPhases {
                            Text(proto.currentPhase.rawValue.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(proto.currentPhase.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(proto.currentPhase.color.opacity(0.14))
                                .clipShape(.capsule)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(proto.weekLabel)
                            .font(.system(.caption, design: .serif).italic())
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("\(proto.compounds.count) \(proto.compounds.count == 1 ? "compound" : "compounds")")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                        if proto.isActive {
                            let logged = proto.compounds.filter { compound in
                                proto.doseLog.contains {
                                    $0.compoundName == compound.compoundName &&
                                    Calendar.current.isDateInToday($0.timestamp)
                                }
                            }.count
                            if !proto.compounds.isEmpty {
                                Text("·")
                                    .font(.caption2)
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                                Text("\(logged)/\(proto.compounds.count) today")
                                    .font(.system(.caption2, weight: .semibold))
                                    .foregroundStyle(logged == proto.compounds.count ? .green : PepTheme.amber)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func leadingBottleIcon(_ proto: PeptideProtocol) -> some View {
        if let primary = proto.compounds.first {
            let accent = PeptidePharmacology.accentColor(for: primary.compoundName)
            let fillFraction: Double = {
                if let v = VialInventoryStore.shared.activeVials(for: primary.compoundName).first {
                    return v.fillFraction
                }
                guard let mg = primary.vialSizeMg, mg > 0 else { return 1 }
                let used = proto.doseLog
                    .filter { $0.compoundName == primary.compoundName && !$0.wasSkipped }
                    .reduce(0.0) { $0 + $1.doseMcg }
                return max(0, min(1, 1 - (used / 1000.0) / mg))
            }()
            PeptideBottleView(
                fillFraction: fillFraction,
                liquidColor: accent,
                compactHeight: 56,
                showHighlights: true
            )
            .frame(width: 32, height: 56)
            .accessibilityLabel("\(primary.compoundName) bottle, \(Int(round(fillFraction * 100)))% full")
        } else {
            ZStack {
                Circle()
                    .fill(proto.goal.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: proto.goal.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(proto.goal.color)
            }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "pill.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PepTheme.teal)
                    Text("PROTOCOLS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(2.0)
                }
                Text(protocols.count == 1 ? "Active Protocol" : "\(protocols.count) Protocols")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showProtocolWizard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 30, height: 30)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.circle)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: showProtocolWizard)

                Button {
                    showManageAll = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.circle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func protocolSummary(_ proto: PeptideProtocol) -> some View {
        Button {
            navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: nil)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: proto.goal.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(proto.goal.color)
                            Text(proto.name)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(1)
                            if !proto.isActive {
                                Text("ENDED")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PepTheme.elevated)
                                    .clipShape(.capsule)
                            }
                        }
                        Text(proto.weekLabel)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    if proto.hasPhases {
                        Text(proto.currentPhase.rawValue)
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(proto.currentPhase.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(proto.currentPhase.color.opacity(0.12))
                            .clipShape(.capsule)
                    }
                }

                if proto.hasPhases {
                    phaseProgressBar(proto)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func phaseProgressBar(_ proto: PeptideProtocol) -> some View {
        let lw = proto.loadingWeeks ?? 0
        let mw = proto.maintenanceWeeks ?? 0
        let tw = proto.taperingWeeks ?? 0
        let ow = proto.offCycleWeeks ?? 0
        let total = max(1, lw + mw + tw + ow)
        return GeometryReader { geo in
            HStack(spacing: 2) {
                if lw > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CyclePhase.loading.color.opacity(proto.currentPhase == .loading ? 1.0 : 0.35))
                        .frame(width: geo.size.width * CGFloat(lw) / CGFloat(total))
                }
                if mw > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CyclePhase.maintenance.color.opacity(proto.currentPhase == .maintenance ? 1.0 : 0.35))
                        .frame(width: geo.size.width * CGFloat(mw) / CGFloat(total))
                }
                if tw > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CyclePhase.tapering.color.opacity(proto.currentPhase == .tapering ? 1.0 : 0.35))
                        .frame(width: geo.size.width * CGFloat(tw) / CGFloat(total))
                }
                if ow > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CyclePhase.offCycle.color.opacity(proto.currentPhase == .offCycle ? 1.0 : 0.35))
                        .frame(width: geo.size.width * CGFloat(ow) / CGFloat(total))
                }
            }
        }
        .frame(height: 6)
    }

    private func compoundSchedulesList(_ proto: PeptideProtocol) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schedule")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if !proto.compounds.isEmpty {
                    Text("\(proto.compounds.count) \(proto.compounds.count == 1 ? "compound" : "compounds")")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                }
            }
            .padding(.bottom, 8)

            if proto.compounds.isEmpty {
                HStack {
                    Image(systemName: "pills")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No compounds added yet")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Spacer()
                }
                .padding(10)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
            } else {
                VStack(spacing: 6) {
                    ForEach(proto.compounds) { compound in
                        compoundRow(proto: proto, compound: compound)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func currentBodyLevelLine(proto: PeptideProtocol, compound: ProtocolCompound, accent: Color) -> some View {
        let level = ProtocolBodyLevelCalculator.currentLevel(for: compound, in: proto)
        inBodyReadout(level: level, accent: accent)
    }

    private func inBodyReadout(level: ProtocolBodyLevelCalculator.Reading, accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .overlay(Circle().stroke(accent.opacity(0.4), lineWidth: 3).blur(radius: 2))
            VStack(alignment: .leading, spacing: 1) {
                Text("IN BODY NOW")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.8))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(level.displayValue)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    if let pct = level.percentOfLastDose {
                        Text("\(pct)% of last dose")
                            .font(.system(.caption2, design: .serif).italic())
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func compoundRow(proto: PeptideProtocol, compound: ProtocolCompound) -> some View {
        let loggedToday = proto.doseLog.contains {
            $0.compoundName == compound.compoundName &&
            Calendar.current.isDateInToday($0.timestamp)
        }
        let accent = PeptidePharmacology.accentColor(for: compound.compoundName)
        let fillFraction: Double = {
            if let v = VialInventoryStore.shared.activeVials(for: compound.compoundName).first {
                return v.fillFraction
            }
            guard let mg = compound.vialSizeMg, mg > 0 else { return 1 }
            let used = proto.doseLog
                .filter { $0.compoundName == compound.compoundName && !$0.wasSkipped }
                .reduce(0.0) { $0 + $1.doseMcg }
            return max(0, min(1, 1 - (used / 1000.0) / mg))
        }()
        let level = ProtocolBodyLevelCalculator.currentLevel(for: compound, in: proto)
        return HStack(alignment: .top, spacing: 14) {
            Button {
                navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: compound.compoundName)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    // Prominent bottle
                    PeptideBottleView(
                        fillFraction: fillFraction,
                        liquidColor: accent,
                        compactHeight: 88,
                        showHighlights: true
                    )
                    .frame(width: 50, height: 88)
                    .shadow(color: accent.opacity(0.25), radius: 8, x: 0, y: 4)

                    VStack(alignment: .leading, spacing: 6) {
                        // Compound name — editorial serif
                        Text(compound.compoundName)
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)

                        // Dose · frequency
                        HStack(spacing: 6) {
                            Text(CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                            Text(compound.frequency)
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(PepTheme.textSecondary)
                                .lineLimit(1)
                        }

                        // In-body level — featured editorial readout
                        inBodyReadout(level: level, accent: accent)
                            .padding(.top, 2)

                        // Sparkline
                        CompoundLevelSparkline(proto: proto, compound: compound, color: accent)
                            .frame(height: 18)
                            .padding(.top, 1)

                        // Supply chip below
                        let supply = SupplyForecastService.forecast(for: compound, in: proto)
                        if supply.hasAnyVial {
                            SupplyChip(forecast: supply, compact: true)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                if proto.isActive {
                    Button {
                        viewModel.quickLogDose(protocolId: proto.id, compoundId: compound.id)
                    } label: {
                        Image(systemName: loggedToday ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(loggedToday ? .green : PepTheme.teal)
                            .symbolEffect(.bounce, value: loggedToday)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: loggedToday)
                }

            Menu {
                Button {
                    navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: compound.compoundName)
                } label: {
                    Label("Open Peptide", systemImage: "chart.line.uptrend.xyaxis")
                }
                Button {
                    editSchedule = EditScheduleTarget(proto: proto, compound: compound)
                } label: {
                    Label("Edit Schedule", systemImage: "slider.horizontal.3")
                }
                Button {
                    navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: nil)
                } label: {
                    Label("Protocol Details", systemImage: "doc.text.magnifyingglass")
                }
                Button(role: .destructive) {
                    viewModel.removeCompound(protocolId: proto.id, compoundId: compound.id)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.circle)
            }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.06), PepTheme.elevated.opacity(0.35)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accent.opacity(0.18), lineWidth: 0.5)
        )
        .contentShape(.rect(cornerRadius: 14))
        .contextMenu {
            Button {
                editSchedule = EditScheduleTarget(proto: proto, compound: compound)
            } label: {
                Label("Edit Schedule", systemImage: "slider.horizontal.3")
            }
            if proto.isActive {
                Button {
                    viewModel.quickLogDose(protocolId: proto.id, compoundId: compound.id)
                } label: {
                    Label("Log Dose", systemImage: "plus.circle")
                }
            }
            Button {
                navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: nil)
            } label: {
                Label("View Details", systemImage: "doc.text")
            }
            Button(role: .destructive) {
                viewModel.removeCompound(protocolId: proto.id, compoundId: compound.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func peptideToolsStrip(_ proto: PeptideProtocol) -> some View {
        let primaryCompound = proto.compounds.first?.compoundName
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Peptide Tools")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                toolTile(title: "Recon", icon: "function", color: PepTheme.blue) {
                    reconInitialCompound = primaryCompound
                    reconInitialVialSizeMg = nil
                    showReconCalc = true
                }
                toolTile(title: "Scan", icon: "viewfinder", color: PepTheme.teal) {
                    showVialScanner = true
                }
                toolTile(title: "Vials", icon: "testtube.2", color: PepTheme.violet) {
                    navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: primaryCompound)
                }
                toolTile(title: "Integrity", icon: "checkmark.seal.fill", color: .green) {
                    showIntegrityCheck = true
                }
                toolTile(title: "Stack", icon: "square.stack.3d.up.fill", color: PepTheme.violet) {
                    showStackBuilder = true
                }
                toolTile(title: "Titrate", icon: "chart.line.uptrend.xyaxis", color: PepTheme.amber) {
                    titrationTargetProto = proto
                    if TitrationScheduleStore.shared.schedule(for: proto.id) != nil {
                        openBuilder(for: proto, seed: nil, existing: TitrationScheduleStore.shared.schedule(for: proto.id))
                    } else {
                        showTitrationPicker = true
                    }
                }
                toolTile(title: "Trends", icon: "waveform.path.ecg", color: PepTheme.teal) {
                    trendsProto = proto
                }
                toolTile(title: "Ask AI", icon: "sparkles", color: PepTheme.blue) {
                    showAIChat = true
                }
            }
        }
    }

    private func toolTile(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.14), in: .circle)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(PepTheme.elevated.opacity(0.55))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(color.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: false)
    }

    private func applyTemplate(_ template: TitrationTemplate, to proto: PeptideProtocol) {
        let compoundName = proto.compounds.first(where: { $0.compoundName.lowercased() == template.compound.lowercased() })?.compoundName
            ?? proto.compounds.first?.compoundName
            ?? template.compound
        let steps = template.steps.map {
            TitrationScheduleStep(week: $0.week, doseMcg: $0.doseMcg, label: $0.label)
        }
        let schedule = TitrationSchedule(
            protocolId: proto.id,
            compoundName: compoundName,
            startDate: Calendar.current.startOfDay(for: Date()),
            steps: steps
        )
        viewModel.saveTitrationSchedule(schedule)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { _ = await TitrationScheduleStore.shared.requestAuthorizationIfNeeded() }
    }

    private func openBuilder(for proto: PeptideProtocol, seed: TitrationTemplate?, existing: TitrationSchedule?) {
        let name = proto.compounds.first?.compoundName ?? seed?.compound ?? ""
        titrationBuilder = TitrationBuilderContext(
            protocolId: proto.id,
            compoundName: name,
            existing: existing,
            seed: seed
        )
    }

    private func footerActions(_ proto: PeptideProtocol) -> some View {
        HStack(spacing: 10) {
            Button {
                navDetailProto = ProtocolDetailNavTarget(proto: proto, compoundName: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Details")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PepTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                navJourneyProto = proto
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Journey")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(PepTheme.teal.gradient)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Start card

    private var startProtocolCard: some View {
        Button {
            showProtocolWizard = true
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [PepTheme.teal.opacity(0.15), PepTheme.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)

                    VStack(spacing: 10) {
                        Image(systemName: "pill.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(PepTheme.teal)

                        Text("Start Your First Protocol")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }

                Text("Set up your peptide protocol with dose scheduling, cycle planning, and injection tracking")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
            .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(colors: [PepTheme.teal.opacity(0.3), PepTheme.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.impact(weight: .medium), trigger: showProtocolWizard)
    }
}

// MARK: - Supporting types

private struct EditScheduleTarget: Identifiable {
    let proto: PeptideProtocol
    let compound: ProtocolCompound
    var id: UUID { compound.id }
}

struct ProtocolDetailNavTarget: Identifiable, Hashable {
    let proto: PeptideProtocol
    let compoundName: String?
    var id: String { "\(proto.id.uuidString)|\(compoundName ?? "")" }

    static func == (lhs: ProtocolDetailNavTarget, rhs: ProtocolDetailNavTarget) -> Bool {
        lhs.proto.id == rhs.proto.id && lhs.compoundName == rhs.compoundName
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(proto.id)
        hasher.combine(compoundName)
    }
}

// MARK: - Manage All Protocols Sheet

struct ManageProtocolsSheet: View {
    @Bindable var viewModel: HomeViewModel
    let onAddNew: () -> Void
    let onOpen: (PeptideProtocol) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: PeptideProtocol?

    private var sorted: [PeptideProtocol] {
        viewModel.allProtocols.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }
            return a.startDate > b.startDate
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Button(action: onAddNew) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(PepTheme.teal)
                            Text("Add New Protocol")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        .padding(14)
                        .background(PepTheme.teal.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(PepTheme.teal.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(sorted) { proto in
                        manageRow(proto)
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Manage Protocols")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .alert("Delete Protocol?", isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { confirmDelete = nil }
                Button("Delete", role: .destructive) {
                    if let p = confirmDelete { viewModel.deleteProtocolFromHome(p) }
                    confirmDelete = nil
                }
            } message: {
                Text("This permanently removes the protocol and all its logs.")
            }
        }
    }

    private func manageRow(_ proto: PeptideProtocol) -> some View {
        Button {
            onOpen(proto)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(proto.goal.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: proto.goal.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(proto.goal.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(proto.name)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                            .lineLimit(1)
                        if proto.isActive {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PepTheme.teal)
                                .clipShape(.capsule)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(proto.weekLabel)
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("\(proto.compounds.count) compound\(proto.compounds.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                Spacer()

                Menu {
                    if proto.isActive {
                        Button {
                            viewModel.archiveProtocolFromHome(proto)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    } else {
                        Button {
                            viewModel.reactivateProtocolFromHome(proto)
                        } label: {
                            Label("Reactivate", systemImage: "play.circle")
                        }
                    }
                    Button {
                        viewModel.setActiveProtocol(proto)
                    } label: {
                        Label("Set as Primary", systemImage: "star")
                    }
                    Button(role: .destructive) {
                        confirmDelete = proto
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.circle)
                }
            }
            .padding(12)
            .background(PepTheme.cardSurface.opacity(0.6))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        proto.isActive ? proto.goal.color.opacity(0.3) : PepTheme.glassBorderBottom,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TitrationBuilderContext: Identifiable {
    let id = UUID()
    let protocolId: UUID
    let compoundName: String
    let existing: TitrationSchedule?
    let seed: TitrationTemplate?
}
