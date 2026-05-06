import SwiftUI
import UserNotifications
import UIKit

struct SmartNotificationSettingsView: View {
    @State private var store = SmartNotificationStore.shared
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var quietStartDate: Date = Date()
    @State private var quietEndDate: Date = Date()
    @State private var didSendTest: Bool = false

    var body: some View {
        Form {
            // System permission banner
            Section {
                permissionRow
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.settings.masterEnabled },
                    set: { newValue in
                        store.settings.masterEnabled = newValue
                        Task { await SmartNotificationEngine.shared.replanAll() }
                    }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Notifications")
                                .font(.body)
                            Text("Master switch for everything below")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }

            Section("Categories") {
                ForEach(SmartNotificationCategory.allCases) { category in
                    Toggle(isOn: Binding(
                        get: { store.settings.enabledCategories.contains(category) },
                        set: { newValue in
                            if newValue {
                                store.settings.enabledCategories.insert(category)
                            } else {
                                store.settings.enabledCategories.remove(category)
                            }
                            Task { await SmartNotificationEngine.shared.replanAll() }
                        }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.body)
                                Text(category.blurb)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        } icon: {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.accent)
                                .frame(width: 22)
                        }
                    }
                    .disabled(!store.settings.masterEnabled)
                }
            }

            Section {
                DatePicker("Quiet hours start", selection: $quietStartDate, displayedComponents: .hourAndMinute)
                    .onChange(of: quietStartDate) { _, newValue in
                        store.settings.quietStartHour = Calendar.current.component(.hour, from: newValue)
                        Task { await SmartNotificationEngine.shared.replanAll() }
                    }
                DatePicker("Quiet hours end", selection: $quietEndDate, displayedComponents: .hourAndMinute)
                    .onChange(of: quietEndDate) { _, newValue in
                        store.settings.quietEndHour = Calendar.current.component(.hour, from: newValue)
                        Task { await SmartNotificationEngine.shared.replanAll() }
                    }
            } header: {
                Text("Quiet hours")
            } footer: {
                Text("Notifications scheduled inside this window are paused or pushed to the next opening.")
            }

            Section {
                Picker("Daily limit", selection: Binding(
                    get: { store.settings.dailyCap ?? -1 },
                    set: { newValue in
                        store.settings.dailyCap = newValue == -1 ? nil : newValue
                        Task { await SmartNotificationEngine.shared.replanAll() }
                    }
                )) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                    Text("8").tag(8)
                    Text("Unlimited").tag(-1)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Frequency cap")
            } footer: {
                Text("Across all categories. We'll keep the most important ones (social, supplements, training) when we have to choose.")
            }

            Section {
                preview
            } header: {
                Text("Preview")
            }

            Section {
                Button {
                    Task {
                        await SmartNotificationEngine.shared.sendTest()
                        await MainActor.run {
                            didSendTest = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                } label: {
                    HStack {
                        Label("Send test notification", systemImage: "paperplane.fill")
                        Spacer()
                        if didSendTest {
                            Text("Sent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await refreshAuth()
            quietStartDate = hourDate(store.settings.quietStartHour)
            quietEndDate = hourDate(store.settings.quietEndHour)
        }
    }

    // MARK: - Permission

    private var permissionRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: permissionIcon)
                .font(.title3)
                .foregroundStyle(permissionColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(permissionTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(permissionBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if authStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if authStatus != .authorized && authStatus != .provisional {
                Button("Enable") {
                    Task {
                        _ = await SmartNotificationEngine.shared.requestAuthorization()
                        await refreshAuth()
                        await SmartNotificationEngine.shared.replanAll()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var permissionIcon: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "checkmark.seal.fill"
        case .denied: return "exclamationmark.triangle.fill"
        default: return "bell.slash.fill"
        }
    }

    private var permissionColor: Color {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .orange
        default: return PepTheme.textSecondary
        }
    }

    private var permissionTitle: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "Notifications allowed"
        case .denied: return "Notifications blocked"
        default: return "Permission needed"
        }
    }

    private var permissionBody: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "We can deliver smart nudges to you."
        case .denied: return "Open iOS Settings to re-enable notifications."
        default: return "Allow notifications to receive timely reminders."
        }
    }

    private func refreshAuth() async {
        authStatus = await SmartNotificationEngine.shared.authorizationStatus()
    }

    // MARK: - Preview card

    private var preview: some View {
        let sample = SmartNotificationCategory.training
        return HStack(spacing: 12) {
            Rectangle()
                .fill(sample.accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: sample.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(sample.accent)
                    Text("EPTI · NOW")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                }
                Text("Training window opens soon")
                    .font(.system(size: 14, weight: .semibold))
                Text("Your session usually starts around now. Want to get loose?")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func hourDate(_ hour: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}
