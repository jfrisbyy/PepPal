import SwiftUI

nonisolated enum JourneyEventType: String, Sendable {
    case dose
    case weight
    case bloodwork
    case photo
    case sideEffect
    case milestone
    case workout
    case nutrition

    var icon: String {
        switch self {
        case .dose: return "syringe.fill"
        case .weight: return "scalemass.fill"
        case .bloodwork: return "drop.fill"
        case .photo: return "camera.fill"
        case .sideEffect: return "exclamationmark.triangle.fill"
        case .milestone: return "flag.fill"
        case .workout: return "dumbbell.fill"
        case .nutrition: return "fork.knife"
        }
    }

    var color: Color {
        switch self {
        case .dose: return PepTheme.teal
        case .weight: return Color(red: 76/255, green: 217/255, blue: 100/255)
        case .bloodwork: return PepTheme.blue
        case .photo: return PepTheme.violet
        case .sideEffect: return PepTheme.amber
        case .milestone: return Color(red: 255/255, green: 107/255, blue: 107/255)
        case .workout: return Color(red: 255/255, green: 149/255, blue: 0)
        case .nutrition: return Color(red: 52/255, green: 199/255, blue: 89/255)
        }
    }
}

nonisolated struct JourneyEvent: Identifiable, Sendable {
    let id: UUID
    let type: JourneyEventType
    let date: Date
    let title: String
    let subtitle: String
    let detail: String?
    let week: Int

    init(type: JourneyEventType, date: Date, title: String, subtitle: String, detail: String? = nil, week: Int) {
        self.id = UUID()
        self.type = type
        self.date = date
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.week = week
    }
}

nonisolated struct WeeklySummary: Sendable {
    let workoutCount: Int
    let totalWorkoutMinutes: Int
    let totalCaloriesBurned: Int
    let avgDailyCalories: Int
    let avgDailyProtein: Int
    let avgDailyCarbs: Int
    let avgDailyFat: Int
    let nutritionDaysLogged: Int
    let tasksCompleted: Int
    let totalTasks: Int
    let doseCount: Int
    let weightChange: Double?
}

nonisolated struct JourneyWeek: Identifiable, Sendable {
    let id: Int
    let weekNumber: Int
    let events: [JourneyEvent]
    let startDate: Date
    let endDate: Date
    let isCurrentWeek: Bool
    let summary: WeeklySummary
}

@Observable
final class ProtocolJourneyViewModel {
    let protocolData: PeptideProtocol
    var weightEntries: [WeightEntry] = []
    var bloodworkEntries: [BloodworkEntry] = []
    var progressPhotos: [ProgressPhoto] = []
    var workouts: [SupabaseWorkout] = []
    var weeklyMeals: [Int: [SupabaseLoggedMeal]] = [:]
    var weeklyTasks: [Int: (completed: Int, total: Int)] = [:]
    var isLoading: Bool = true
    var selectedWeekFilter: Int? = nil
    var showProtocolDetail: Bool = false

    private let bodyGoalsService = BodyGoalsService.shared
    private let bloodworkService = BloodworkService.shared
    private let workoutService = WorkoutService.shared
    private let nutritionService = NutritionService.shared
    private let dailyTaskService = DailyTaskService.shared
    private let calendar = Calendar.current

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(protocolData: PeptideProtocol) {
        self.protocolData = protocolData
    }

