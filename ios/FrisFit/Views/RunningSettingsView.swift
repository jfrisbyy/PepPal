import SwiftUI

struct RunningSettingsView: View {
    @Bindable var runVM: RunningViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    unitsSection
                    audioCuesSection
                    gpsAccuracySection
                    runPreferencesSection
                    shoeManagementSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Running Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
            .sheet(isPresented: $runVM.showAddShoe) {
                AddShoeSheet(runVM: runVM)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "ruler", title: "Units")

            HStack {
                Text("Distance Unit")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Picker("Unit", selection: $runVM.settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Audio Cues

    private var audioCuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "speaker.wave.2.fill", title: "Audio Cues")

            VStack(spacing: 4) {
                Text("Announce Every")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(AudioCueInterval.allCases) { interval in
                            Button {
                                runVM.settings.audioCueInterval = interval
                            } label: {
                                Text(interval.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(runVM.settings.audioCueInterval == interval ? .black : PepTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(runVM.settings.audioCueInterval == interval ? accentColor : PepTheme.elevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            }

            Toggle("Announce Pace", isOn: $runVM.settings.announcePace)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)

            Toggle("Announce Heart Rate", isOn: $runVM.settings.announceHeartRate)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)

            Toggle("Announce Distance", isOn: $runVM.settings.announceDistance)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - GPS Accuracy

    private var gpsAccuracySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "location.fill", title: "GPS Accuracy")

            VStack(spacing: 8) {
                ForEach(GPSAccuracy.allCases) { level in
                    let isSelected = runVM.settings.gpsAccuracy == level
                    Button {
                        runVM.settings.gpsAccuracy = level
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: level.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(isSelected ? accentColor : PepTheme.textSecondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(level.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(accentColor)
                            }
                        }
                        .padding(10)
                        .background(isSelected ? accentColor.opacity(0.08) : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Preferences

    private var runPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "gearshape.fill", title: "Run Preferences")

            Toggle("Auto-Pause", isOn: $runVM.settings.autoPause)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)

            HStack {
                Text("Countdown Timer")
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Picker("Countdown", selection: $runVM.settings.countdownSeconds) {
                    Text("Off").tag(0)
                    Text("3s").tag(3)
                    Text("5s").tag(5)
                    Text("10s").tag(10)
                }
                .pickerStyle(.menu)
                .tint(accentColor)
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Shoe Management

    private var shoeManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(icon: "shoe.fill", title: "Shoes")
                Spacer()
                Button {
                    runVM.showAddShoe = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(accentColor)
                }
            }

            if runVM.shoes.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "shoe.fill")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No shoes added yet")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(runVM.shoes) { shoe in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(shoe.isRetired ? PepTheme.textSecondary.opacity(0.1) : shoe.statusColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "shoe.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(shoe.isRetired ? PepTheme.textSecondary : shoe.statusColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("\(shoe.brand) \(shoe.name)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(shoe.isRetired ? PepTheme.textSecondary : PepTheme.textPrimary)
                                if shoe.isRetired {
                                    Text("RETIRED")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(String(format: "%.0f / %.0f mi", shoe.totalMiles, shoe.retirementMiles))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        Spacer()

                        Menu {
                            if !shoe.isRetired {
                                Button("Retire Shoe") {
                                    runVM.retireShoe(shoe.id)
                                }
                            }
                            Button("Delete", role: .destructive) {
                                runVM.deleteShoe(shoe.id)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(PepTheme.textSecondary)
                                .frame(width: 30, height: 30)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accentColor)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}

// MARK: - Add Shoe Sheet

struct AddShoeSheet: View {
    @Bindable var runVM: RunningViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var retirementMiles: Double = 400

    private let accentColor = Color(red: 0.0, green: 0.9, blue: 1.0)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brand")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("Nike, Brooks, etc.", text: $brand)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("Pegasus 41, Ghost 16, etc.", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Retirement at")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                        Text("\(Int(retirementMiles)) mi")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                    Slider(value: $retirementMiles, in: 100...600, step: 25)
                        .tint(accentColor)
                }

                Spacer()
            }
            .padding()
            .appBackground()
            .navigationTitle("Add Shoe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let shoe = RunningShoe(name: name, brand: brand, retirementMiles: retirementMiles)
                        runVM.addShoe(shoe)
                        dismiss()
                    }
                    .foregroundStyle(accentColor)
                    .disabled(name.isEmpty || brand.isEmpty)
                }
            }
        }
    }
}
