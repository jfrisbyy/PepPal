import SwiftUI

struct ProtocolDetailView: View {
    @State private var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(protocolData: PeptideProtocol) {
        _viewModel = State(initialValue: ProtocolDetailViewModel(protocolData: protocolData))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                protocolHeader
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

                batchInfoSection
                supplementStackSection
                notesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle(viewModel.protocolData.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { viewModel.showReconCalculator = true } label: {
                        Label("Reconstitution Calculator", systemImage: "function")
                    }
                    Button {} label: {
                        Label("Edit Protocol", systemImage: "pencil")
                    }
                    Button(role: .destructive) {} label: {
                        Label("End Protocol", systemImage: "stop.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
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
        .onAppear {
            viewModel.refreshFromSupabase()
        }
    }

    // MARK: - Protocol Header

    private var protocolHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [viewModel.protocolData.goal.color.opacity(0.3), viewModel.protocolData.goal.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: viewModel.protocolData.goal.icon)
                        .font(.title2)
                        .foregroundStyle(viewModel.protocolData.goal.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.protocolData.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(viewModel.protocolData.goal.rawValue)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(viewModel.protocolData.goal.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(viewModel.protocolData.goal.color.opacity(0.12))
                            .clipShape(.capsule)

                        Text("Day \(viewModel.protocolData.currentDay)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                headerStat(label: "Phase", value: viewModel.protocolData.currentPhase.rawValue, color: viewModel.protocolData.currentPhase.color)
                headerStat(label: "Days Left", value: "\(viewModel.daysRemainingInPhase)", color: PepTheme.amber)
                headerStat(label: "Compounds", value: "\(viewModel.protocolData.compounds.count)", color: PepTheme.teal)
                headerStat(label: "Doses Logged", value: "\(viewModel.protocolData.doseLog.count)", color: PepTheme.blue)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private func headerStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Next Dose Action

    private var nextDoseAction: some View {
        Group {
            if let nextDose = viewModel.protocolData.nextDose {
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
                            Text("\(Int(nextDose.doseMcg))mcg \(nextDose.compoundName)")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(PepTheme.teal)
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
            }
        }
    }

    // MARK: - Cycle Timeline

    private var cycleTimelineSection: some View {
        Group {
            if viewModel.protocolData.hasPhases || viewModel.protocolData.totalWeeks != nil {
                CollapsibleSection(
                    title: "Cycle Timeline",
                    icon: "calendar.badge.clock",
                    iconColor: PepTheme.blue,
                    isExpanded: viewModel.isSectionExpanded("timeline"),
                    toggle: { viewModel.toggleSection("timeline") }
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
        CollapsibleSection(
            title: "Dose History",
            icon: "list.bullet.clipboard",
            iconColor: PepTheme.teal,
            isExpanded: viewModel.isSectionExpanded("doseLog"),
            toggle: { viewModel.toggleSection("doseLog") },
            trailing: {
                Button { viewModel.showLogDoseSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PepTheme.teal)
                }
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
                        doseLogRow(dose)
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
                Text("\(Int(dose.doseMcg))mcg \(dose.compoundName)")
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
        CollapsibleSection(
            title: "Injection Site Rotation",
            icon: "figure.stand",
            iconColor: PepTheme.blue,
            isExpanded: viewModel.isSectionExpanded("sites"),
            toggle: { viewModel.toggleSection("sites") }
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
        CollapsibleSection(
            title: "Reconstitution Calculator",
            icon: "function",
            iconColor: .orange,
            isExpanded: viewModel.isSectionExpanded("recon"),
            toggle: { viewModel.toggleSection("recon") }
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
        CollapsibleSection(
            title: "Side Effects",
            icon: "exclamationmark.triangle",
            iconColor: PepTheme.amber,
            isExpanded: viewModel.isSectionExpanded("sideEffects"),
            toggle: { viewModel.toggleSection("sideEffects") },
            trailing: {
                Button { viewModel.showSideEffectSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PepTheme.amber)
                }
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
        CollapsibleSection(
            title: "Titration Schedule",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            isExpanded: viewModel.isSectionExpanded("titration"),
            toggle: { viewModel.toggleSection("titration") }
        ) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.titrationSteps.enumerated()), id: \.element.id) { index, step in
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

                        Text("\(Int(step.doseMcg))mcg")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(step.isCompleted ? .green : PepTheme.textSecondary)
                    }
                    .padding(.vertical, 10)

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
            }
        }
    }

    // MARK: - Weight Loss Tracking

    private var weightLossTrackingSection: some View {
        CollapsibleSection(
            title: "Weight Loss Tracking",
            icon: "scalemass.fill",
            iconColor: .green,
            isExpanded: viewModel.isSectionExpanded("weightLoss"),
            toggle: { viewModel.toggleSection("weightLoss") }
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
        CollapsibleSection(
            title: "Recovery Tracking",
            icon: "cross.case.fill",
            iconColor: PepTheme.blue,
            isExpanded: viewModel.isSectionExpanded("healing"),
            toggle: { viewModel.toggleSection("healing") }
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
        CollapsibleSection(
            title: "Muscle & GH Tracking",
            icon: "figure.strengthtraining.traditional",
            iconColor: PepTheme.teal,
            isExpanded: viewModel.isSectionExpanded("muscle"),
            toggle: { viewModel.toggleSection("muscle") }
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
        CollapsibleSection(
            title: "Cognitive Tracking",
            icon: "brain.head.profile",
            iconColor: PepTheme.violet,
            isExpanded: viewModel.isSectionExpanded("cognitive"),
            toggle: { viewModel.toggleSection("cognitive") }
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
        CollapsibleSection(
            title: "Tanning & Cosmetic",
            icon: "sun.max.fill",
            iconColor: .orange,
            isExpanded: viewModel.isSectionExpanded("tanning"),
            toggle: { viewModel.toggleSection("tanning") }
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

    // MARK: - Batch Info

    private var batchInfoSection: some View {
        CollapsibleSection(
            title: "Batch & Source Info",
            icon: "shippingbox.fill",
            iconColor: PepTheme.textSecondary,
            isExpanded: viewModel.isSectionExpanded("batch"),
            toggle: { viewModel.toggleSection("batch") }
        ) {
            VStack(spacing: 10) {
                ForEach(viewModel.protocolData.compounds) { compound in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(compound.compoundName)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            batchDetail(label: "Vendor", value: compound.vendorName ?? "Not set")
                            batchDetail(label: "Batch #", value: compound.batchNumber ?? "Not set")
                            batchDetail(label: "Expiration", value: compound.expirationDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not set")
                            batchDetail(label: "Route", value: compound.injectionRoute.rawValue)
                        }
                    }
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
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
        CollapsibleSection(
            title: "Supplement Stack",
            icon: "leaf.fill",
            iconColor: .green,
            isExpanded: viewModel.isSectionExpanded("supplements"),
            toggle: { viewModel.toggleSection("supplements") },
            trailing: {
                Button { viewModel.showAddSupplementSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                }
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
        CollapsibleSection(
            title: "Notes",
            icon: "note.text",
            iconColor: PepTheme.violet,
            isExpanded: viewModel.isSectionExpanded("notes"),
            toggle: { viewModel.toggleSection("notes") },
            trailing: {
                Button { viewModel.showAddNoteSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PepTheme.violet)
                }
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
