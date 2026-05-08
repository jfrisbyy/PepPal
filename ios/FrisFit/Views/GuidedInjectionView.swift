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
    @FocusState private var notesFocused: Bool

    private let accent: Color = PepTheme.teal

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
            ScrollView {
                VStack(spacing: 22) {
                    editorialHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    chapterRail
                        .padding(.horizontal, 20)

                    Group {
                        switch step {
                        case 0: suppliesStep
                        case 1: siteStep
                        case 2: drawStep
                        case 3: injectStep
                        default: postStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .id(step)

                    footerActions
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Quit") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { notesFocused = false }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
    }

    // MARK: - Editorial Header

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("THE RITUAL")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accent.opacity(0.85))
                Rectangle()
                    .fill(LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.5)
            }
            Text(stepTitle)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .kerning(-0.5)
                .foregroundStyle(PepTheme.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: step)
            Text(stepBlurb)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: step)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Lay out your kit"
        case 1: return "Choose the site"
        case 2: return "Draw with care"
        case 3: return "The slow press"
        default: return "How did it land?"
        }
    }

    private var stepBlurb: String {
        switch step {
        case 0: return "Begin with a clean field — every tool in its place."
        case 1: return "Rotate sites; your skin remembers."
        case 2: return "Verify, then verify again. Numbers matter here."
        case 3: return "Steady, slow, and unhurried. Count it out."
        default: return "Capture how it felt — patterns surface in the small notes."
        }
    }

    // MARK: - Chapter Rail

    private var chapterRail: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%02d", i + 1))
                        .font(.system(size: 9, weight: .semibold, design: .serif))
                        .tracking(1.4)
                        .foregroundStyle(i == step ? accent : (i < step ? PepTheme.textPrimary.opacity(0.7) : PepTheme.textSecondary.opacity(0.5)))
                    Capsule()
                        .fill(i <= step ? accent : PepTheme.elevated)
                        .frame(height: 2)
                        .opacity(i <= step ? 1 : 0.6)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.35), value: step)
            }
        }
    }

    // MARK: - Step 0: Supplies

    private var suppliesStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(kicker: "01 — Kit", title: "Tap as you place each piece", accent: accent)

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
                                    .foregroundStyle(suppliesChecked.contains(item) ? accent : PepTheme.textSecondary)
                                Text(item)
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                                    .strikethrough(suppliesChecked.contains(item), color: PepTheme.textSecondary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(PepTheme.elevated.opacity(0.5))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .editorialCard(accent: accent)

            if !availableVials.isEmpty {
                vialPickerCard
            }
        }
    }

    private var vialPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "From Inventory", title: "Pick the vial", accent: PepTheme.amber)

            VStack(spacing: 8) {
                ForEach(availableVials) { vial in
                    Button {
                        selectedVial = vial
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedVial?.id == vial.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedVial?.id == vial.id ? accent : PepTheme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vial.compoundName)
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("\(vial.dosesRemaining) doses left · \(vial.statusLabel)")
                                    .font(.system(size: 11, design: .serif))
                                    .italic()
                                    .foregroundStyle(vial.statusColor)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    if vial.isExpired {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                            Text("Past its BUD — use with caution.")
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private var availableVials: [Vial] {
        VialInventoryStore.shared.activeVials(for: viewModel.newDoseCompound)
    }

    // MARK: - Step 1: Site

    private var siteStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "02 — Site", title: "Where today?", accent: accent)

            Text("Rotating sites reduces scar tissue and local irritation.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)

            InjectionBodyMapView(viewModel: viewModel)

            if viewModel.siteRecency(viewModel.newDoseSite) == .overused {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Used recently")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("This site was used in the last 3 days — consider rotating.")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .editorialCard(accent: accent)
    }

    // MARK: - Step 2: Draw & Check

    private var drawStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(kicker: "03 — Draw", title: "Tonight's number", accent: accent)

                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.newDoseCompound)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("\(viewModel.newDoseMcg) \(CompoundUnitHelper.unit(for: viewModel.newDoseCompound).rawValue)")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(accent)
                }

                Rectangle()
                    .fill(LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.5)

                if let vial = selectedVial {
                    HStack(spacing: 8) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 11))
                            .foregroundStyle(PepTheme.textSecondary)
                        Text("From \(vial.compoundName)")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                    }
                }
            }
            .editorialCard(accent: accent)

            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(kicker: "Verify", title: "Before you pierce", accent: PepTheme.violet)
                VStack(spacing: 10) {
                    checkItem("Vial is clear, not cloudy")
                    checkItem("No particles or discoloration")
                    checkItem("Swab vial top before piercing")
                    checkItem("Tap syringe to remove air bubbles")
                }
            }
            .editorialCard(accent: PepTheme.violet)

            if !safetyIssues.isEmpty {
                safetyPanel
            }
        }
    }

    private var safetyPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Caution", title: "Worth a second look", accent: PepTheme.amber)
            VStack(spacing: 8) {
                ForEach(safetyIssues, id: \.self) { issue in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(PepTheme.amber)
                        Text(issue)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }
                    .padding(10)
                    .background(PepTheme.amber.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Step 3: Inject

    private var injectStep: some View {
        VStack(spacing: 16) {
            timerCard(
                kicker: "Step One",
                title: "Swab the site",
                instruction: "Wipe firmly for ten seconds, then let it air-dry.",
                seconds: swabTimer,
                running: swabRunning,
                tint: PepTheme.blue,
                buttonLabel: swabRunning ? "Running…" : (swabTimer == 0 ? "Done" : "Start Swab Timer"),
                action: startSwabTimer
            )

            timerCard(
                kicker: "Step Two",
                title: "The slow press",
                instruction: "Inject slowly, count to five, then withdraw.",
                seconds: injectionTimer,
                running: injectionRunning,
                tint: .orange,
                buttonLabel: injectionRunning ? "Injecting…" : (injectionTimer == 0 ? "Complete" : "Start Injection"),
                action: startInjectionTimer
            )
        }
    }

    private func timerCard(
        kicker: String,
        title: String,
        instruction: String,
        seconds: Int,
        running: Bool,
        tint: Color,
        buttonLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: kicker, title: title, accent: tint)

            Text(instruction)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(seconds)")
                    .font(.system(size: 64, weight: .semibold, design: .serif))
                    .foregroundStyle(seconds == 0 ? .green : tint)
                    .contentTransition(.numericText())
                Text("s")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 8) {
                    if running {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: seconds == 0 ? "checkmark" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(buttonLabel)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .tracking(0.3)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: running ? [PepTheme.textSecondary.opacity(0.7), PepTheme.textSecondary.opacity(0.5)] : [tint, tint.opacity(0.85)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: tint.opacity(running ? 0 : 0.25), radius: 10, x: 0, y: 5)
            }
            .disabled(running)
        }
        .editorialCard(accent: tint)
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
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(kicker: "After", title: "What did you feel?", accent: accent)
                Text("Optional — small notes, tracked over time, become real signal.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
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
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(tag)
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundStyle(isSelected ? .black : PepTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? PepTheme.amber : PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                    }
                }
            }
            .editorialCard(accent: accent)

            if !postSideEffects.isEmpty && !postSideEffects.contains("None") {
                VStack(alignment: .leading, spacing: 14) {
                    EditorialSectionHeading(
                        kicker: "Severity",
                        title: ["Mild", "Moderate", "Significant", "Severe"][max(0, min(severity - 1, 3))],
                        accent: severityColor
                    )
                    HStack(spacing: 8) {
                        ForEach(1...4, id: \.self) { level in
                            Button {
                                severity = level
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(severity >= level ? colorFor(level) : PepTheme.elevated)
                                        .frame(width: 38, height: 38)
                                        .overlay {
                                            Text("\(level)")
                                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                                .foregroundStyle(severity >= level ? .white : PepTheme.textSecondary)
                                        }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .editorialCard(accent: severityColor)
            }

            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionHeading(kicker: "Notes", title: "A line for the record", accent: PepTheme.violet)
                TextField("e.g., slight warmth, no bleeding…", text: $postNotes, axis: .vertical)
                    .focused($notesFocused)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(3...5)
                    .padding(12)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 12))
            }
            .editorialCard(accent: PepTheme.violet)
        }
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

    private var footerActions: some View {
        VStack(spacing: 10) {
            EditorialPrimaryButton(
                step == totalSteps - 1 ? "Log Injection" : "Continue",
                icon: step == totalSteps - 1 ? "checkmark.seal.fill" : "arrow.right",
                accent: accent,
                action: advance
            )
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)

            if step > 0 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { step -= 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back to \(prevStepLabel)")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var prevStepLabel: String {
        switch step - 1 {
        case 0: return "kit"
        case 1: return "site"
        case 2: return "draw"
        case 3: return "inject"
        default: return "start"
        }
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        if !postSideEffects.isEmpty && !postSideEffects.contains("None") {
            for tag in postSideEffects {
                viewModel.newEffectName = tag
                viewModel.newEffectSeverity = severity
                viewModel.newEffectNotes = postNotes
                viewModel.logSideEffect()
            }
        }

        let combined: String = {
            var parts: [String] = []
            if !postSideEffects.isEmpty { parts.append("Symptoms: " + postSideEffects.joined(separator: ", ")) }
            if !postNotes.isEmpty { parts.append(postNotes) }
            return parts.joined(separator: " — ")
        }()
        viewModel.newDoseNotes = combined

        let doseMcg = CompoundUnitHelper.toMcg(Double(viewModel.newDoseMcg) ?? 0, for: viewModel.newDoseCompound)
        viewModel.logDose()
        if let vial = selectedVial {
            VialInventoryStore.shared.recordDose(vialId: vial.id, mcg: doseMcg)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