    var allEvents: [JourneyEvent] {
        var events: [JourneyEvent] = []

        for dose in protocolData.doseLog {
            let week = weekNumber(for: dose.timestamp)
            events.append(JourneyEvent(
                type: .dose,
                date: dose.timestamp,
                title: dose.compoundName,
                subtitle: CompoundUnitHelper.displayDoseShort(dose.doseMcg, for: dose.compoundName),
                detail: dose.notes.isEmpty ? dose.injectionSite.shortName : "\(dose.injectionSite.shortName) · \(dose.notes)",
                week: week
            ))
        }

        for entry in weightEntries {
            let week = weekNumber(for: entry.date)
            let changeText = weightChangeText(for: entry)
            events.append(JourneyEvent(
                type: .weight,
                date: entry.date,
                title: String(format: "%.1f lbs", entry.weight),
                subtitle: changeText,
                detail: entry.note.isEmpty ? nil : entry.note,
                week: week
            ))
        }

        for entry in bloodworkEntries {
            let week = weekNumber(for: entry.date)
            let abnormalCount = entry.results.filter { !$0.isInRange }.count
            let subtitle = abnormalCount > 0
                ? "\(entry.results.count) markers · \(abnormalCount) flagged"
                : "\(entry.results.count) markers · All normal"
            events.append(JourneyEvent(
                type: .bloodwork,
                date: entry.date,
                title: "Lab Results",
                subtitle: subtitle,
                detail: entry.notes.isEmpty ? nil : entry.notes,
                week: week
            ))
        }

        for photo in progressPhotos {
            let week = weekNumber(for: photo.date)
            events.append(JourneyEvent(
                type: .photo,
                date: photo.date,
                title: "Progress Photo",
                subtitle: photo.label.isEmpty ? (photo.category ?? "Week \(week)") : photo.label,
                week: week
            ))
        }

        for effect in protocolData.sideEffectLog {
            let week = weekNumber(for: effect.timestamp)
            let severityLabel: String
            switch effect.severity {
            case 1: severityLabel = "Mild"
            case 2: severityLabel = "Moderate"
            case 3: severityLabel = "Significant"
            default: severityLabel = "Severe"
            }
            events.append(JourneyEvent(
                type: .sideEffect,
                date: effect.timestamp,
                title: effect.effect,
                subtitle: severityLabel,
                detail: effect.notes.isEmpty ? nil : effect.notes,
                week: week
            ))
        }

        for workout in workouts {
            let dateStr = workout.completed_at ?? workout.created_at
            let date = parseDate(dateStr)
            guard date >= protocolData.startDate else { continue }
            let week = weekNumber(for: date)
            let duration = workout.duration_minutes ?? 0
            let cals = workout.calories_burned ?? 0
            let durationText = duration > 0 ? "\(duration) min" : ""
            let calText = cals > 0 ? "\(cals) cal" : ""
            let parts = [durationText, calText].filter { !$0.isEmpty }
            events.append(JourneyEvent(
                type: .workout,
                date: date,
                title: workout.name,
                subtitle: parts.joined(separator: " · "),
                detail: workout.workout_type,
                week: week
            ))
        }

        return events.sorted { $0.date > $1.date }
    }

    var journeyWeeks: [JourneyWeek] {
        let currentWeek = protocolData.currentWeek
        let totalWeeks = max(currentWeek, protocolData.effectiveTotalWeeks)
        let events = allEvents

        var weeks: [JourneyWeek] = []
        for w in (1...totalWeeks).reversed() {
            let weekEvents = events.filter { $0.week == w }
            let weekStart = calendar.date(byAdding: .day, value: (w - 1) * 7, to: protocolData.startDate) ?? protocolData.startDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let summary = buildWeeklySummary(week: w, events: weekEvents, weekStart: weekStart, weekEnd: weekEnd)

            weeks.append(JourneyWeek(
                id: w,
                weekNumber: w,
                events: weekEvents,
                startDate: weekStart,
                endDate: weekEnd,
                isCurrentWeek: w == currentWeek,
                summary: summary
            ))
        }

        if let filter = selectedWeekFilter {
            return weeks.filter { $0.weekNumber == filter }
        }

        return weeks
    }

    var totalDoses: Int {
        protocolData.doseLog.count
    }

    var totalWeightChange: Double? {
        guard let first = weightEntries.first, let last = weightEntries.last, weightEntries.count >= 2 else { return nil }
        return last.weight - first.weight
    }

    var totalBloodworkPanels: Int {
        bloodworkEntries.count
    }

    var totalPhotos: Int {
        progressPhotos.count
    }

