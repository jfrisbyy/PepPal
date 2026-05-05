import Foundation

enum SmartDailyTasksAssembler {

    struct Inputs {
        let userTasks: [DailyTask]
        let activeProtocols: [PeptideProtocol]
        let activeProgram: TrainingProgram?
        let todaysWorkoutPlan: WorkoutPlan
        let workoutCompletedToday: Bool
        let proteinTarget: Int
        let calorieTarget: Int
        let proteinConsumed: Int
        let caloriesConsumed: Int
        let stepGoal: Int
        let stepsToday: Int
        let waterTarget: Int
        let aiActionItems: [PlanActionItem]
        let aiDeckSuggestions: [AIDeckSuggestion]
        let completedSyntheticIds: Set<UUID>
    }

    static func assemble(_ inputs: Inputs) -> [DailyTask] {
        var result: [DailyTask] = []
        var seenNames: Set<String> = []

        for t in inputs.userTasks {
            seenNames.insert(t.name.lowercased())
            result.append(t)
        }

        for proto in inputs.activeProtocols {
            for compound in proto.compounds {
                guard isDueToday(compound: compound, protocolStart: proto.startDate) else { continue }
                let logged = proto.doseLog.contains {
                    $0.compoundName == compound.compoundName &&
                    Calendar.current.isDateInToday($0.timestamp)
                }
                let name = "Log \(compound.compoundName) Dose"
                let key = "scheduled-dose-\(compound.id.uuidString)-\(dayKey())"
                let id = stableUUID(from: key)
                if seenNames.contains(name.lowercased()) { continue }
                seenNames.insert(name.lowercased())
                result.append(DailyTask(
                    id: id,
                    name: name,
                    icon: "syringe.fill",
                    category: .wellness,
                    isCompleted: logged || inputs.completedSyntheticIds.contains(id),
                    actionLink: .none,
                    isProtocolRecommended: true,
                    protocolReason: "Scheduled \(compound.frequency.lowercased()) — \(formatDose(compound))",
                    source: .scheduled
                ))
            }
        }

        if let program = inputs.activeProgram, !inputs.todaysWorkoutPlan.isRestDay {
            let name = "Complete \(inputs.todaysWorkoutPlan.name)"
            if !seenNames.contains(name.lowercased()) {
                seenNames.insert(name.lowercased())
                let key = "scheduled-workout-\(program.id.uuidString)-\(dayKey())"
                let id = stableUUID(from: key)
                result.append(DailyTask(
                    id: id,
                    name: name,
                    icon: "dumbbell.fill",
                    category: .fitness,
                    isCompleted: inputs.workoutCompletedToday || inputs.completedSyntheticIds.contains(id),
                    actionLink: .workoutCompleted,
                    isProtocolRecommended: false,
                    protocolReason: "",
                    source: .scheduled
                ))
            }
        }

        appendTypical(
            result: &result,
            seenNames: &seenNames,
            link: .proteinGoal,
            name: "Hit \(inputs.proteinTarget)g Protein",
            icon: "fish.fill",
            category: .nutrition,
            target: inputs.proteinTarget,
            current: inputs.proteinConsumed,
            completedSyntheticIds: inputs.completedSyntheticIds
        )
        appendTypical(
            result: &result,
            seenNames: &seenNames,
            link: .calorieGoal,
            name: "Hit \(inputs.calorieTarget) Calorie Target",
            icon: "flame.fill",
            category: .nutrition,
            target: inputs.calorieTarget,
            current: inputs.caloriesConsumed,
            completedSyntheticIds: inputs.completedSyntheticIds
        )
        if inputs.stepGoal > 0 {
            appendTypical(
                result: &result,
                seenNames: &seenNames,
                link: .stepCounter,
                name: "Walk \(inputs.stepGoal.formatted()) Steps",
                icon: "figure.walk",
                category: .fitness,
                target: inputs.stepGoal,
                current: inputs.stepsToday,
                completedSyntheticIds: inputs.completedSyntheticIds
            )
        }
        if inputs.waterTarget > 0 {
            appendTypical(
                result: &result,
                seenNames: &seenNames,
                link: .waterIntake,
                name: "Drink \(inputs.waterTarget)oz Water",
                icon: "drop.fill",
                category: .nutrition,
                target: inputs.waterTarget,
                current: 0,
                completedSyntheticIds: inputs.completedSyntheticIds
            )
        }

        for suggestion in inputs.aiDeckSuggestions {
            if seenNames.contains(suggestion.title.lowercased()) { continue }
            seenNames.insert(suggestion.title.lowercased())
            let id = stableUUID(from: "deck-\(suggestion.id)-\(dayKey())")
            result.append(DailyTask(
                id: id,
                name: suggestion.title,
                icon: suggestion.icon,
                category: suggestion.category,
                isCompleted: inputs.completedSyntheticIds.contains(id),
                actionLink: .none,
                isProtocolRecommended: false,
                protocolReason: suggestion.reason,
                source: .aiSuggested,
                aiUrgency: suggestion.urgency,
                aiEvidence: suggestion.evidence,
                aiSuggestionId: suggestion.id
            ))
        }

        for item in inputs.aiActionItems {
            if seenNames.contains(item.title.lowercased()) { continue }
            seenNames.insert(item.title.lowercased())
            let id = stableUUID(from: item.stableId + "-" + dayKey())
            let category = TaskCategory(rawValue: item.category ?? "") ?? .wellness
            result.append(DailyTask(
                id: id,
                name: item.title,
                icon: item.icon ?? "sparkles",
                category: category,
                isCompleted: inputs.completedSyntheticIds.contains(id),
                actionLink: .none,
                isProtocolRecommended: false,
                protocolReason: item.reason ?? "",
                source: .aiSuggested
            ))
        }

        return result
    }

