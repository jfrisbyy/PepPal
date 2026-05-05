import SwiftUI
import PhotosUI

/// Single sheet that switches forms based on the chosen lane / pin type.
/// Covers all six pin types from the foundation spec.
struct JourneyEventCaptureSheet: View {
    let initialLane: JourneyLane
    var onSaved: ((JourneyEvent) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var lane: JourneyLane
    @State private var subtype: PinSubtype = .bodyMilestone
    @State private var timestamp: Date = Date()
    @State private var title: String = ""
    @State private var note: String = ""

    // Body
    @State private var weightLbs: String = ""
    @State private var bodyFatPercent: String = ""

    // Compound (past or current)
    @State private var compoundName: String = ""
    @State private var doseAmount: String = ""
    @State private var doseUnit: String = "mcg"
    @State private var frequency: String = "Weekly"
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var perceivedResults: String = ""
    @State private var sideEffectsText: String = ""
    @State private var reasonStoppedText: String = ""
    @State private var schedule: String = ""
    @State private var plannedCycleWeeks: String = ""
    @State private var vialsRemaining: String = ""

    // Training phase
    @State private var phaseType: JourneyTrainingPhase = .cut

    // Bloodwork
    @State private var drawDate: Date = Date()

    // Life
    @State private var lifeEventType: JourneyLifeEventType = .vacation

    @State private var saving: Bool = false
    @State private var errorMessage: String?

    private let frequencies = ["Daily", "Twice daily", "Every other day", "Weekly", "Twice weekly", "Custom"]
    private let doseUnits = ["mcg", "mg", "iu", "ml"]

    enum PinSubtype: String, CaseIterable, Identifiable {
        case bodyMilestone
        case pastCycle
        case currentCycle
        case trainingPhase
        case bloodworkDate
        case lifeEvent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .bodyMilestone: return "Body Milestone"
            case .pastCycle: return "Past Cycle"
            case .currentCycle: return "Current Cycle"
            case .trainingPhase: return "Training Phase"
            case .bloodworkDate: return "Bloodwork"
            case .lifeEvent: return "Life Event"
            }
        }

        var icon: String {
            switch self {
            case .bodyMilestone: return "scalemass.fill"
            case .pastCycle: return "arrow.uturn.backward.circle.fill"
            case .currentCycle: return "syringe.fill"
            case .trainingPhase: return "dumbbell.fill"
            case .bloodworkDate: return "drop.fill"
            case .lifeEvent: return "calendar.badge.exclamationmark"
            }
        }

