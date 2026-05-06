import SwiftUI

struct CyclingSettingsView: View {
    @Bindable var cyclingVM: CyclingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddBike: Bool = false
    @State private var newBikeName: String = ""
    @State private var newBikeType: String = "Road"

    private let accentColor = Color(red: 0.95, green: 0.45, blue: 0.0)
    private let bikeTypes = ["Road", "Gravel", "Mountain", "Hybrid", "TT/Tri", "Track", "Indoor"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    statsCard
                    preferencesCard
                    audioCard
                    bikeGarageCard
                    aboutCard
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Cycling Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
            .sheet(isPresented: $showAddBike) {
                addBikeSheet
                    .presentationDetents([.height(360)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Your saddle life", title: "By the Numbers", accent: accentColor)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                statTile(value: String(format: "%.0f", cyclingVM.totalMilesAllTime), label: "MILES RIDDEN", color: accentColor)
                statTile(value: "\(cyclingVM.totalRidesAllTime)", label: "RIDES LOGGED", color: .green)
                statTile(value: String(format: "%.0f", cyclingVM.totalElevationAllTime), label: "FT CLIMBED", color: .orange)
                statTile(value: "\(cyclingVM.bikes.filter { !$0.isRetired }.count)", label: "BIKES IN GARAGE", color: PepTheme.violet)
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Display", title: "Preferences", accent: accentColor)

            settingRow(label: "Speed Unit") {
                Picker("", selection: $cyclingVM.settings.speedUnit) {
                    ForEach(SpeedUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            divider

            settingRow(label: "Distance Unit") {
                Picker("", selection: $cyclingVM.settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            divider

            toggleRow(
                label: "Auto-Pause",
                blurb: "Pause the timer automatically when you stop moving.",
                isOn: $cyclingVM.settings.autoPause
            )

            divider

            toggleRow(
                label: "Show Power Data",
                blurb: "Surface watts and FTP-style metrics in ride detail.",
                isOn: $cyclingVM.settings.showPowerData
            )
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Audio

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Hands-free", title: "Audio Cues", accent: accentColor)

            settingRow(label: "Announce Every") {
                Picker("", selection: $cyclingVM.settings.audioAnnounceInterval) {
                    ForEach(AudioCueInterval.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(accentColor)
            }

            divider
            toggleRow(label: "Announce Speed", blurb: nil, isOn: $cyclingVM.settings.announceSpeed)
            divider
            toggleRow(label: "Announce Distance", blurb: nil, isOn: $cyclingVM.settings.announceDistance)
            divider
            toggleRow(label: "Announce Heart Rate", blurb: nil, isOn: $cyclingVM.settings.announceHeartRate)
        }
        .editorialCard(accent: accentColor)
    }

    // MARK: - Bike Garage

    private var bikeGarageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Garage",
                title: "Your Bikes",
                accent: accentColor,
                trailing: AnyView(
                    Button {
                        showAddBike = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 11))
                            Text("ADD")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(accentColor)
                    }
                )
            )

            if cyclingVM.bikes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 24))
                        .foregroundStyle(accentColor.opacity(0.4))
                    Text("No bikes yet")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Add a bike and we'll track miles and service intervals automatically.")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 10) {
                    ForEach(cyclingVM.bikes) { bike in
                        bikeRow(bike)
                    }
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func bikeRow(_ bike: Bike) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(bike.isRetired ? PepTheme.textSecondary.opacity(0.10) : bike.maintenanceStatusColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bicycle")
                        .font(.system(size: 15))
                        .foregroundStyle(bike.isRetired ? PepTheme.textSecondary : bike.maintenanceStatusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(bike.name)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(bike.isRetired ? PepTheme.textSecondary : PepTheme.textPrimary)
                        Text(bike.type.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.10))
                            .clipShape(Capsule())
                        if bike.isRetired {
                            Text("RETIRED")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    Text(String(format: "%.0f mi total · %.0f mi to service", bike.totalMiles, max(0, bike.maintenanceIntervalMiles - bike.milesSinceLastMaintenance)))
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()
            }

            if !bike.isRetired {
                HStack(spacing: 8) {
                    actionPill(icon: "wrench.fill", label: "SERVICED", color: .green) {
                        cyclingVM.markMaintenance(bike.id)
                    }
                    actionPill(icon: "archivebox", label: "RETIRE", color: .orange) {
                        cyclingVM.retireBike(bike.id)
                    }
                    actionPill(icon: "trash", label: "DELETE", color: .red) {
                        cyclingVM.deleteBike(bike.id)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    actionPill(icon: "trash", label: "DELETE", color: .red) {
                        cyclingVM.deleteBike(bike.id)
                    }
                }
            }
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.35))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func actionPill(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Bike Sheet

    private var addBikeSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                EditorialSectionHeading(kicker: "New ride", title: "Add a Bike", accent: accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    TextField("e.g. Tarmac SL7", text: $newBikeName)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(12)
                        .background(PepTheme.elevated.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("TYPE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(PepTheme.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(bikeTypes, id: \.self) { type in
                                Button {
                                    newBikeType = type
                                } label: {
                                    Text(type)
                                        .font(.system(size: 12, weight: .semibold, design: .serif))
                                        .foregroundStyle(newBikeType == type ? .black : PepTheme.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(newBikeType == type ? accentColor : PepTheme.elevated)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)
                }

                Spacer()

                EditorialPrimaryButton("Add Bike", icon: "plus.circle.fill", accent: accentColor) {
                    let trimmed = newBikeName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    cyclingVM.addBike(Bike(name: trimmed, type: newBikeType))
                    newBikeName = ""
                    newBikeType = "Road"
                    showAddBike = false
                }
                .opacity(newBikeName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                .disabled(newBikeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .appBackground(accent: accentColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newBikeName = ""
                        newBikeType = "Road"
                        showAddBike = false
                    }
                    .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BUILT FOR")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(PepTheme.textSecondary)
            Text("Weekend warriors, gravel grinders, indoor trainers, and everyone in between. Your rides, your routes, your bikes — kept tidy and quietly tracked.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(PepTheme.cardSurface.opacity(0.5))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.glassBorderTop.opacity(0.5))
            .frame(height: 0.5)
    }

    private func settingRow<Trailing: View>(label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }

    private func toggleRow(label: String, blurb: String?, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                if let blurb {
                    Text(blurb)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accentColor)
        }
        .padding(.vertical, 4)
    }
}
