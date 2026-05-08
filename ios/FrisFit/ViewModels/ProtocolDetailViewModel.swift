import SwiftUI

@Observable
final class ProtocolDetailViewModel {
    var protocolData: PeptideProtocol
    var expandedSections: Set<String> = ["doseLog", "timeline"]
    var showLogDoseSheet: Bool = false
    var showSideEffectSheet: Bool = false
    var showAddSupplementSheet: Bool = false
    var showAddNoteSheet: Bool = false
    var showReconCalculator: Bool = false
    var showArchiveConfirm: Bool = false
    var showDeleteConfirm: Bool = false
    var showSkipDoseSheet: Bool = false
    var showCostSheet: Bool = false
    var showShareSheet: Bool = false
    var editingDose: DoseLogEntry? = nil
    var exportURL: URL?
    var isLoading: Bool = false
    var errorMessage: String?
    var didDelete: Bool = false

    var newDoseCompound: String = ""
    var newDoseMcg: String = ""
    var newDoseSite: InjectionSite = .leftAbdomen
    var newDoseNotes: String = ""
    var newDoseRoute: AdministrationRoute = .subcutaneous
    var newDoseNasalSide: NasalSide = .both

    var skipReason: String = ""

    var newEffectName: String = ""
    var newEffectSeverity: Int = 2
    var newEffectNotes: String = ""

    var newSupplementName: String = ""
    var newSupplementDose: String = ""
    var newSupplementFrequency: String = "Daily"

    var newNoteText: String = ""

    var reconPeptideMg: String = ""
    var reconWaterMl: String = ""
    var reconDesiredMcg: String = ""

    var dailyRatings: [DailyRating] = []
    var notes: [ProtocolNote] = []
    var titrationSteps: [TitrationStep] = []
    var recoveryMilestones: [RecoveryMilestone] = []
    var bodyMeasurements: [ProtocolBodyMeasurement] = []

    private let protocolService = ProtocolService.shared

    let commonSideEffects = [
        "Nausea", "Injection Site Redness", "Fatigue", "Headache",
        "Water Retention", "Dizziness", "Appetite Changes",
        "Mood Changes", "Insomnia", "Flushing"
    ]

    let skipReasons = [
        "Forgot", "Traveling", "Sick", "Ran out", "Side effects", "Intentional break", "Other"
    ]

    init(protocolData: PeptideProtocol) {
        self.protocolData = protocolData
        if let first = protocolData.smartNextDose() ?? protocolData.compounds.first {
            self.newDoseCompound = first.compoundName
            let displayVal = CompoundUnitHelper.fromMcg(first.doseMcg, for: first.compoundName)
            self.newDoseMcg = displayVal == displayVal.rounded() && displayVal >= 1 ? String(Int(displayVal)) : String(format: "%.2g", displayVal)
        }
        self.newDoseSite = suggestedNextSite
        setupTitrationSteps()
        setupRecoveryMilestones()
    }

