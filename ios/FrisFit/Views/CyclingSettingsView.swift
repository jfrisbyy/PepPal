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
            List {
                unitsSection
                audioSection
                bikesSection
            }
            .scrollContentBackground(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("Cycling Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
            .alert("Add Bike", isPresented: $showAddBike) {
                TextField("Bike Name", text: $newBikeName)
                Button("Cancel", role: .cancel) {
                    newBikeName = ""
                    newBikeType = "Road"
                }
                Button("Add") {
                    guard !newBikeName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let bike = Bike(name: newBikeName, type: newBikeType)
                    cyclingVM.addBike(bike)
                    newBikeName = ""
                    newBikeType = "Road"
                }
            } message: {
                Text("Enter a name for your bike")
            }
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section {
            Picker("Speed Unit", selection: $cyclingVM.settings.speedUnit) {
                ForEach(SpeedUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }

            Picker("Distance Unit", selection: $cyclingVM.settings.distanceUnit) {
                ForEach(DistanceUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }

            Toggle("Auto-Pause", isOn: $cyclingVM.settings.autoPause)
                .tint(accentColor)

            Toggle("Show Power Data", isOn: $cyclingVM.settings.showPowerData)
                .tint(accentColor)
        } header: {
            Text("Preferences")
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        Section {
            Picker("Announce Every", selection: $cyclingVM.settings.audioAnnounceInterval) {
                ForEach(AudioCueInterval.allCases) { interval in
                    Text(interval.rawValue).tag(interval)
                }
            }

            Toggle("Announce Speed", isOn: $cyclingVM.settings.announceSpeed)
                .tint(accentColor)

            Toggle("Announce Distance", isOn: $cyclingVM.settings.announceDistance)
                .tint(accentColor)

            Toggle("Announce Heart Rate", isOn: $cyclingVM.settings.announceHeartRate)
                .tint(accentColor)
        } header: {
            Text("Audio Cues")
        }
    }

    // MARK: - Bikes

    private var bikesSection: some View {
        Section {
            ForEach(cyclingVM.bikes) { bike in
                bikeRow(bike)
            }

            Button {
                showAddBike = true
            } label: {
                Label("Add Bike", systemImage: "plus.circle.fill")
                    .foregroundStyle(accentColor)
            }
        } header: {
            Text("Bike Garage")
        }
    }

    private func bikeRow(_ bike: Bike) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bike.isRetired ? PepTheme.textSecondary.opacity(0.12) : bike.maintenanceStatusColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "bicycle")
                    .font(.system(size: 14))
                    .foregroundStyle(bike.isRetired ? PepTheme.textSecondary : bike.maintenanceStatusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bike.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(bike.isRetired ? PepTheme.textSecondary : PepTheme.textPrimary)
                    Text(bike.type)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    if bike.isRetired {
                        Text("RETIRED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(String(format: "%.0f mi total", bike.totalMiles))
                    .font(.system(size: 11))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()
        }
        .swipeActions(edge: .trailing) {
            if !bike.isRetired {
                Button {
                    cyclingVM.retireBike(bike.id)
                } label: {
                    Label("Retire", systemImage: "archivebox")
                }
                .tint(.orange)

                Button {
                    cyclingVM.markMaintenance(bike.id)
                } label: {
                    Label("Service", systemImage: "wrench.fill")
                }
                .tint(.green)
            }

            Button(role: .destructive) {
                cyclingVM.deleteBike(bike.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