    var totalWorkouts: Int {
        workouts.filter { workout in
            let date = parseDate(workout.completed_at ?? workout.created_at)
            return date >= protocolData.startDate
        }.count
    }

    var adherenceRate: Double {
        guard protocolData.currentDay > 0 else { return 0 }
        let expectedDoses = estimateExpectedDoses()
        guard expectedDoses > 0 else { return 1.0 }
        return min(Double(totalDoses) / Double(expectedDoses), 1.0)
    }

    var weightTrend: [(date: Date, weight: Double)] {
        weightEntries.sorted { $0.date < $1.date }.map { ($0.date, $0.weight) }
    }

    func loadData() {
        Task {
            isLoading = true
            await fetchAllJourneyData()
            isLoading = false
        }
    }

    private func fetchAllJourneyData() async {
        do {
            let weights = try await bodyGoalsService.fetchWeightLogs()
            weightEntries = weights.filter { $0.date >= protocolData.startDate }
        } catch {}

        do {
            let userId = try AuthService.shared.currentUserId()

            async let bloodworkTask: Void = fetchBloodwork(userId: userId)
            async let workoutsTask: Void = fetchWorkouts(userId: userId)
            async let nutritionTask: Void = fetchNutrition(userId: userId)
            async let tasksTask: Void = fetchDailyTasks(userId: userId)

            _ = await (bloodworkTask, workoutsTask, nutritionTask, tasksTask)
        } catch {}
    }

    private func fetchBloodwork(userId: String) async {
        do {
            let supaEntries = try await bloodworkService.fetchEntries(userId: userId)
            var loaded: [BloodworkEntry] = []
            for entry in supaEntries {
                guard let entryId = entry.id else { continue }
                let results = try await bloodworkService.fetchBiomarkerResults(entryId: entryId)
                let converted = bloodworkService.toBloodworkEntry(entry, results: results)
                if converted.date >= protocolData.startDate {
                    loaded.append(converted)
                }
            }
            bloodworkEntries = loaded
        } catch {}
    }

    private func fetchWorkouts(userId: String) async {
        do {
            let fetched = try await workoutService.fetchWorkouts(userId: userId, limit: 200)
            workouts = fetched.filter { workout in
                let date = parseDate(workout.completed_at ?? workout.created_at)
                return date >= protocolData.startDate
            }
        } catch {}
    }

