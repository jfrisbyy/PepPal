import SwiftUI
import HealthKit

struct LogActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedActivity: String = UserDefaults.standard.string(forKey: "logActivity.lastSport") ?? "Walking"
    @State private var durationMinutes: String = "30"
    @State private var intensity: Int = 5
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var estimatedCalories: Int = 0
    @State private var manualCalorieOverride: String = ""
    @State private var isOverrideActive: Bool = false
    @State private var matchedWatchWorkout: HKWorkout? = nil
    @State private var watchWorkoutCalories: Int = 0

    private let activities = [
        "Walking", "Hiking", "Running", "Cycling", "Swimming",
        "Yoga", "HIIT", "Dancing", "Rowing", "Elliptical",
        "Jump Rope", "Stretching", "Yard Work", "Stair Climbing",
        "Boxing", "Martial Arts", "Pilates", "Rock Climbing",
        "Basketball", "Soccer", "Tennis", "Football", "Baseball"
    ]

    private var finalCalories: Int {
        if isOverrideActive, let override = Int(manualCalorieOverride), override > 0 {
            return override
        }
        return estimatedCalories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    activityPicker
                    durationSection
                    if matchedWatchWorkout != nil {
                        watchMatchBanner
                    } else {
                        intensitySection
                    }
                    calorieEstimate
                    calorieOverrideSection
                    notesSection
                }
                .padding()
                .padding(.bottom, 40)
            }
            .appBackground()
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveActivity()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(PepTheme.teal)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(PepTheme.teal)
                        }
                    }
                    .disabled(isSaving || (Int(durationMinutes) ?? 0) <= 0)
                }
            }
            .onChange(of: selectedActivity) { _, newValue in
                loadRemembered(for: newValue)
                Task { await tryMatchWatchWorkout() }
                updateCalorieEstimate()
            }
            .onChange(of: durationMinutes) { _, _ in updateCalorieEstimate() }
            .onChange(of: intensity) { _, _ in updateCalorieEstimate() }
            .onAppear {
                loadRemembered(for: selectedActivity)
                Task { await tryMatchWatchWorkout() }
                updateCalorieEstimate()
            }
        }
    }

    private var activityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity Type")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(activities, id: \.self) { activity in
                        let isSelected = selectedActivity == activity
                        Button {
                            selectedActivity = activity
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: iconForActivity(activity))
                                    .font(.system(size: 12))
                                Text(activity)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.capsule)
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duration")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            HStack(spacing: 12) {
                ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                    let isSelected = durationMinutes == "\(mins)"
                    Button {
                        durationMinutes = "\(mins)"
                    } label: {
                        Text("\(mins)m")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .black : PepTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Custom:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                TextField("", text: $durationMinutes)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 8))
                Text("minutes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Intensity")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Text(intensityLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(intensityColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(intensityColor.opacity(0.12))
                    .clipShape(.capsule)
            }

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { level in
                    Button {
                        intensity = level
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(level <= intensity ? intensityColor : PepTheme.elevated)
                            .frame(height: 32)
                    }
                }
            }
        }
    }

    private var watchMatchBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "applewatch")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Synced from Apple Watch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Using real heart rate data from your session.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.green.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.green.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var calorieEstimate: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isOverrideActive ? "Manual Calories" : "Estimated Calories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Text("\(finalCalories) cal")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(isOverrideActive ? "Override" : "MET-based")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOverrideActive ? .orange : PepTheme.textSecondary)
                Text(isOverrideActive ? "active" : "estimate")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOverrideActive ? .orange : PepTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder((isOverrideActive ? Color.orange : .orange).opacity(0.2), lineWidth: 0.5)
        )
    }

    private var calorieOverrideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Override Calories")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Spacer()
                Toggle("", isOn: $isOverrideActive)
                    .labelsHidden()
                    .tint(.orange)
            }

            if isOverrideActive {
                HStack(spacing: 8) {
                    TextField("e.g. 350", text: $manualCalorieOverride)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 10))

                    Text("cal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Text("Use this if you have a more accurate reading from your watch or gym equipment.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOverrideActive)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes (optional)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)

            TextField("How did it feel?", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var intensityLabel: String {
        switch intensity {
        case 1...3: "Light"
        case 4...5: "Moderate"
        case 6...7: "Hard"
        case 8...10: "Vigorous"
        default: "Moderate"
        }
    }

    private var intensityColor: Color {
        switch intensity {
        case 1...3: .green
        case 4...5: PepTheme.teal
        case 6...7: .orange
        case 8...10: .red
        default: PepTheme.teal
        }
    }

    private func iconForActivity(_ activity: String) -> String {
        switch activity {
        case "Walking": return "figure.walk"
        case "Hiking": return "figure.hiking"
        case "Running": return "figure.run"
        case "Cycling": return "figure.outdoor.cycle"
        case "Swimming": return "figure.pool.swim"
        case "Yoga": return "figure.yoga"
        case "HIIT": return "bolt.heart.fill"
        case "Dancing": return "figure.dance"
        case "Rowing": return "figure.rowing"
        case "Elliptical": return "figure.elliptical"
        case "Jump Rope": return "figure.jumprope"
        case "Stretching": return "figure.flexibility"
        case "Yard Work": return "leaf.fill"
        case "Stair Climbing": return "figure.stairs"
        case "Boxing": return "figure.boxing"
        case "Martial Arts": return "figure.martial.arts"
        case "Pilates": return "figure.pilates"
        case "Rock Climbing": return "figure.climbing"
        case "Basketball": return "basketball.fill"
        case "Soccer": return "soccerball"
        case "Tennis": return "tennis.racket"
        case "Football": return "football.fill"
        case "Baseball": return "baseball.fill"
        default: return "figure.run"
        }
    }

    private func updateCalorieEstimate() {
        let mins = Int(durationMinutes) ?? 0
        guard mins > 0 else {
            estimatedCalories = 0
            return
        }
        if matchedWatchWorkout != nil, watchWorkoutCalories > 0 {
            estimatedCalories = watchWorkoutCalories
            return
        }
        let cachedLbs = UserDefaults.standard.double(forKey: "cachedWeightLbs")
        let weightKg = cachedLbs > 0 ? cachedLbs * 0.453592 : 79.4
        estimatedCalories = METCalculator.caloriesBurned(
            sport: selectedActivity,
            workoutType: nil,
            durationMinutes: mins,
            weightKg: weightKg,
            intensity: intensity
        )
    }

    private func loadRemembered(for activity: String) {
        let key = "logActivity.remembered.\(activity.lowercased())"
        if let data = UserDefaults.standard.dictionary(forKey: key) {
            if let dur = data["duration"] as? Int {
                durationMinutes = "\(dur)"
            }
            if let inten = data["intensity"] as? Int {
                intensity = inten
            }
        }
    }

    private func remember(activity: String, duration: Int, intensity: Int) {
        UserDefaults.standard.set(activity, forKey: "logActivity.lastSport")
        let key = "logActivity.remembered.\(activity.lowercased())"
        UserDefaults.standard.set(["duration": duration, "intensity": intensity], forKey: key)
    }

    private func tryMatchWatchWorkout() async {
        let hk = HealthKitService.shared
        guard hk.isHealthKitEnabled, hk.isAuthorized else {
            matchedWatchWorkout = nil
            watchWorkoutCalories = 0
            return
        }
        let workouts = await hk.fetchWorkouts(for: Date())
        let normalizedSelected = ActivityReconciliation.normalize(selectedActivity)
        let cutoff = Date().addingTimeInterval(-3 * 60 * 60)
        let match = workouts.first { w in
            guard w.endDate >= cutoff else { return false }
            let sport = ActivityReconciliation.sportName(for: w.workoutActivityType)
            return ActivityReconciliation.sportsMatch(
                ActivityReconciliation.normalize(sport),
                normalizedSelected
            )
        }
        matchedWatchWorkout = match
        if let match {
            let dur = Int(match.duration / 60)
            if dur > 0 { durationMinutes = "\(dur)" }
            if let stats = match.statistics(for: HKQuantityType(.activeEnergyBurned)),
               let sum = stats.sumQuantity() {
                watchWorkoutCalories = Int(sum.doubleValue(for: .kilocalorie()))
            }
        } else {
            watchWorkoutCalories = 0
        }
    }

    private func saveActivity() {
        let mins = Int(durationMinutes) ?? 0
        guard mins > 0, AuthService.shared.authState == .signedIn else { return }
        isSaving = true
        Task {
            do {
                let userId = try AuthService.shared.currentUserId()
                let noteStr: String? = notes.isEmpty ? nil : notes
                try await ActivityLogService.shared.logActivity(
                    userId: userId,
                    activityType: "workout",
                    sport: selectedActivity,
                    durationMinutes: mins,
                    caloriesBurned: finalCalories,
                    metValue: nil as Double?,
                    notes: noteStr
                )
                remember(activity: selectedActivity, duration: mins, intensity: intensity)
                NotificationCenter.default.post(name: .supabaseDataChanged, object: nil, userInfo: ["source": "activity"])
                dismiss()
            } catch {
                print("[LogActivity] ERROR: \(error)")
                isSaving = false
            }
        }
    }
}
