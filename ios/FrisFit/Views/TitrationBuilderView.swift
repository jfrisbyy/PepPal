import SwiftUI

struct TitrationBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    let protocolId: UUID
    let compoundName: String
    let onSave: (TitrationSchedule) -> Void

    @State private var steps: [TitrationScheduleStep]
    @State private var startDate: Date
    @State private var remindersEnabled: Bool
    @State private var reminderTime: Date
    @State private var autoAdvance: Bool
    @State private var showPermissionAlert: Bool = false

    private var unit: CompoundUnit { CompoundUnitHelper.unit(for: compoundName) }

    init(
        protocolId: UUID,
        compoundName: String,
        existing: TitrationSchedule? = nil,
        seedFromTemplate: TitrationTemplate? = nil,
        onSave: @escaping (TitrationSchedule) -> Void
    ) {
        self.protocolId = protocolId
        self.compoundName = compoundName
        self.onSave = onSave

        if let existing {
            _steps = State(initialValue: existing.sortedSteps)
            _startDate = State(initialValue: existing.startDate)
            _remindersEnabled = State(initialValue: existing.remindersEnabled)
            var comps = DateComponents()
            comps.hour = existing.reminderHour
            comps.minute = existing.reminderMinute
            _reminderTime = State(initialValue: Calendar.current.date(from: comps) ?? Date())
            _autoAdvance = State(initialValue: existing.autoAdvanceDose)
        } else if let tmpl = seedFromTemplate {
            let mapped = tmpl.steps.map {
                TitrationScheduleStep(week: $0.week, doseMcg: $0.doseMcg, label: $0.label)
            }
            _steps = State(initialValue: mapped)
            _startDate = State(initialValue: Date())
            _remindersEnabled = State(initialValue: true)
            _reminderTime = State(initialValue: _makeTime(hour: 9, minute: 0))
            _autoAdvance = State(initialValue: true)
        } else {
            let defaultStart: Double = CompoundUnitHelper.unit(for: compoundName) == .mg ? 1000 : 250
            _steps = State(initialValue: [TitrationScheduleStep(week: 1, doseMcg: defaultStart, label: "Start")])
            _startDate = State(initialValue: Date())
            _remindersEnabled = State(initialValue: true)
            _reminderTime = State(initialValue: _makeTime(hour: 9, minute: 0))
            _autoAdvance = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "pills.fill").foregroundStyle(PepTheme.teal)
                        Text(compoundName)
                            .font(.system(.subheadline, weight: .semibold))
                        Spacer()
                        Text("Units: \(unit.rawValue)")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .tint(PepTheme.teal)
                }

                Section("Steps") {
                    ForEach($steps) { $step in
                        stepRow($step)
                    }
                    .onMove { indices, newOffset in
                        steps.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indexSet in
                        steps.remove(atOffsets: indexSet)
                    }

                    Button {
                        addStep()
                    } label: {
                        Label("Add Step", systemImage: "plus.circle.fill")
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                Section("Reminders") {
                    Toggle("Step-up alerts", isOn: $remindersEnabled)
                        .tint(PepTheme.teal)
                    if remindersEnabled {
                        DatePicker("Alert time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .tint(PepTheme.teal)
                    }
                    Toggle("Auto-update dose when step starts", isOn: $autoAdvance)
                        .tint(PepTheme.teal)
                }

                if !steps.isEmpty {
                    Section("Preview") {
                        ForEach(sortedPreview) { step in
                            HStack {
                                Text("Week \(step.week)")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(CompoundUnitHelper.displayDoseShort(step.doseMcg, for: compoundName))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                Spacer()
                                Text(previewDateString(for: step))
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Titration Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(steps.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .alert("Enable Notifications", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("To get titration step-up alerts, enable notifications in Settings.")
            }
        }
    }

    private var sortedPreview: [TitrationScheduleStep] {
        steps.sorted(by: { $0.week < $1.week })
    }

    private func stepRow(_ step: Binding<TitrationScheduleStep>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Week")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    Stepper(value: step.week, in: 1...104) {
                        Text("\(step.week.wrappedValue)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: 130, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose (\(unit.rawValue))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("Dose", value: Binding(
                        get: { CompoundUnitHelper.fromMcg(step.doseMcg.wrappedValue, for: compoundName) },
                        set: { step.doseMcg.wrappedValue = CompoundUnitHelper.toMcg($0, for: compoundName) }
                    ), format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            TextField("Label (optional) e.g. Bump 1, Target", text: step.label)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func addStep() {
        let lastWeek = steps.map(\.week).max() ?? 0
        let lastDose = steps.last?.doseMcg ?? (unit == .mg ? 1000 : 250)
        let nextDose = lastDose * 2
        steps.append(TitrationScheduleStep(week: lastWeek + 4, doseMcg: nextDose, label: ""))
    }

    private func previewDateString(for step: TitrationScheduleStep) -> String {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: (step.week - 1) * 7, to: cal.startOfDay(for: startDate)) ?? startDate
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    private func save() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: reminderTime)
        let schedule = TitrationSchedule(
            protocolId: protocolId,
            compoundName: compoundName,
            startDate: cal.startOfDay(for: startDate),
            steps: steps.sorted(by: { $0.week < $1.week }),
            remindersEnabled: remindersEnabled,
            reminderHour: comps.hour ?? 9,
            reminderMinute: comps.minute ?? 0,
            autoAdvanceDose: autoAdvance
        )
        if remindersEnabled {
            Task {
                let granted = await TitrationScheduleStore.shared.requestAuthorizationIfNeeded()
                await MainActor.run {
                    if !granted {
                        showPermissionAlert = true
                    }
                    onSave(schedule)
                    dismiss()
                }
            }
        } else {
            onSave(schedule)
            dismiss()
        }
    }
}

private func _makeTime(hour: Int, minute: Int) -> Date {
    var c = DateComponents()
    c.hour = hour
    c.minute = minute
    return Calendar.current.date(from: c) ?? Date()
}
