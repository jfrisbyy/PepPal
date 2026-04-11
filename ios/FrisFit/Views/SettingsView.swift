import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ProfileViewModel
    @State private var showDeleteConfirm: Bool = false
    @State private var showLogOutConfirm: Bool = false
    @State private var appearanceManager = AppearanceManager.shared
    @State private var healthKit = HealthKitService.shared
    @State private var reminderManager = ReminderManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                unitsSection
                timerSection
                healthKitSection
                healthRemindersSection
                activityRemindersSection
                socialNotificationsSection
                streakSection
                appearanceSection
                accountSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { }
        } message: {
            Text("This will permanently delete your account and all data. This action cannot be undone.")
        }
        .alert("Log Out", isPresented: $showLogOutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                Task {
                    try? await AuthService.shared.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }

    private var unitsSection: some View {
        SettingsCard(title: "Units") {
            HStack {
                Label("Weight Unit", systemImage: "scalemass")
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Picker("", selection: $viewModel.weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    private var timerSection: some View {
        SettingsCard(title: "Workout") {
            HStack {
                Label("Default Rest Timer", systemImage: "timer")
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Menu {
                    ForEach([30, 60, 90, 120, 180], id: \.self) { seconds in
                        Button("\(seconds)s") {
                            viewModel.defaultRestSeconds = seconds
                        }
                    }
                } label: {
                    Text("\(viewModel.defaultRestSeconds)s")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
    }

    private var healthRemindersSection: some View {
        SettingsCard(title: "Health Reminders") {
            VStack(spacing: 0) {
                if reminderManager.authorizationDenied {
                    NotificationDeniedBanner()
                    Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 8)
                }

                ReminderToggleRow(
                    category: .dose,
                    isEnabled: $reminderManager.doseEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.textSecondary)
                            Text("Automatically scheduled from your active protocol compounds.")
                                .font(.system(size: 11))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }

                NotificationDivider()

                ReminderToggleRow(
                    category: .bloodwork,
                    isEnabled: $reminderManager.bloodworkEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    VStack(spacing: 8) {
                        ReminderIntervalPicker(label: "Frequency", interval: $reminderManager.bloodworkInterval)
                        ReminderTimePicker(label: "Reminder Time", icon: "clock", time: $reminderManager.bloodworkTime)
                    }
                }

                NotificationDivider()

                ReminderToggleRow(
                    category: .weighIn,
                    isEnabled: $reminderManager.weighInEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    VStack(spacing: 8) {
                        ReminderDayPicker(label: "Day", day: $reminderManager.weighInDay)
                        ReminderTimePicker(label: "Time", icon: "clock", time: $reminderManager.weighInTime)
                    }
                }
            }
        }
    }

    private var activityRemindersSection: some View {
        SettingsCard(title: "Activity Reminders") {
            VStack(spacing: 0) {
                ReminderToggleRow(
                    category: .workout,
                    isEnabled: $reminderManager.workoutEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    ReminderTimePicker(label: "Reminder Time", icon: "clock", time: $reminderManager.workoutTime)
                }

                NotificationDivider()

                ReminderToggleRow(
                    category: .mealLogging,
                    isEnabled: $reminderManager.mealLoggingEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    VStack(spacing: 8) {
                        ReminderTimePicker(label: "Breakfast", icon: "sunrise", time: $reminderManager.breakfastTime)
                        ReminderTimePicker(label: "Lunch", icon: "sun.max", time: $reminderManager.lunchTime)
                        ReminderTimePicker(label: "Dinner", icon: "moon", time: $reminderManager.dinnerTime)
                    }
                }
            }
        }
    }

    private var socialNotificationsSection: some View {
        SettingsCard(title: "Social Notifications") {
            VStack(spacing: 0) {
                NotificationToggleRow(
                    type: .friendWorkout,
                    isOn: $viewModel.friendWorkoutNotifs,
                    viewModel: viewModel
                )

                NotificationDivider()

                NotificationToggleRow(
                    type: .friendLike,
                    isOn: $viewModel.likeNotifs,
                    viewModel: viewModel
                )

                NotificationDivider()

                NotificationToggleRow(
                    type: .streakMilestone,
                    isOn: $viewModel.streakMilestoneNotifs,
                    viewModel: viewModel
                )

                NotificationDivider()

                NotificationToggleRow(
                    type: .weeklyProgress,
                    isOn: $viewModel.weeklyProgressNotifs,
                    viewModel: viewModel
                )

                NotificationDivider()

                NotificationToggleRow(
                    type: .restDayRecovery,
                    isOn: $viewModel.restDayRecoveryNotifs,
                    viewModel: viewModel
                )

                NotificationDivider()

                NotificationToggleRow(
                    type: .streakWarning,
                    isOn: $viewModel.streakWarningNotifs,
                    viewModel: viewModel
                )
            }
        }
    }

    private func requestPermissionIfNeeded() {
        Task {
            _ = await reminderManager.requestAuthorizationIfNeeded()
        }
    }

    private var streakSection: some View {
        SettingsCard(title: "Streak") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Streak Freeze")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Allows 1 missed day per week without breaking your streak")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    if viewModel.streakManager.streakData.streakFreezeUsedThisWeek {
                        Text("Used")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 6))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake")
                                .font(.caption)
                            Text("Available")
                                .font(.system(.caption, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(PepTheme.teal.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }

                Divider().overlay(PepTheme.glassBorderTop)

                HStack {
                    Label("Current Streak", systemImage: "flame.fill")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("\(viewModel.streakManager.streakData.currentStreak) days")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.amber)
                }

                HStack {
                    Label("Longest Streak", systemImage: "trophy.fill")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text("\(viewModel.streakManager.streakData.longestStreak) days")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var healthKitSection: some View {
        SettingsCard(title: "Apple Health") {
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { healthKit.isHealthKitEnabled },
                    set: { healthKit.isHealthKitEnabled = $0 }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.body)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Apple Health")
                                .font(.body)
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("Sync steps, calories, heart rate, workouts & more")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                }
                .tint(PepTheme.teal)

                if healthKit.isAuthorized {
                    Divider().overlay(PepTheme.glassBorderTop)

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Text("Connected to Apple Health")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        healthDataRow(icon: "figure.walk", label: "Steps", value: "\(healthKit.steps)")
                        healthDataRow(icon: "flame.fill", label: "Active Calories", value: "\(Int(healthKit.activeCalories)) kcal")
                        healthDataRow(icon: "heart.fill", label: "Heart Rate", value: healthKit.heartRate > 0 ? "\(Int(healthKit.heartRate)) BPM" : "--")
                        healthDataRow(icon: "figure.run", label: "Distance", value: String(format: "%.2f mi", healthKit.distanceMiles))
                        healthDataRow(icon: "timer", label: "Exercise", value: "\(Int(healthKit.exerciseMinutes)) min")
                        healthDataRow(icon: "bed.double.fill", label: "Sleep", value: healthKit.sleepHours > 0 ? String(format: "%.1f hrs", healthKit.sleepHours) : "--")
                    }
                } else if healthKit.isHealthKitEnabled && !healthKit.isAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.amber)
                        Text("HealthKit not available on this device")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private func healthDataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(PepTheme.teal)
                .frame(width: 20)
            Text(label)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
        }
    }

    private var appearanceSection: some View {
        SettingsCard(title: "Appearance") {
            VStack(spacing: 12) {
                HStack {
                    Label("Theme", systemImage: appearanceManager.mode.icon)
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                appearanceManager.mode = mode
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 13, weight: .medium))
                                Text(mode.title)
                                    .font(.system(.subheadline, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(appearanceManager.mode == mode ? PepTheme.invertedText : PepTheme.textSecondary)
                            .background(appearanceManager.mode == mode ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: appearanceManager.mode == mode)
                    }
                }
            }
        }
    }

    private var accountSection: some View {
        SettingsCard(title: "Account") {
            VStack(spacing: 0) {
                SettingsButton(icon: "envelope.fill", title: "Change Email") { }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                SettingsButton(icon: "lock.fill", title: "Change Password") { }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                SettingsButton(icon: "rectangle.portrait.and.arrow.right", title: "Log Out", color: PepTheme.textSecondary) {
                    showLogOutConfirm = true
                }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                SettingsButton(icon: "trash.fill", title: "Delete Account", color: .red) {
                    showDeleteConfirm = true
                }
            }
        }
    }
}

private struct NotificationToggleRow: View {
    let type: NotificationType
    @Binding var isOn: Bool
    let viewModel: ProfileViewModel

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.subheadline)
                    .foregroundStyle(PepTheme.teal)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(type.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .tint(PepTheme.teal)
        .onChange(of: isOn) { _, newValue in
            viewModel.updateNotificationPreference(type, enabled: newValue)
        }
    }
}

private struct NotificationDivider: View {
    var body: some View {
        Divider()
            .overlay(PepTheme.glassBorderTop)
            .padding(.vertical, 6)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }
}

private struct SettingsButton: View {
    let icon: String
    let title: String
    var color: Color = PepTheme.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.impact(weight: .light), trigger: false)
    }
}