        var lane: JourneyLane {
            switch self {
            case .bodyMilestone: return .body
            case .pastCycle, .currentCycle: return .compounds
            case .trainingPhase: return .training
            case .bloodworkDate: return .bloodwork
            case .lifeEvent: return .life
            }
        }
    }

    init(initialLane: JourneyLane, onSaved: ((JourneyEvent) -> Void)? = nil) {
        self.initialLane = initialLane
        self.onSaved = onSaved
        _lane = State(initialValue: initialLane)
        switch initialLane {
        case .body: _subtype = State(initialValue: .bodyMilestone)
        case .compounds: _subtype = State(initialValue: .currentCycle)
        case .training: _subtype = State(initialValue: .trainingPhase)
        case .bloodwork: _subtype = State(initialValue: .bloodworkDate)
        case .life: _subtype = State(initialValue: .lifeEvent)
        case .agentAnnotation: _subtype = State(initialValue: .bodyMilestone)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                subtypePicker

                switch subtype {
                case .bodyMilestone: bodyForm
                case .pastCycle: pastCycleForm
                case .currentCycle: currentCycleForm
                case .trainingPhase: trainingPhaseForm
                case .bloodworkDate: bloodworkForm
                case .lifeEvent: lifeForm
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Add Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saving ? "Saving…" : "Save") {
                        save()
                    }
                    .disabled(saving || !canSave)
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? PepTheme.teal : PepTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var subtypePicker: some View {
        Section("Type") {
            Picker("Pin type", selection: $subtype) {
                ForEach(PinSubtype.allCases) { sub in
                    Label(sub.label, systemImage: sub.icon).tag(sub)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: subtype) { _, newValue in
                lane = newValue.lane
            }
        }
    }

    // MARK: - Forms

    private var bodyForm: some View {
        Group {
            Section("When") {
                DatePicker("Date", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
            }
            Section("Body") {
                TextField("Weight (lbs)", text: $weightLbs)
                    .keyboardType(.decimalPad)
                TextField("Body fat % (optional)", text: $bodyFatPercent)
                    .keyboardType(.decimalPad)
            }
            Section("Note") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
    }

    private var pastCycleForm: some View {
        Group {
            Section("Compound") {
                TextField("Compound name", text: $compoundName)
                    .textInputAutocapitalization(.words)
                HStack {
                    TextField("Dose", text: $doseAmount)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $doseUnit) {
                        ForEach(doseUnits, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Picker("Frequency", selection: $frequency) {
                    ForEach(frequencies, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)
            }
            Section("Outcome") {
                TextField("Perceived results", text: $perceivedResults, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Side effects (comma separated)", text: $sideEffectsText, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Reason stopped (comma separated)", text: $reasonStoppedText, axis: .vertical)
                    .lineLimit(1...3)
            }
        }
    }

    private var currentCycleForm: some View {
        Group {
            Section("Compound") {
                TextField("Compound name", text: $compoundName)
                    .textInputAutocapitalization(.words)
                HStack {
                    TextField("Dose", text: $doseAmount)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $doseUnit) {
                        ForEach(doseUnits, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Picker("Frequency", selection: $frequency) {
                    ForEach(frequencies, id: \.self) { Text($0).tag($0) }
                }
                TextField("Schedule (e.g. Mon/Thu)", text: $schedule)
            }
            Section("Plan") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                TextField("Planned cycle length (weeks)", text: $plannedCycleWeeks)
                    .keyboardType(.numberPad)
                TextField("Vials remaining", text: $vialsRemaining)
                    .keyboardType(.numberPad)
            }
            Section {
                NavigationLink {
                    VialScannerView { _, _ in }
                } label: {
                    Label("Scan a vial now", systemImage: "viewfinder")
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
    }

    private var trainingPhaseForm: some View {
        Group {
            Section("Phase") {
                Picker("Type", selection: $phaseType) {
                    ForEach(JourneyTrainingPhase.allCases, id: \.self) { p in
                        Label(p.label, systemImage: p.icon).tag(p)
                    }
                }
            }
            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)
            }
            Section("Note") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var bloodworkForm: some View {
        Group {
            Section("Draw") {
                DatePicker("Draw date", selection: $drawDate, displayedComponents: .date)
            }
            Section {
                Text("After saving, upload the lab photo from Bloodwork to parse markers automatically.")
                    .font(.footnote)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var lifeForm: some View {
        Group {
            Section("When") {
                DatePicker("Date", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
            }
            Section("Type") {
                Picker("Type", selection: $lifeEventType) {
                    ForEach(JourneyLifeEventType.allCases, id: \.self) { t in
                        Label(t.label, systemImage: t.icon).tag(t)
                    }
                }
            }
            Section("Description") {
                TextField("Short description", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
    }

    // MARK: - Save

    private var canSave: Bool {
        switch subtype {
        case .bodyMilestone:
            return Double(weightLbs) != nil
        case .pastCycle, .currentCycle:
            return !compoundName.trimmingCharacters(in: .whitespaces).isEmpty
        case .trainingPhase:
            return endDate >= startDate
        case .bloodworkDate:
            return true
        case .lifeEvent:
            return !note.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func save() {
        guard canSave else { return }
        guard let uidStr = try? AuthService.shared.currentUserId(),
              let uid = UUID(uuidString: uidStr) else {
            errorMessage = "You must be signed in to save pins."
            return
        }
        saving = true
        let event = buildEvent(userId: uid)
        Task {
            await JourneyEventService.shared.add(event)
            await MainActor.run {
                saving = false
                onSaved?(event)
                dismiss()
            }
        }
    }

    private func buildEvent(userId: UUID) -> JourneyEvent {
        var payload = JourneyEventPayload()
        var resolvedTimestamp = timestamp
        var resolvedDuration: Int?
        var resolvedTitle = title
        var resolvedDescription: String? = note.isEmpty ? nil : note
        let lane = subtype.lane

        switch subtype {
        case .bodyMilestone:
            payload.weightLbs = Double(weightLbs)
            payload.bodyFatPercent = Double(bodyFatPercent)
            payload.note = note.isEmpty ? nil : note
            resolvedTitle = payload.weightLbs.map { String(format: "%.1f lbs", $0) } ?? "Body milestone"
        case .pastCycle:
            payload.compoundName = compoundName
            payload.doseAmount = Double(doseAmount)
            payload.doseUnit = doseUnit
            payload.frequency = frequency
            payload.startDate = startDate
            payload.endDate = endDate
            payload.perceivedResults = perceivedResults.isEmpty ? nil : perceivedResults
            payload.sideEffects = sideEffectsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            payload.reasonStopped = reasonStoppedText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            resolvedTimestamp = startDate
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            resolvedDuration = max(0, days)
            resolvedTitle = compoundName
            resolvedDescription = perceivedResults.isEmpty ? nil : perceivedResults
        case .currentCycle:
            payload.compoundName = compoundName
            payload.doseAmount = Double(doseAmount)
            payload.doseUnit = doseUnit
            payload.frequency = frequency
            payload.schedule = schedule.isEmpty ? nil : schedule
            payload.startDate = startDate
            payload.plannedCycleWeeks = Int(plannedCycleWeeks)
            payload.vialsRemaining = Int(vialsRemaining)
            resolvedTimestamp = startDate
            if let weeks = payload.plannedCycleWeeks { resolvedDuration = weeks * 7 }
            resolvedTitle = "\(compoundName) (current)"
        case .trainingPhase:
            payload.phaseType = phaseType.rawValue
            payload.startDate = startDate
            payload.endDate = endDate
            resolvedTimestamp = startDate
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            resolvedDuration = max(0, days)
            resolvedTitle = phaseType.label
        case .bloodworkDate:
            resolvedTimestamp = drawDate
            resolvedTitle = "Bloodwork draw"
        case .lifeEvent:
            payload.lifeEventType = lifeEventType.rawValue
            payload.shortDescription = note.isEmpty ? nil : note
            resolvedTitle = lifeEventType.label
        }

        return JourneyEvent(
            userId: userId,
            lane: lane,
            timestamp: resolvedTimestamp,
            durationDays: resolvedDuration,
            title: resolvedTitle,
            description: resolvedDescription,
            sourceType: .manual,
            confidence: 1.0,
            payload: payload
        )
    }
}
