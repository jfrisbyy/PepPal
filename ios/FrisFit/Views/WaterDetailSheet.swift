import SwiftUI

struct WaterDetailSheet: View {
    @Bindable var viewModel: WaterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var goalMl: Double = 2500
    @State private var editingEntry: WaterEntry?

    private let date: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    unitSection
                    goalSection
                    logsSection
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { goalMl = Double(viewModel.dailyGoalMl) }
            .sheet(item: $editingEntry) { entry in
                EditWaterEntrySheet(entry: entry, viewModel: viewModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var unitSection: some View {
        HStack {
            Label("Units", systemImage: "ruler")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Picker("Units", selection: Binding(
                get: { viewModel.unit },
                set: { viewModel.setUnit($0) }
            )) {
                Text("oz").tag(WaterViewModel.Unit.oz)
                Text("ml").tag(WaterViewModel.Unit.ml)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var goalSection: some View {
        let isOz = viewModel.unit == .oz
        let ozPerMl = 1.0 / 29.5735
        let mlPerOz = 29.5735
        let gallonOz = 128.0
        let literMl = 1000.0

        let sliderMin: Double = isOz ? 32 : 1000
        let sliderMax: Double = isOz ? 256 : 6000
        let step: Double = isOz ? 1 : 100

        let goalInUnit: Double = isOz ? goalMl * ozPerMl : goalMl
        let unitLabel = isOz ? "oz" : "ml"

        let markerLabel: String = {
            if isOz {
                let gallons = goalInUnit / gallonOz
                if gallons >= 0.99 {
                    let rounded = (gallons * 4).rounded() / 4
                    if abs(gallons - rounded) < 0.05 && rounded.truncatingRemainder(dividingBy: 0.25) == 0 {
                        if rounded == rounded.rounded() {
                            return "\(Int(rounded)) gal"
                        } else {
                            return String(format: "%.2f gal", rounded)
                        }
                    }
                    return String(format: "%.2f gal", gallons)
                }
                return ""
            } else {
                let liters = goalInUnit / literMl
                if liters >= 1 {
                    let rounded = (liters * 10).rounded() / 10
                    return String(format: "%.1f L", rounded)
                }
                return ""
            }
        }()

        let presets: [Double] = isOz ? [64, 96, 128, 160] : [2000, 2500, 3000, 3500]

        let sliderBinding = Binding<Double>(
            get: { isOz ? goalMl * ozPerMl : goalMl },
            set: { newVal in
                goalMl = isOz ? newVal * mlPerOz : newVal
            }
        )

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Daily Goal", systemImage: "target")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                if !markerLabel.isEmpty {
                    Text(markerLabel)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.blue.opacity(0.14), in: .capsule)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(goalInUnit.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.blue)
                Text(unitLabel)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Slider(value: sliderBinding, in: sliderMin...sliderMax, step: step)
                .tint(PepTheme.blue)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    let presetMl = isOz ? preset * mlPerOz : preset
                    let selected = Int(goalMl.rounded()) == Int(presetMl.rounded())
                    Button {
                        goalMl = presetMl
                    } label: {
                        Text(isOz ? "\(Int(preset))oz" : "\(Int(preset))ml")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(selected ? .white : PepTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? PepTheme.blue : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                viewModel.setGoal(Int(goalMl))
                dismiss()
            } label: {
                Text("Save Goal")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PepTheme.blue, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(Int(goalMl) == viewModel.dailyGoalMl)
            .opacity(Int(goalMl) == viewModel.dailyGoalMl ? 0.5 : 1)
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Logs", systemImage: "list.bullet")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text("\(viewModel.totalMl(for: date))ml")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            let entries = viewModel.entries(for: date).sorted { $0.loggedAt > $1.loggedAt }

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "drop")
                        .font(.title2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No water logged yet today")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        logRow(entry)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(WaterPreset.allCases) { preset in
                    Button {
                        viewModel.add(amountMl: preset.rawValue)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text("+\(preset.oz)oz")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(PepTheme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(PepTheme.blue.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func logRow(_ entry: WaterEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PepTheme.blue)
                    .frame(width: 28, height: 28)
                    .background(PepTheme.blue.opacity(0.12))
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.amountMl)ml")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(entry.loggedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Text("\(Int(Double(entry.amountMl) / 29.5735)) oz")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PepTheme.elevated.opacity(0.6))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.remove(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct EditWaterEntrySheet: View {
    let entry: WaterEntry
    @Bindable var viewModel: WaterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountMl: Double = 250
    @State private var loggedAt: Date = Date()

    private var presetButtons: some View {
        HStack(spacing: 8) {
            ForEach([100, 250, 355, 500, 750], id: \.self) { preset in
                Button {
                    amountMl = Double(preset)
                } label: {
                    Text("\(preset)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("\(Int(amountMl))ml")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.blue)
                    Text("\(Int(amountMl / 29.5735)) oz")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.top, 8)

                Slider(value: $amountMl, in: 50...1500, step: 25)
                    .tint(PepTheme.blue)
                    .padding(.horizontal)

                presetButtons

                DatePicker("Logged at", selection: $loggedAt)
                    .datePickerStyle(.compact)
                    .padding(14)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))

                Spacer()

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        viewModel.remove(entry)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.12), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.update(entry, amountMl: Int(amountMl), loggedAt: loggedAt)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PepTheme.blue, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .appBackground()
            .navigationTitle("Edit Water Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .onAppear {
                amountMl = Double(entry.amountMl)
                loggedAt = entry.loggedAt
            }
        }
    }
}