    func toggleSection(_ section: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    func isSectionExpanded(_ section: String) -> Bool {
        expandedSections.contains(section)
    }

    // MARK: - Dose Logging

    func logDose(vial: Vial? = nil) {
        let displayValue = Double(newDoseMcg) ?? 0
        let mcgValue = CompoundUnitHelper.toMcg(displayValue, for: newDoseCompound)
        let compound = newDoseCompound
        let site = newDoseSite
        let doseNotes = newDoseNotes
        newDoseNotes = ""
        showLogDoseSheet = false

        // Optimistic local insert
        let optimistic = DoseLogEntry(
            compoundName: compound,
            doseMcg: mcgValue,
            injectionSite: site,
            notes: doseNotes
        )
        protocolData.doseLog.insert(optimistic, at: 0)

        let sid = protocolData.supabaseId
        Task {
            let result = await DoseLogger.log(
                protocolId: sid,
                compoundName: compound,
                doseMcg: mcgValue,
                injectionSite: site,
                notes: doseNotes,
                vial: vial
            )
            if let saved = result.entry,
               let idx = protocolData.doseLog.firstIndex(where: { $0.id == optimistic.id }) {
                protocolData.doseLog[idx] = saved
            }
            StreakManager.shared.logActivity(type: .pin)
            // Final dedup pass
            protocolData.doseLog = Self.dedupDoseLogs(protocolData.doseLog)
        }
    }

    func updateDose(_ dose: DoseLogEntry, doseMcg: Double, site: InjectionSite, notes: String, timestamp: Date) {
        guard let idx = protocolData.doseLog.firstIndex(where: { $0.id == dose.id }) else { return }
        // Optimistic local update
        var updated = DoseLogEntry(
            compoundName: dose.compoundName,
            doseMcg: doseMcg,
            timestamp: timestamp,
            injectionSite: site,
            notes: notes,
            wasSkipped: dose.wasSkipped,
            skipReason: dose.skipReason
        )
        updated.supabaseId = dose.supabaseId
        protocolData.doseLog[idx] = updated

        guard let sid = dose.supabaseId else { return }
        Task {
            do {
                let saved = try await protocolService.updateDoseLog(
                    id: sid,
                    doseMcg: doseMcg,
                    injectionSite: site,
                    notes: notes,
                    loggedAt: timestamp
                )
                if let i = protocolData.doseLog.firstIndex(where: { $0.id == updated.id }) {
                    protocolData.doseLog[i] = saved
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteDose(_ dose: DoseLogEntry) {
        protocolData.doseLog.removeAll { $0.id == dose.id }
        guard let sid = dose.supabaseId else { return }
        Task {
            try? await protocolService.deleteDoseLog(id: sid)
        }
    }

    func logSideEffect(linkedTo dose: DoseLogEntry) {
        newEffectName = ""
        newEffectSeverity = 2
        newEffectNotes = "Linked to \(dose.compoundName) dose at \(dose.timestamp.formatted(date: .abbreviated, time: .shortened))"
        showSideEffectSheet = true
    }

    nonisolated static func dedupDoseLogs(_ logs: [DoseLogEntry]) -> [DoseLogEntry] {
        var seenIds: Set<String> = []
        var seenKeys: Set<String> = []
        var out: [DoseLogEntry] = []
        for entry in logs {
            if let sid = entry.supabaseId {
                if seenIds.contains(sid) { continue }
                seenIds.insert(sid)
            }
            // Bucket timestamp to minute to catch fuzzy duplicates from optimistic + server inserts.
            let bucket = Int(entry.timestamp.timeIntervalSince1970 / 60.0)
            let key = "\(entry.compoundName)|\(entry.doseMcg)|\(bucket)|\(entry.injectionSite.rawValue)"
            if entry.supabaseId == nil {
                if seenKeys.contains(key) { continue }
            }
            seenKeys.insert(key)
            out.append(entry)
        }
        return out
    }

    func skipDose() {
        guard let next = protocolData.smartNextDose() ?? protocolData.compounds.first else { return }
        let reason = skipReason.isEmpty ? "Skipped" : skipReason
        skipReason = ""
        showSkipDoseSheet = false

        guard let protocolId = protocolData.supabaseId else {
            let entry = DoseLogEntry(
                compoundName: next.compoundName,
                doseMcg: 0,
                injectionSite: .leftAbdomen,
                notes: "",
                wasSkipped: true,
                skipReason: reason
            )
            protocolData.doseLog.insert(entry, at: 0)
            return
        }

        Task {
            do {
                let entry = try await protocolService.logDose(
                    protocolId: protocolId,
                    compoundName: next.compoundName,
                    doseMcg: 0,
                    injectionSite: .leftAbdomen,
                    notes: "",
                    wasSkipped: true,
                    skipReason: reason
                )
                protocolData.doseLog.insert(entry, at: 0)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var sortedDoseLog: [DoseLogEntry] {
        Self.dedupDoseLogs(protocolData.doseLog).sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Injection Site Rotation

    func siteRecency(_ site: InjectionSite) -> SiteRecency {
        let logsForSite = protocolData.doseLog
            .filter { $0.injectionSite == site && !$0.wasSkipped }
            .sorted { $0.timestamp > $1.timestamp }
        guard let lastUse = logsForSite.first?.timestamp else { return .unused }
        let daysSince = Calendar.current.dateComponents([.day], from: lastUse, to: Date()).day ?? 0
        if daysSince < 3 { return .overused }
        if daysSince < 7 { return .recentlyUsed }
        return .rotated
    }

    var suggestedNextSite: InjectionSite {
        let logs = protocolData.doseLog.filter { !$0.wasSkipped }
        let lastUseBySite: [InjectionSite: Date] = Dictionary(grouping: logs, by: { $0.injectionSite })
            .compactMapValues { $0.map(\.timestamp).max() }

        let sorted = InjectionSite.allCases.sorted { a, b in
            let aDate = lastUseBySite[a]
            let bDate = lastUseBySite[b]
            switch (aDate, bDate) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (aD?, bD?): return aD < bD
            }
        }
        return sorted.first ?? .leftAbdomen
    }

    // MARK: - Side Effects

    func logSideEffect() {
        guard let protocolId = protocolData.supabaseId else {
            let entry = SideEffectEntry(
                effect: newEffectName,
                severity: newEffectSeverity,
                notes: newEffectNotes
            )
            protocolData.sideEffectLog.insert(entry, at: 0)
            newEffectName = ""
            newEffectSeverity = 2
            newEffectNotes = ""
            showSideEffectSheet = false
            return
        }

        let symptom = newEffectName
        let severity = newEffectSeverity
        let effectNotes = newEffectNotes
        newEffectName = ""
        newEffectSeverity = 2
        newEffectNotes = ""
        showSideEffectSheet = false

        Task {
            do {
                let entry = try await protocolService.logSideEffect(
                    protocolId: protocolId,
                    symptom: symptom,
                    severity: severity,
                    notes: effectNotes
                )
                protocolData.sideEffectLog.insert(entry, at: 0)
                await HealthKitService.shared.saveSymptom(name: symptom, severity: severity)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Supplements

    func addSupplement() {
        guard let protocolId = protocolData.supabaseId else {
            let entry = SupplementEntry(
                name: newSupplementName,
                dose: newSupplementDose,
                frequency: newSupplementFrequency
            )
            protocolData.supplements.append(entry)
            newSupplementName = ""
            newSupplementDose = ""
            newSupplementFrequency = "Daily"
            showAddSupplementSheet = false
            return
        }

        let supplement = SupplementEntry(
            name: newSupplementName,
            dose: newSupplementDose,
            frequency: newSupplementFrequency
        )
        newSupplementName = ""
        newSupplementDose = ""
        newSupplementFrequency = "Daily"
        showAddSupplementSheet = false

        Task {
            do {
                let saved = try await protocolService.addSupplement(supplement, protocolId: protocolId)
                protocolData.supplements.append(saved)
            } catch {
                protocolData.supplements.append(supplement)
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeSupplement(_ entry: SupplementEntry) {
        protocolData.supplements.removeAll { $0.id == entry.id }
        if let supabaseId = entry.supabaseId {
            Task {
                try? await protocolService.deleteSupplement(id: supabaseId)
            }
        }
    }

    // MARK: - Notes

    func addNote(withImage image: UIImage? = nil) {
        let text = newNoteText
        newNoteText = ""
        showAddNoteSheet = false

        let localNote = ProtocolNote(text: text)
        notes.insert(localNote, at: 0)

        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            do {
                var photoUrl: String?
                if let image, let data = image.jpegData(compressionQuality: 0.7) {
                    photoUrl = try? await protocolService.uploadNotePhoto(imageData: data)
                }
                let saved = try await protocolService.addNote(protocolId: protocolId, text: text, photoUrl: photoUrl)
                if let idx = notes.firstIndex(where: { $0.id == localNote.id }) {
                    notes[idx] = saved
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Export / Share

    func exportCSV() {
        let csv = ProtocolExportService.csvForDoctor(protocolData, notes: notes)
        if let url = ProtocolExportService.writeTempFile(csv: csv, filenameHint: protocolData.name) {
            exportURL = url
            showShareSheet = true
        }
    }

    // MARK: - Interactions + Insights

    var drugInteractions: [CompoundInteraction] {
        DrugInteractionDatabase.interactions(among: protocolData.compounds.map(\.compoundName))
    }

    var proactiveInsights: [ProactiveInsight] {
        ProactiveInsightService.insights(
            for: protocolData,
            adherence7d: weeklyAdherence,
            sideEffects: protocolData.sideEffectLog
        )
    }

    // MARK: - Daily Ratings

    func addRating(category: String, value: Int, label: String = "") {
        let today = Calendar.current.startOfDay(for: Date())
        dailyRatings.removeAll { $0.category == category && Calendar.current.isDate($0.date, inSameDayAs: today) }
        let rating = DailyRating(date: today, category: category, value: value, label: label)
        dailyRatings.append(rating)

        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            do {
                try await protocolService.upsertRating(
                    protocolId: protocolId, category: category, value: value, label: label, date: today
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func todayRating(for category: String) -> Int? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyRatings.first { $0.category == category && Calendar.current.isDate($0.date, inSameDayAs: today) }?.value
    }

    // MARK: - Reconstitution

    var reconConcentration: Double? {
        guard let mg = Double(reconPeptideMg), let ml = Double(reconWaterMl), mg > 0, ml > 0 else { return nil }
        return (mg * 1000) / ml
    }

    var reconUnits: Double? {
        guard let conc = reconConcentration, let dose = Double(reconDesiredMcg), conc > 0, dose > 0 else { return nil }
        return (dose / conc) * 100
    }

    // MARK: - Cycle Progress

    var cycleProgressFraction: Double {
        guard let tw = protocolData.totalWeeks, tw > 0 else {
            let etw = protocolData.effectiveTotalWeeks
            guard etw > 0 else { return 0 }
            return min(Double(protocolData.currentDay) / Double(etw * 7), 1.0)
        }
        return min(Double(protocolData.currentDay) / Double(tw * 7), 1.0)
    }

    var currentPhaseProgress: Double {
        let day = protocolData.currentDay
        let phase = protocolData.currentPhase
        let loadDays = (protocolData.loadingWeeks ?? 0) * 7
        let mainDays = (protocolData.maintenanceWeeks ?? 0) * 7
        let taperDays = (protocolData.taperingWeeks ?? 0) * 7
        let offDays = (protocolData.offCycleWeeks ?? 0) * 7

        let raw: Double
        switch phase {
        case .loading:
            raw = loadDays > 0 ? Double(day) / Double(loadDays) : 0
        case .maintenance:
            raw = mainDays > 0 ? Double(day - loadDays) / Double(mainDays) : 0
        case .tapering:
            raw = taperDays > 0 ? Double(day - loadDays - mainDays) / Double(taperDays) : 0
        case .pct, .offCycle:
            raw = offDays > 0 ? Double(day - loadDays - mainDays - taperDays) / Double(offDays) : 0
        }
        return max(0, min(raw, 1.0))
    }

    var daysRemainingInPhase: Int {
        guard protocolData.hasPhases else { return 0 }
        let day = protocolData.currentDay
        let loadDays = (protocolData.loadingWeeks ?? 0) * 7
        let mainDays = (protocolData.maintenanceWeeks ?? 0) * 7
        let taperDays = (protocolData.taperingWeeks ?? 0) * 7
        let offDays = (protocolData.offCycleWeeks ?? 0) * 7

        switch protocolData.currentPhase {
        case .loading: return max(0, loadDays - day)
        case .maintenance: return max(0, (loadDays + mainDays) - day)
        case .tapering: return max(0, (loadDays + mainDays + taperDays) - day)
        case .pct, .offCycle: return max(0, (loadDays + mainDays + taperDays + offDays) - day)
        }
    }

    // MARK: - Adherence

    /// Number of doses expected per week across all compounds (based on frequency strings).
    private func dosesPerWeek(for compound: ProtocolCompound) -> Double {
        let f = compound.frequency.lowercased()
        if f.contains("eod") { return 3.5 }
        if f.contains("as needed") { return 0 }
        if f.contains("3x daily") { return 21 }
        if f.contains("2x daily") || f.contains("twice daily") { return 14 }
        if f.contains("3x weekly") { return 3 }
        if f.contains("2x weekly") { return 2 }
        if f.contains("1x weekly") || f.contains("weekly") { return 1 }
        if f.contains("daily") { return 7 }
        return 7
    }

    /// Fraction 0…1 of doses logged vs expected since protocol start (ignoring skipped days).
    var overallAdherence: Double {
        let weeks = max(1.0, Double(protocolData.currentDay) / 7.0)
        let expected = protocolData.compounds.reduce(0.0) { $0 + dosesPerWeek(for: $1) * weeks }
        guard expected > 0 else { return 0 }
        let logged = Double(protocolData.doseLog.filter { !$0.wasSkipped }.count)
        return min(1.0, logged / expected)
    }

    /// Adherence just for the last 7 days.
    var weeklyAdherence: Double {
        let expected = protocolData.compounds.reduce(0.0) { $0 + dosesPerWeek(for: $1) }
        guard expected > 0 else { return 0 }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let logged = Double(protocolData.doseLog.filter { !$0.wasSkipped && $0.timestamp >= weekAgo }.count)
        return min(1.0, logged / expected)
    }

    var adherenceColor: Color {
        let a = overallAdherence
        if a >= 0.9 { return .green }
        if a >= 0.7 { return PepTheme.teal }
        if a >= 0.5 { return PepTheme.amber }
        return .red
    }

    // MARK: - Supply

    struct SupplyEstimate {
        let compoundName: String
        let mgRemaining: Double?
        let dosesRemaining: Int?
        let daysUntilExpiration: Int?
        let vialSizeMg: Double?
    }

    func supplyEstimate(for compound: ProtocolCompound) -> SupplyEstimate {
        let logs = protocolData.doseLog.filter { $0.compoundName == compound.compoundName && !$0.wasSkipped }
        let totalMcgUsed = logs.reduce(0.0) { $0 + $1.doseMcg }
        let mgRemaining: Double? = compound.vialSizeMg.map { max(0, $0 - totalMcgUsed / 1000.0) }
        let dosesRemaining: Int? = {
            guard let mg = mgRemaining, compound.doseMcg > 0 else { return nil }
            return Int((mg * 1000.0) / compound.doseMcg)
        }()
        let daysUntilExpiration: Int? = compound.expirationDate.flatMap {
            Calendar.current.dateComponents([.day], from: Date(), to: $0).day
        }
        return SupplyEstimate(
            compoundName: compound.compoundName,
            mgRemaining: mgRemaining,
            dosesRemaining: dosesRemaining,
            daysUntilExpiration: daysUntilExpiration,
            vialSizeMg: compound.vialSizeMg
        )
    }

    // MARK: - Side Effect Trends

    struct SideEffectTrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let severity: Double
        let effect: String
    }

    var sideEffectTrend: [SideEffectTrendPoint] {
        protocolData.sideEffectLog
            .sorted { $0.timestamp < $1.timestamp }
            .map { SideEffectTrendPoint(date: $0.timestamp, severity: Double($0.severity), effect: $0.effect) }
    }

    // MARK: - Category Helpers

    var isWeightLoss: Bool { protocolData.goal == .weightLoss }
    var isHealing: Bool { protocolData.goal == .healing }
    var isMuscleGrowth: Bool { protocolData.goal == .muscleGrowth }
    var isCognitive: Bool { protocolData.goal == .cognitive }
    var isTanning: Bool { protocolData.goal == .tanning }
    var isCustom: Bool { protocolData.goal == .custom }

    var hasInjectableCompound: Bool {
        protocolData.compounds.contains { $0.injectionRoute == .subcutaneous || $0.injectionRoute == .intramuscular }
    }

    var smartNextDose: ProtocolCompound? {
        protocolData.smartNextDose()
    }

    // MARK: - Setup

    private func setupTitrationSteps() {
        // Prefer the user-authored schedule from AddVialFlow / TitrationBuilder.
        if let stored = TitrationScheduleStore.shared.schedule(for: protocolData.id) {
            titrationSteps = stepsFromStoredSchedule(stored)
            return
        }
        guard protocolData.goal == .weightLoss else { return }
        titrationSteps = [
            TitrationStep(weekNumber: 1, doseMcg: 250, label: "Starting Dose", isCompleted: protocolData.currentDay > 7),
            TitrationStep(weekNumber: 2, doseMcg: 500, label: "First Increase", isCompleted: protocolData.currentDay > 14),
            TitrationStep(weekNumber: 4, doseMcg: 1000, label: "Mid Titration", isCompleted: protocolData.currentDay > 28),
            TitrationStep(weekNumber: 6, doseMcg: 1700, label: "Approaching Target", isCompleted: protocolData.currentDay > 42),
            TitrationStep(weekNumber: 8, doseMcg: 2400, label: "Target Dose"),
        ]
    }

    /// Returns the user's saved titration schedule (from AddVialFlow or the
    /// in-app builder), if one exists for this protocol.
    var currentTitrationSchedule: TitrationSchedule? {
        TitrationScheduleStore.shared.schedule(for: protocolData.id)
    }

    /// Convert the persisted schedule into the detail view's TitrationStep rows,
    /// preserving completion state from the existing in-memory steps.
    private func stepsFromStoredSchedule(_ schedule: TitrationSchedule) -> [TitrationStep] {
        let day = protocolData.currentDay
        return schedule.sortedSteps.map { step in
            let existing = titrationSteps.first(where: { $0.weekNumber == step.week })
            let auto = day > step.week * 7
            return TitrationStep(
                weekNumber: step.week,
                doseMcg: step.doseMcg,
                label: step.label,
                isCompleted: existing?.isCompleted ?? auto
            )
        }
    }

    /// Persist a titration schedule edit and refresh the section.
    func saveTitrationSchedule(_ schedule: TitrationSchedule) {
        TitrationScheduleStore.shared.save(schedule)
        titrationSteps = stepsFromStoredSchedule(schedule)
    }

    private func setupRecoveryMilestones() {
        guard protocolData.goal == .healing else { return }
        recoveryMilestones = [
            RecoveryMilestone(title: "Reduced pain at rest"),
            RecoveryMilestone(title: "Pain-free walking"),
            RecoveryMilestone(title: "Light training resumed"),
            RecoveryMilestone(title: "Full range of motion"),
            RecoveryMilestone(title: "Return to full activity"),
        ]
    }

    func refreshFromSupabase() {
        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            do {
                isLoading = true
                async let doseLogsTask = protocolService.fetchDoseLogs(protocolId: protocolId)
                async let sideEffectsTask = protocolService.fetchSideEffects(protocolId: protocolId)
                async let supplementsTask = protocolService.fetchSupplements(protocolId: protocolId)
                async let notesTask = protocolService.fetchNotes(protocolId: protocolId)
                async let ratingsTask = protocolService.fetchRatings(protocolId: protocolId)
                async let milestonesTask = protocolService.fetchMilestones(protocolId: protocolId)
                async let titrationTask = protocolService.fetchTitrationSteps(protocolId: protocolId)

                protocolData.doseLog = Self.dedupDoseLogs(try await doseLogsTask)
                protocolData.sideEffectLog = try await sideEffectsTask
                protocolData.supplements = try await supplementsTask
                notes = try await notesTask
                dailyRatings = try await ratingsTask

                let fetchedMilestones = try await milestonesTask
                if !fetchedMilestones.isEmpty {
                    mergeMilestones(fetchedMilestones)
                }

                let fetchedTitration = try await titrationTask
                if !fetchedTitration.isEmpty {
                    mergeTitration(fetchedTitration)
                }
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func mergeMilestones(_ remote: [RecoveryMilestone]) {
        for r in remote {
            if let idx = recoveryMilestones.firstIndex(where: { $0.title == r.title }) {
                recoveryMilestones[idx].isAchieved = r.isAchieved
                recoveryMilestones[idx].achievedDate = r.achievedDate
            }
        }
    }

    private func mergeTitration(_ remote: [TitrationStep]) {
        for r in remote {
            if let idx = titrationSteps.firstIndex(where: { $0.weekNumber == r.weekNumber }) {
                titrationSteps[idx].isCompleted = r.isCompleted
            }
        }
    }

    func archiveProtocol() {
        let localId = protocolData.id
        protocolData.isActive = false
        NotificationCenter.default.post(
            name: .supabaseDataChanged,
            object: nil,
            userInfo: [
                "source": "protocol_archive",
                "protocol_local_id": localId.uuidString,
                "protocol_supabase_id": protocolData.supabaseId ?? ""
            ]
        )
        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            do {
                try await protocolService.updateProtocolStatus(id: protocolId, isActive: false)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func reactivateProtocol() {
        let localId = protocolData.id
        protocolData.isActive = true
        NotificationCenter.default.post(
            name: .supabaseDataChanged,
            object: nil,
            userInfo: [
                "source": "protocol_reactivate",
                "protocol_local_id": localId.uuidString,
                "protocol_supabase_id": protocolData.supabaseId ?? ""
            ]
        )
        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            do {
                try await protocolService.updateProtocolStatus(id: protocolId, isActive: true)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteProtocol() {
        let localId = protocolData.id
        guard let protocolId = protocolData.supabaseId else {
            didDelete = true
            NotificationCenter.default.post(
                name: .supabaseDataChanged,
                object: nil,
                userInfo: [
                    "source": "protocol_delete",
                    "protocol_local_id": localId.uuidString
                ]
            )
            return
        }
        // Optimistically dismiss + tell the rest of the app to drop this
        // protocol from local caches so it doesn't reappear before the
        // background delete completes.
        didDelete = true
        NotificationCenter.default.post(
            name: .supabaseDataChanged,
            object: nil,
            userInfo: [
                "source": "protocol_delete",
                "protocol_local_id": localId.uuidString,
                "protocol_supabase_id": protocolId
            ]
        )
        Task {
            do {
                try await protocolService.deleteProtocol(id: protocolId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleMilestone(_ milestone: RecoveryMilestone) {
        guard let idx = recoveryMilestones.firstIndex(where: { $0.id == milestone.id }) else { return }
        recoveryMilestones[idx].isAchieved.toggle()
        let achieved = recoveryMilestones[idx].isAchieved
        recoveryMilestones[idx].achievedDate = achieved ? Date() : nil
        let title = recoveryMilestones[idx].title
        let achievedAt = recoveryMilestones[idx].achievedDate

        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            try? await protocolService.upsertMilestone(
                protocolId: protocolId, title: title, isAchieved: achieved, achievedAt: achievedAt
            )
        }
    }

    func toggleTitrationStep(_ step: TitrationStep) {
        guard let idx = titrationSteps.firstIndex(where: { $0.id == step.id }) else { return }
        titrationSteps[idx].isCompleted.toggle()
        let completed = titrationSteps[idx].isCompleted
        let week = titrationSteps[idx].weekNumber
        let dose = titrationSteps[idx].doseMcg
        let label = titrationSteps[idx].label

        guard let protocolId = protocolData.supabaseId else { return }
        Task {
            try? await protocolService.upsertTitrationStep(
                protocolId: protocolId, weekNumber: week, doseMcg: dose, label: label, isCompleted: completed
            )
        }
    }
}

nonisolated enum SiteRecency: Sendable {
    case unused, rotated, recentlyUsed, overused

    var color: Color {
        switch self {
        case .unused: return .gray.opacity(0.3)
        case .rotated: return .green
        case .recentlyUsed: return .yellow
        case .overused: return .red
        }
    }
}