    private static func appendTypical(
        result: inout [DailyTask],
        seenNames: inout Set<String>,
        link: TaskActionLink,
        name: String,
        icon: String,
        category: TaskCategory,
        target: Int,
        current: Int,
        completedSyntheticIds: Set<UUID>
    ) {
        guard target > 0 else { return }
        let lowerName = name.lowercased()
        if seenNames.contains(lowerName) { return }
        if result.contains(where: { $0.actionLink == link && $0.source == .user }) { return }
        seenNames.insert(lowerName)
        let key = "typical-\(link.rawValue)-\(dayKey())"
        let id = stableUUID(from: key)
        let isHit = current >= target
        result.append(DailyTask(
            id: id,
            name: name,
            icon: icon,
            category: category,
            isCompleted: isHit || completedSyntheticIds.contains(id),
            actionLink: link,
            actionTarget: target,
            source: .typical
        ))
    }

    private static func isDueToday(compound: ProtocolCompound, protocolStart: Date) -> Bool {
        let freq = compound.frequency.lowercased()
        if freq.contains("daily") || freq.contains("every day") { return true }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let todayName = dayNames[weekday - 1]
        if freq.contains(todayName) { return true }
        if freq.contains("weekly") || freq.contains("once a week") {
            let days = Calendar.current.dateComponents([.day], from: protocolStart, to: Date()).day ?? 0
            return days % 7 == 0
        }
        if freq.contains("twice") || freq.contains("2x") {
            return weekday == 2 || weekday == 5
        }
        if freq.contains("eod") || freq.contains("every other day") {
            let days = Calendar.current.dateComponents([.day], from: protocolStart, to: Date()).day ?? 0
            return days % 2 == 0
        }
        return true
    }

    private static func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func stableUUID(from key: String) -> UUID {
        var hasher = Hasher()
        hasher.combine(key)
        let h = hasher.finalize()
        let upper = UInt64(bitPattern: Int64(h))
        let lower = UInt64(bitPattern: Int64(key.count))
        let bytes: [UInt8] = withUnsafeBytes(of: upper.bigEndian) { Array($0) }
            + withUnsafeBytes(of: lower.bigEndian) { Array($0) }
        let uuid = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    private static func formatDose(_ compound: ProtocolCompound) -> String {
        CompoundUnitHelper.displayDoseShort(compound.doseMcg, for: compound.compoundName)
    }
}
