import SwiftUI

struct GuidedInjectionView: View {
    @Bindable var viewModel: ProtocolDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0
    @State private var suppliesChecked: Set<String> = []
    @State private var swabTimer: Int = 10
    @State private var swabRunning: Bool = false
    @State private var injectionTimer: Int = 5
    @State private var injectionRunning: Bool = false
    @State private var postSideEffects: Set<String> = []
    @State private var postNotes: String = ""
    @State private var severity: Int = 1
    @State private var selectedVial: Vial? = nil

    private let supplies = [
        "Vial (reconstituted, not expired)",
        "BAC water (if mixing)",
        "Alcohol swab",
        "Insulin syringe",
        "Clean work surface",
        "Sharps container"
    ]

    private let sideEffectTags = ["Flushing", "Headache", "Injection site reaction", "Fatigue", "Nausea", "Lightheadedness", "None"]

    private let totalSteps = 5

    var body: some View {
        if PeptideAccessManager.shared.shouldShowTrackAEmptyState {
            NavigationStack {
                TrackAEmptyStateView(
                    surface: .guidedInjection,
                    icon: "figure.walk.motion",
                    title: "Guided injection flow",
                    blurb: "EPTI walks you through supplies, site rotation, draw, and post-injection logging — with timers and built-in safety checks."
                )
                .navigationTitle("Guided Injection")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        } else {
            guidedBody
        }
    }

    @ViewBuilder
    private var guidedBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                ScrollView {
                    Group {
                        switch step {
                        case 0: suppliesStep
                        case 1: siteStep
                        case 2: drawStep
                        case 3: injectStep
                        default: postStep
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                }
                .scrollIndicators(.hidden)

                footerBar
            }
            .appBackground()
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Quit") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Supplies"
        case 1: return "Choose Site"
        case 2: return "Draw & Check"
        case 3: return "Inject"
        default: return "How Did It Go?"
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? PepTheme.teal : PepTheme.elevated)
                    .frame(width: i == step ? 28 : 14, height: 6)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: - Step 0: Supplies

    private var suppliesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gather your supplies")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            Text("Tap each item as you place it on your clean work surface.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(supplies, id: \.self) { item in
                    Button {
                        withAnimation(.spring()) {
                            if suppliesChecked.contains(item) { suppliesChecked.remove(item) }
                            else {
                                suppliesChecked.insert(item)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: suppliesChecked.contains(item) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(suppliesChecked.contains(item) ? .green : PepTheme.textSecondary)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .strikethrough(suppliesChecked.contains(item), color: PepTheme.textSecondary)
                            Spacer()
                        }
                        .padding(14)
                        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }

            if !availableVials.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SELECT VIAL")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                    ForEach(availableVials) { vial in
                        Button {
                            selectedVial = vial
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedVial?.id == vial.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedVial?.id == vial.id ? PepTheme.teal : PepTheme.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vial.compoundName)
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(PepTheme.textPrimary)
                                    Text("\(vial.dosesRemaining) doses left · \(vial.statusLabel)")
                                        .font(.caption2)
                                        .foregroundStyle(vial.statusColor)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        if vial.isExpired {
                            Text("This vial is past its BUD — use with caution.")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 24)
    }

    private var availableVials: [Vial] {
        VialInventoryStore.shared.activeVials(for: viewModel.newDoseCompound)
    }

    // MARK: - Step 1: Site

    private var siteStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick an injection site")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Rotating sites reduces scar tissue and local irritation.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            InjectionBodyMapView(viewModel: viewModel)

            if viewModel.siteRecency(viewModel.newDoseSite) == .overused {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("This site was used in the last 3 days — consider rotating.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Step 2: Draw & Check

    private var drawStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Draw your dose")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Compound", systemImage: "pill.fill")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(viewModel.newDoseCompound)
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Divider().overlay(PepTheme.separatorColor)

                    HStack {
                        Label("Dose", systemImage: "syringe.fill")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text("\(viewModel.newDoseMcg) \(CompoundUnitHelper.unit(for: viewModel.newDoseCompound).rawValue)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PepTheme.teal)
                    }

                    if let vial = selectedVial {
                        HStack {
                            Label("From Vial", systemImage: "testtube.2")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                            Spacer()
                            Text(vial.compoundName)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textPrimary)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("CHECKLIST")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                checkItem("Vial is clear, not cloudy")
                checkItem("No particles or discoloration")
                checkItem("Swab vial top before piercing")
                checkItem("Tap syringe to remove air bubbles")
            }

            // Safety panel
            safetyPanel
        }
        .padding(.bottom, 24)
    }

    private var safetyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(safetyIssues, id: \.self) { issue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PepTheme.amber)
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(PepTheme.amber.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var safetyIssues: [String] {
        var out: [String] = []
        if let vial = selectedVial, vial.isExpired {
            out.append("Selected vial is past its Beyond-Use Date.")
        }
        if let dose = Double(viewModel.newDoseMcg),
           let hint = CompoundUnitHelper.typicalRangeHint(for: viewModel.newDoseCompound) {
            let mcg = CompoundUnitHelper.toMcg(dose, for: viewModel.newDoseCompound)
            let numbers = hint.matches(of: /\d+(?:\.\d+)?/).compactMap { Double($0.output) }
            if numbers.count >= 2 {
                let isMg = hint.lowercased().contains("mg") && !hint.lowercased().contains("mcg")
                let factor = isMg ? 1000.0 : 1.0
                let lower = numbers[0] * factor
                let upper = numbers[1] * factor
                if mcg < lower * 0.5 {
                    out.append("Dose is well below typical range. Double-check your math.")
                } else if mcg > upper * 1.5 {
                    out.append("Dose is well above typical range. Double-check your math.")
                }
            }
        }
        return out
    }

    private func checkItem(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(PepTheme.teal)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Step 3: Inject

    private var injectStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inject")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)

            GlassCard {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .foregroundStyle(PepTheme.blue)
                        Text("Swab site for 10 seconds")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    Text("\(swabTimer)s")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(swabTimer == 0 ? .green : PepTheme.teal)
                        .contentTransition(.numericText())

                    Button {
                        startSwabTimer()
                    } label: {
                        Text(swabRunning ? "Running..." : swabTimer == 0 ? "Done" : "Start Swab Timer")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(swabRunning ? PepTheme.textSecondary : PepTheme.blue, in: .capsule)
                    }
                    .disabled(swabRunning)
                }
            }

            GlassCard {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "syringe.fill")
                            .foregroundStyle(.orange)
                        Text("Inject slowly, count to 5, withdraw")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    Text("\(injectionTimer)s")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(injectionTimer == 0 ? .green : .orange)
                        .contentTransition(.numericText())

                    Button {
                        startInjectionTimer()
                    } label: {
                        Text(injectionRunning ? "Injecting..." : injectionTimer == 0 ? "Complete" : "Start Injection")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(injectionRunning ? PepTheme.textSecondary : .orange, in: .capsule)
                    }
                    .disabled(injectionRunning)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func startSwabTimer() {
        swabRunning = true
        swabTimer = 10
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { @MainActor in
            while swabTimer > 0 {
                try? await Task.sleep(for: .seconds(1))
                swabTimer = max(0, swabTimer - 1)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            swabRunning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func startInjectionTimer() {
        injectionRunning = true
        injectionTimer = 5
        Task { @MainActor in
            while injectionTimer > 0 {
                try? await Task.sleep(for: .seconds(1))
                injectionTimer = max(0, injectionTimer - 1)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            injectionRunning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Step 4: Post

    private var postStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How did it feel?")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Optional — logging symptoms builds your pattern over time.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("SYMPTOMS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(sideEffectTags, id: \.self) { tag in
                        let isSelected = postSideEffects.contains(tag)
                        Button {
                            if tag == "None" {
                                postSideEffects = isSelected ? [] : ["None"]
                            } else {
                                postSideEffects.remove("None")
                                if isSelected { postSideEffects.remove(tag) }
                                else { postSideEffects.insert(tag) }
                            }
                        } label: {
                            Text(tag)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? PepTheme.amber : PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                    }
                }
            }

            if !postSideEffects.isEmpty && !postSideEffects.contains("None") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("SEVERITY")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text(["Mild", "Moderate", "Significant", "Severe"][max(0, min(severity - 1, 3))])
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(severityColor)
                    }
                    HStack(spacing: 6) {
                        ForEach(1...4, id: \.self) { level in
                            Button { severity = level } label: {
                                Circle()
                                    .fill(severity >= level ? colorFor(level) : PepTheme.elevated)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text("\(level)")
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundStyle(severity >= level ? .white : PepTheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("e.g., slight warmth, no bleeding...", text: $postNotes, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(3...5)
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
            }
        }
        .padding(.bottom, 24)
    }

    private var severityColor: Color { colorFor(severity) }

    private func colorFor(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Text("Back")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PepTheme.elevated, in: .capsule)
                }
            }

            Button {
                advance()
            } label: {
                Text(step == totalSteps - 1 ? "Log Injection" : "Continue")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.teal, in: .capsule)
            }
            .disabled(!canAdvance)
        }
        .padding(.horizontal)
        .padding(.bottom, 14)
        .padding(.top, 8)
        .background(PepTheme.background.opacity(0.95))
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return suppliesChecked.count >= 3
        case 3: return !swabRunning && !injectionRunning
        default: return true
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        // Record symptoms & notes
        if !postSideEffects.isEmpty && !postSideEffects.contains("None") {
            for tag in postSideEffects {
                viewModel.newEffectName = tag
                viewModel.newEffectSeverity = severity
                viewModel.newEffectNotes = postNotes
                viewModel.logSideEffect()
            }
        }

        // Append combined notes for dose
        let combined: String = {
            var parts: [String] = []
            if !postSideEffects.isEmpty { parts.append("Symptoms: " + postSideEffects.joined(separator: ", ")) }
            if !postNotes.isEmpty { parts.append(postNotes) }
            return parts.joined(separator: " — ")
        }()
        viewModel.newDoseNotes = combined

        // Log dose (will decrement vial on return)
        let doseMcg = CompoundUnitHelper.toMcg(Double(viewModel.newDoseMcg) ?? 0, for: viewModel.newDoseCompound)
        viewModel.logDose()
        if let vial = selectedVial {
            VialInventoryStore.shared.recordDose(vialId: vial.id, mcg: doseMcg)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
