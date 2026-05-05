import SwiftUI
import HealthKit
import UIKit

struct SettingsView: View {
    @Bindable var viewModel: ProfileViewModel
    @State private var showDeleteConfirm: Bool = false
    @State private var showLogOutConfirm: Bool = false
    @State private var appearanceManager = AppearanceManager.shared
    @State private var healthKit = HealthKitService.shared
    @State private var reminderManager = ReminderManager.shared
    @State private var peptideAccess = PeptideAccessManager.shared
    @State private var showHealthSettingsAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                unitsSection
                personalizationSection
                aiMemorySection
                vialScanHistorySection
                timerSection
                healthKitSection
                compoundAccessSection
                healthRemindersSection
                activityRemindersSection
                socialNotificationsSection
                moderationSection
                privacyDataSection
                streakSection
                appearanceSection
                aboutSection
                accountSection
                #if DEBUG
                DeveloperSettingsView()
                #endif
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .appBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { }
        } message: {
            Text("This will permanently delete your account and all data. This action cannot be undone.")
        }
        .alert("Apple Health Access", isPresented: $showHealthSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow EPTI to read your health data in Settings → Privacy & Security → Health → EPTI.")
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

    private var personalizationSection: some View {
        SettingsCard(title: "Personalization") {
            NavigationLink {
                PersonalizationSettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Persona track & profile")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Switch tracks or re-run About You / Goals")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    @State private var showVialScanHistory: Bool = false

    private var vialScanHistorySection: some View {
        SettingsCard(title: "Compound Tools") {
            Button {
                showVialScanHistory = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body)
                        .foregroundStyle(PepTheme.violet)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vial Scan History")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("View labels you've scanned previously")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showVialScanHistory) {
            NavigationStack {
                VialScanHistoryView { _, _ in
                    showVialScanHistory = false
                }
            }
        }
    }

    private var aiMemorySection: some View {
        SettingsCard(title: "Intelligence") {
            NavigationLink {
                AIMemoryView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.body)
                        .foregroundStyle(PepTheme.violet)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Memory")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("See what the app has learned about you")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
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

                NotificationDivider()

                ReminderToggleRow(
                    category: .weeklyCheckIn,
                    isEnabled: $reminderManager.weeklyCheckInEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    VStack(spacing: 8) {
                        ReminderDayPicker(label: "Day", day: $reminderManager.weeklyCheckInDay)
                        ReminderTimePicker(label: "Time", icon: "clock", time: $reminderManager.weeklyCheckInTime)
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

                NotificationDivider()

                ReminderToggleRow(
                    category: .hydration,
                    isEnabled: $reminderManager.hydrationEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    HydrationTimesEditor(reminderManager: reminderManager)
                }

                NotificationDivider()

                ReminderToggleRow(
                    category: .restDay,
                    isEnabled: $reminderManager.restDayEnabled,
                    onToggle: { enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                ) {
                    ReminderTimePicker(label: "Check Time", icon: "clock", time: $reminderManager.restDayCheckTime)
                }
            }
        }
    }

    private var moderationSection: some View {
        SettingsCard(title: "Moderation & Privacy") {
            NavigationLink {
                ModerationSettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.body)
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Muted users, tags, keywords")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text(moderationSummary)
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var privacyDataSection: some View {
        SettingsCard(title: "Privacy & Your Data") {
            NavigationLink {
                PrivacyDataView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.body)
                        .foregroundStyle(PepTheme.teal)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your data, your control")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Export your data, delete your account, review policies")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var moderationSummary: String {
        let m = LocalModerationStore.shared
        let users = m.mutedUserIds.count
        let tags = m.mutedTags.count
        let keywords = m.keywordFilters.count
        if users == 0 && tags == 0 && keywords == 0 {
            return "Manage your filters and blocks"
        }
        return "\(users) user\(users == 1 ? "" : "s"), \(tags) tag\(tags == 1 ? "" : "s"), \(keywords) keyword\(keywords == 1 ? "" : "s")"
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

    @State private var showStreakInfoFromSettings: Bool = false

    private var streakSection: some View {
        SettingsCard(title: "Streak") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Streak Freeze")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Text("Auto-applies once per rolling 7 days when you miss")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    Spacer()
                    if let days = viewModel.streakManager.freezeAvailableInDays {
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass").font(.caption)
                            Text("\(days)d").font(.system(.caption, weight: .medium))
                        }
                        .foregroundStyle(PepTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 6))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake").font(.caption)
                            Text("Ready").font(.system(.caption, weight: .medium))
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

                if viewModel.streakManager.streakState == .paused, let hours = viewModel.streakManager.pausedHoursRemaining {
                    Divider().overlay(PepTheme.glassBorderTop)
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill").foregroundStyle(PepTheme.amber)
                        Text("Paused — \(hours)h to save it")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                        Spacer()
                    }
                }

                Divider().overlay(PepTheme.glassBorderTop)

                Button {
                    showStreakInfoFromSettings = true
                } label: {
                    HStack {
                        Label("How streaks work", systemImage: "info.circle")
                            .font(.body)
                            .foregroundStyle(PepTheme.teal)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(PepTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showStreakInfoFromSettings) {
            StreakInfoSheet().presentationDetents([.medium, .large])
        }
    }

    private var compoundAccessSection: some View {
        SettingsCard(title: "Compound Surfaces") {
            VStack(alignment: .leading, spacing: 12) {
                if peptideAccess.biologicalSex == .female {
                    Toggle(isOn: Binding(
                        get: { peptideAccess.isPregnantOrNursing },
                        set: { peptideAccess.setPregnancyState($0) }
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill")
                                .font(.body)
                                .foregroundStyle(PepTheme.amber)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pregnant or nursing")
                                    .font(.body)
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("While on, compound tracking surfaces stay locked.")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .tint(PepTheme.teal)

                    Divider().overlay(PepTheme.glassBorderTop)
                }

                HStack(spacing: 10) {
                    Image(systemName: peptideAccess.canAccessCompoundSurfaces ? "lock.open.fill" : "lock.fill")
                        .font(.body)
                        .foregroundStyle(peptideAccess.canAccessCompoundSurfaces ? .green : PepTheme.amber)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(peptideAccess.canAccessCompoundSurfaces ? "Compound surfaces unlocked" : (peptideAccess.lockReason?.title ?? "Compound surfaces locked"))
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(PepTheme.textPrimary)
                        if let reason = peptideAccess.lockReason {
                            Text(reason.message)
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Vial scanner, protocols, dose logging and reconstitution are available.")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var healthKitSection: some View {
        SettingsCard(title: "Apple Health") {
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { healthKit.isHealthKitEnabled },
                    set: { newValue in
                        if newValue {
                            guard HKHealthStore.isHealthDataAvailable() else {
                                healthKit.isAvailable = false
                                return
                            }
                            healthKit.isHealthKitEnabled = true
                            Task {
                                let didShowPrompt = await healthKit.requestAuthorizationInteractively()
                                if !didShowPrompt && !healthKit.isAuthorized {
                                    showHealthSettingsAlert = true
                                }
                            }
                        } else {
                            healthKit.isHealthKitEnabled = false
                        }
                    }
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

    private var aboutSection: some View {
        SettingsCard(title: "About") {
            VStack(spacing: 0) {
                Link(destination: URL(string: "https://peppalapp.com/terms")!) {
                    aboutRow(icon: "doc.text.fill", title: "Terms of Service")
                }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                Link(destination: URL(string: "https://peppalapp.com/privacy")!) {
                    aboutRow(icon: "hand.raised.fill", title: "Privacy Policy")
                }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                Link(destination: URL(string: "https://peppalapp.com/support")!) {
                    aboutRow(icon: "questionmark.circle.fill", title: "Support")
                }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                NavigationLink {
                    MedicalDisclaimerDetailView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.body)
                            .foregroundStyle(PepTheme.amber)
                            .frame(width: 24)
                        Text("Medical Disclaimer")
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }
                Divider().overlay(PepTheme.glassBorderTop).padding(.vertical, 6)
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.body)
                        .foregroundStyle(PepTheme.textSecondary)
                        .frame(width: 24)
                    Text("Version")
                        .font(.body)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Text(appVersion)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func aboutRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(PepTheme.textPrimary)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(PepTheme.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
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
