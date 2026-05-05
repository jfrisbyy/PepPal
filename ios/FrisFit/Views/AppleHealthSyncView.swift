import SwiftUI
import HealthKit

struct AppleHealthSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var healthKit = HealthKitService.shared
    @State private var cloud = HealthCloudSyncService.shared
    @State private var lastSynced: Date? = nil
    @State private var isSyncing: Bool = false
    @State private var showDeleteConfirm: Bool = false

    @AppStorage("health.sync.weight") private var syncWeight: Bool = true
    @AppStorage("health.sync.hr") private var syncHR: Bool = true
    @AppStorage("health.sync.hrv") private var syncHRV: Bool = true
    @AppStorage("health.sync.sleep") private var syncSleep: Bool = true
    @AppStorage("health.sync.steps") private var syncSteps: Bool = true
    @AppStorage("health.sync.energy") private var syncEnergy: Bool = true
    @AppStorage("health.sync.bodyFat") private var syncBodyFat: Bool = true
    @AppStorage("health.sync.writeDoses") private var writeDoses: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                if !healthKit.isAvailable {
                    unavailableCard
                } else if !healthKit.isAuthorized {
                    connectCard
                } else {
                    statusCard
                    cloudSyncCard
                    metricsCard
                    writebackCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.red.opacity(0.2), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.red, .pink)
                    .symbolRenderingMode(.palette)
            }
            Text("Connect Apple Health")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Auto-sync weight, HR, HRV, sleep and more into your protocol trends. No more manual logging.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 10)
    }

    private var unavailableCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PepTheme.amber)
                    .font(.system(size: 22))
                Text("HealthKit unavailable")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("This device doesn't support Apple Health, or it's disabled. Try on a physical iPhone.")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var connectCard: some View {
        GlassCard(accent: .red) {
            VStack(spacing: 14) {
                bulletRow("scalemass.fill", "Weight & body composition", .blue)
                bulletRow("heart.fill", "Heart rate & HRV", .red)
                bulletRow("bed.double.fill", "Sleep duration & stages", .purple)
                bulletRow("figure.walk", "Steps & active energy", .green)

                Button {
                    Task {
                        isSyncing = true
                        await healthKit.requestAuthorization()
                        lastSynced = Date()
                        isSyncing = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSyncing { ProgressView().tint(.white) }
                        Image(systemName: "heart.fill")
                        Text(isSyncing ? "Connecting…" : "Connect Apple Health")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)

                Text("Permissions are requested through iOS. You can change them anytime in Settings → Health.")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func bulletRow(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15), in: .circle)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
        }
    }

    private var statusCard: some View {
        GlassCard(accent: .green) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(lastSyncedLabel)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            isSyncing = true
                            await healthKit.fetchAllData()
                            lastSynced = Date()
                            isSyncing = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isSyncing { ProgressView().controlSize(.mini) }
                            Text(isSyncing ? "Syncing" : "Sync now")
                                .font(.system(.caption, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PepTheme.teal, in: .capsule)
                    }
                    .disabled(isSyncing)
                }

                liveValueRow
            }
        }
    }

    private var liveValueRow: some View {
        HStack(spacing: 10) {
            metricPill("Weight", value: weightText, icon: "scalemass.fill", color: .blue)
            metricPill("HR", value: hrText, icon: "heart.fill", color: .red)
            metricPill("HRV", value: hrvText, icon: "waveform.path.ecg", color: .pink)
            metricPill("Sleep", value: sleepText, icon: "bed.double.fill", color: .purple)
        }
    }

    private func metricPill(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var metricsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SYNCED METRICS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                toggleRow("scalemass.fill", "Weight", .blue, $syncWeight)
                toggleRow("percent", "Body Fat %", .indigo, $syncBodyFat)
                toggleRow("heart.fill", "Resting heart rate", .red, $syncHR)
                toggleRow("waveform.path.ecg", "Heart rate variability", .pink, $syncHRV)
                toggleRow("bed.double.fill", "Sleep", .purple, $syncSleep)
                toggleRow("figure.walk", "Steps", .green, $syncSteps)
                toggleRow("flame.fill", "Active energy", .orange, $syncEnergy)
            }
        }
    }

    private var writebackCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("SEND TO HEALTH")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(PepTheme.textSecondary)
                Toggle(isOn: $writeDoses) {
                    HStack(spacing: 10) {
                        Image(systemName: "syringe.fill")
                            .foregroundStyle(PepTheme.teal)
                            .frame(width: 26, height: 26)
                            .background(PepTheme.teal.opacity(0.15), in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log doses as mindful sessions")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("Each injection appears in the Health Mindfulness category.")
                                .font(.caption2)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .tint(PepTheme.teal)
            }
        }
    }

    private func toggleRow(_ icon: String, _ label: String, _ color: Color, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 26, height: 26)
                    .background(color.opacity(0.15), in: .circle)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.textPrimary)
            }
        }
        .tint(PepTheme.teal)
    }

    private var cloudSyncCard: some View {
        GlassCard(accent: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 30, height: 30)
                        .background(Color.blue.opacity(0.15), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloud sync")
                            .font(.system(.headline, weight: .bold))
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(cloudStatusLabel)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    if cloud.isSyncing {
                        ProgressView().controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    statPill("\(cloud.daysStored)", "days")
                    statPill("\(cloud.workoutsStored)", "workouts")
                }

                Text("Your Health snapshots, sleep, and workouts are encrypted and stored in your account so summaries, AI briefings, and offline cards always have your latest numbers.")
                    .font(.caption2)
                    .foregroundStyle(PepTheme.textSecondary)

                HStack(spacing: 10) {
                    Button {
                        Task { await cloud.resyncRecent(days: 90) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Re-sync 90 days").fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PepTheme.teal, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(cloud.isSyncing)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete cloud data").fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(cloud.isSyncing)
                }
            }
        }
        .task { await cloud.refreshState() }
        .alert("Delete cloud Health data?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await cloud.deleteAllCloudData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every Apple Health snapshot, series point, sleep night, and workout we've stored for you. Local cache and Apple Health itself are untouched.")
        }
    }

    private func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(PepTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private var cloudStatusLabel: String {
        guard let last = cloud.lastSyncedAt else { return "Waiting for first sync" }
        let rf = RelativeDateTimeFormatter()
        rf.unitsStyle = .short
        return "Uploaded \(rf.localizedString(for: last, relativeTo: Date()))"
    }

    private var lastSyncedLabel: String {
        guard let lastSynced else { return "Ready to sync" }
        let rf = RelativeDateTimeFormatter()
        rf.unitsStyle = .short
        return "Last synced \(rf.localizedString(for: lastSynced, relativeTo: Date()))"
    }

    private var weightText: String {
        guard let w = healthKit.bodyWeight else { return "—" }
        return String(format: "%.1f", w)
    }
    private var hrText: String {
        guard let rhr = healthKit.restingHeartRate, rhr > 0 else { return "—" }
        return "\(Int(rhr))"
    }
    private var hrvText: String {
        guard let hrv = healthKit.hrv, hrv > 0 else { return "—" }
        return "\(Int(hrv))"
    }
    private var sleepText: String {
        guard healthKit.sleepHours > 0 else { return "—" }
        return String(format: "%.1fh", healthKit.sleepHours)
    }
}