    private func fetchNutrition(userId: String) async {
        do {
            let now = Date()
            let endDate = min(now, calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            let meals = try await nutritionService.fetchLoggedMealsInRange(
                userId: userId,
                from: protocolData.startDate,
                to: endDate
            )
            var grouped: [Int: [SupabaseLoggedMeal]] = [:]
            for meal in meals {
                let date = parseMealDate(meal.logged_at)
                let week = weekNumber(for: date)
                grouped[week, default: []].append(meal)
            }
            weeklyMeals = grouped
        } catch {}
    }

    private func fetchDailyTasks(userId: String) async {
        do {
            let allTasks = try await dailyTaskService.fetchTasks(userId: userId)
            var tasksByWeek: [Int: (completed: Int, total: Int)] = [:]
            for task in allTasks {
                guard let dateStr = task.task_date else { continue }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                guard let date = formatter.date(from: dateStr), date >= protocolData.startDate else { continue }
                let week = weekNumber(for: date)
                let existing = tasksByWeek[week] ?? (completed: 0, total: 0)
                tasksByWeek[week] = (
                    completed: existing.completed + ((task.is_completed ?? false) ? 1 : 0),
                    total: existing.total + 1
                )
            }
            weeklyTasks = tasksByWeek
        } catch {}
    }

    private func buildWeeklySummary(week: Int, events: [JourneyEvent], weekStart: Date, weekEnd: Date) -> WeeklySummary {
        let weekWorkouts = workouts.filter { workout in
            let date = parseDate(workout.completed_at ?? workout.created_at)
            return weekNumber(for: date) == week
        }
        let workoutCount = weekWorkouts.count
        let totalMinutes = weekWorkouts.reduce(0) { $0 + ($1.duration_minutes ?? 0) }
        let totalCalsBurned = weekWorkouts.reduce(0) { $0 + ($1.calories_burned ?? 0) }

        let meals = weeklyMeals[week] ?? []
        var dailyNutrition: [String: (cals: Int, protein: Double, carbs: Double, fat: Double)] = [:]
        for meal in meals {
            let date = parseMealDate(meal.logged_at)
            let dayKey = calendar.startOfDay(for: date).description
            let servings = meal.servings
            let existing = dailyNutrition[dayKey] ?? (cals: 0, protein: 0, carbs: 0, fat: 0)
            dailyNutrition[dayKey] = (
                cals: existing.cals + Int(Double(meal.calories ?? 0) * servings),
                protein: existing.protein + (meal.protein_g ?? 0) * servings,
                carbs: existing.carbs + (meal.carbs_g ?? 0) * servings,
                fat: existing.fat + (meal.fat_g ?? 0) * servings
            )
        }
        let nutritionDays = dailyNutrition.count
        let avgCals = nutritionDays > 0 ? dailyNutrition.values.reduce(0) { $0 + $1.cals } / nutritionDays : 0
        let avgProtein = nutritionDays > 0 ? Int(dailyNutrition.values.reduce(0.0) { $0 + $1.protein } / Double(nutritionDays)) : 0
        let avgCarbs = nutritionDays > 0 ? Int(dailyNutrition.values.reduce(0.0) { $0 + $1.carbs } / Double(nutritionDays)) : 0
        let avgFat = nutritionDays > 0 ? Int(dailyNutrition.values.reduce(0.0) { $0 + $1.fat } / Double(nutritionDays)) : 0

        let taskData = weeklyTasks[week] ?? (completed: 0, total: 0)

        let doseCount = events.filter { $0.type == .dose }.count

        let weekWeights = weightEntries.filter { weekNumber(for: $0.date) == week }.sorted { $0.date < $1.date }
        var weightChange: Double? = nil
        if weekWeights.count >= 2, let first = weekWeights.first, let last = weekWeights.last {
            weightChange = last.weight - first.weight
        }

        return WeeklySummary(
            workoutCount: workoutCount,
            totalWorkoutMinutes: totalMinutes,
            totalCaloriesBurned: totalCalsBurned,
            avgDailyCalories: avgCals,
            avgDailyProtein: avgProtein,
            avgDailyCarbs: avgCarbs,
            avgDailyFat: avgFat,
            nutritionDaysLogged: nutritionDays,
            tasksCompleted: taskData.completed,
            totalTasks: taskData.total,
            doseCount: doseCount,
            weightChange: weightChange
        )
    }

    private func weekNumber(for date: Date) -> Int {
        let days = max(0, calendar.dateComponents([.day], from: protocolData.startDate, to: date).day ?? 0)
        return days / 7 + 1
    }

    private func weightChangeText(for entry: WeightEntry) -> String {
        guard let firstWeight = weightEntries.first?.weight else { return "" }
        let change = entry.weight - firstWeight
        if abs(change) < 0.1 { return "Starting weight" }
        let sign = change > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change)) lbs from start"
    }

    private func parseDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string) ?? Date()
    }

    private func parseMealDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        return iso8601.date(from: string) ?? Date()
    }

    private func estimateExpectedDoses() -> Int {
        guard !protocolData.compounds.isEmpty else { return 0 }
        let days = protocolData.currentDay
        var total = 0
        for compound in protocolData.compounds {
            let freq = compound.frequency.lowercased()
            if freq.contains("daily") {
                total += days
            } else if freq.contains("twice") {
                total += days / 3
            } else if freq.contains("week") || freq.contains("7") {
                total += days / 7
            } else if freq.contains("other") || freq.contains("eod") {
                total += days / 2
            } else {
                total += days / 7
            }
        }
        return max(1, total)
    }
}
