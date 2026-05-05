import Foundation
import SwiftUI
import Supabase

@Observable
final class OnboardingState {
    var step: OnboardingStep = .welcome
    var personaTrack: PersonaTrack?
    var disclaimerAcceptedAt: Date?
    var disclaimerVersion: String = OnboardingManager.disclaimerVersion

    var email: String = ""
    var password: String = ""
    var username: String = ""
    var fullName: String = ""

    // Social identity
    var avatarColorHex: String? = nil
    var avatarImageData: Data? = nil
    var avatarImageURL: String? = nil
    var usernameAvailability: UsernameAvailability = .idle
    var usernameCheckTask: Task<Void, Never>? = nil

    var firstName: String = ""
    var dateOfBirth: Date?
    var biologicalSex: BiologicalSex?
    var isPregnantOrNursing: Bool?

    var unitSystem: UnitSystem = .imperial
    var heightCm: Double?
    var weightKg: Double?
    var bodyFatPercent: Double?
    var neckCm: Double?
    var waistCm: Double?
    var hipCm: Double?
    var activityLevel: ActivityLevel?

    var bmrKcal: Double?
    var tdeeKcal: Double?
    var starterMacros: MacroTarget?
    var dailyWaterMl: Int?
    var dailyStepFloor: Int?

    // Goals chapter
    var primaryGoal: PrimaryGoal?
    var secondaryGoal: PrimaryGoal?
    var targetWeightKg: Double?
    var targetBodyFatPercent: Double?
    var targetPerformanceMetric: String = ""
    var targetDate: Date?

    var sessionsPerWeek: Int = 3
    var trainingModalities: Set<TrainingModality> = []
    var experienceLevel: TrainingExperience?
    var currentProgramName: String = ""
    var injuries: Set<InjuryArea> = []
    var otherInjuryNote: String = ""

    var dietStyle: DietStyle?
    var priorTracker: PriorTracker?
    var proteinPerKgOverride: Double?
    var allergies: Set<String> = []
    var allergiesOther: String = ""
    var restrictions: Set<String> = []
    var restrictionsOther: String = ""

    var goalDefaults: GoalSmartDefaults?

    var isSubmitting: Bool = false
    var errorMessage: String?

    var ageInYears: Int? {
        guard let dob = dateOfBirth else { return nil }
        let comps = Calendar.current.dateComponents([.year], from: dob, to: Date())
        return comps.year
    }

    var isUnder18: Bool {
        if let age = ageInYears { return age < 18 }
        return false
    }

    var canAccessCompoundSurfaces: Bool {
        guard disclaimerAcceptedAt != nil else { return false }
        guard let age = ageInYears, age >= 18 else { return false }
        if biologicalSex == .female, isPregnantOrNursing == true { return false }
        return true
    }

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .welcome: return true
        case .disclaimer: return disclaimerAcceptedAt != nil
        case .persona: return personaTrack != nil
        case .account:
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedEmail.isEmpty && password.count >= 6
        case .socialIdentity:
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard SocialIdentityRules.isValidFormat(trimmed) else { return false }
            if case .available = usernameAvailability { return true }
            if case .idle = usernameAvailability, !trimmed.isEmpty { return false }
            return false
        case .aboutYou:
            guard dateOfBirth != nil, biologicalSex != nil, activityLevel != nil else { return false }
            guard let h = heightCm, (120.0...230.0).contains(h) else { return false }
            guard let w = weightKg, (30.0...250.0).contains(w) else { return false }
            if let bf = bodyFatPercent, !(3.0...60.0).contains(bf) { return false }
            let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedName.isEmpty
        case .ageBlocked:
            return false
        case .pregnancyGate:
            return isPregnantOrNursing != nil
        case .goals:
            return primaryGoal != nil
        default: return true
        }
    }

    func clearUsernameCheck() {
        usernameCheckTask?.cancel()
        usernameCheckTask = nil
    }

    func shouldShow(chapter: OnboardingChapter) -> Bool {
        switch chapter {
        case .welcome, .aboutYou, .connect, .goals, .finish:
            return true
        case .journey:
            return true
        }
    }

    /// Computes the next step, honoring age + pregnancy branches.
    func nextStep(from step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .aboutYou:
            if isUnder18 { return .ageBlocked }
            if biologicalSex == .female { return .pregnancyGate }
            return .connect
        case .ageBlocked:
            return nil
        case .pregnancyGate:
            return .connect
        default:
            guard let current = OnboardingStep.allCases.firstIndex(of: step) else { return nil }
            let nextIndex = current + 1
            guard nextIndex < OnboardingStep.allCases.count else { return nil }
            let candidate = OnboardingStep.allCases[nextIndex]
            if candidate == .ageBlocked || candidate == .pregnancyGate {
                return .connect
            }
            return candidate
        }
    }

    func previousStep(from step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .ageBlocked, .pregnancyGate:
            return .aboutYou
        case .connect:
            if biologicalSex == .female { return .pregnancyGate }
            return .aboutYou
        default:
            guard let current = OnboardingStep.allCases.firstIndex(of: step), current > 0 else { return nil }
            return OnboardingStep.allCases[current - 1]
        }
    }
}

enum OnboardingManager {
    static let completedKey = "peppal.onboarding.completed.v1"
    static let disclaimerVersion = "v1"
    static let draftKey = "peppal.onboarding.draft.v1"
    static let chapterCheckpointKey = "peppal.onboarding.currentChapter.v1"

    // Success-card pending flag + cached personalization counts surfaced on Home day-1.
    static let successCardPendingKey = "peppal.home.onboardingSuccessCard.pending.v1"
    static let successFactCountKey = "peppal.onboarding.successCard.facts.v1"
    static let successHKDaysKey = "peppal.onboarding.successCard.hkDays.v1"
    static let successPinCountKey = "peppal.onboarding.successCard.pins.v1"
    static let successProtocolKey = "peppal.onboarding.successCard.protocol.v1"
    static let successFirstNameKey = "peppal.onboarding.successCard.firstName.v1"

    static func stageSuccessCardCounts(
        firstName: String,
        factCount: Int,
        hkDays: Int,
        pinCount: Int,
        protocolDescription: String?
    ) {
        let d = UserDefaults.standard
        d.set(true, forKey: successCardPendingKey)
        d.set(factCount, forKey: successFactCountKey)
        d.set(hkDays, forKey: successHKDaysKey)
        d.set(pinCount, forKey: successPinCountKey)
        d.set(firstName, forKey: successFirstNameKey)
        if let proto = protocolDescription, !proto.isEmpty {
            d.set(proto, forKey: successProtocolKey)
        } else {
            d.removeObject(forKey: successProtocolKey)
        }
    }

    static func dismissSuccessCard() {
        UserDefaults.standard.set(false, forKey: successCardPendingKey)
    }

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
        clearDraft()
    }

    /// Hydrates `PeptideAccessManager.personaTrack` from `profiles.persona_track` on launch / auth change.
    /// Source of truth is Supabase — local UserDefaults are a cache only.
    static func hydratePersonaFromRemote() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        guard let profile = try? await ProfileService.shared.fetchProfile(userId: userId) else { return }
        let remote = (profile as Any) as? SupabaseProfile
        _ = remote
        // SupabaseProfile doesn't currently surface persona_track — fetch it directly.
        struct PersonaRow: Decodable, Sendable { let persona_track: String? }
        do {
            let row: PersonaRow = try await SupabaseService.shared.client
                .from("profiles")
                .select("persona_track")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            if let raw = row.persona_track, let track = PersonaTrack(rawValue: raw) {
                await MainActor.run {
                    PeptideAccessManager.shared.personaTrack = track
                }
            }
        } catch {
            print("OnboardingManager.hydratePersonaFromRemote failed: \(error)")
        }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        clearDraft()
    }

    /// Notification fired when QA wants to re-run onboarding immediately on
    /// the current account (without relaunching the app). `ContentView`
    /// observes and re-presents `OnboardingFlowView` as a full-screen cover.
    static let rerunRequested = Notification.Name("peppal.onboarding.rerunRequested")

    /// Force the onboarding flow to re-present right now on the current
    /// account. Useful for QA on partially-complete accounts: clears the
    /// local completion flag + draft + chapter checkpoint and posts a
    /// notification so the UI re-presents the flow without a relaunch.
    /// Supabase rows are intentionally left intact so partial state is
    /// preserved and the user can correct it through the flow.
    @MainActor
    static func rerunNow() {
        reset()
        NotificationCenter.default.post(name: rerunRequested, object: nil)
    }

    /// Result of the remote-profile completeness check.
    /// - `complete`: profile has all required onboarding fields → trust the existing account, no re-onboarding.
    /// - `incomplete`: signed-in user is missing one or more required fields → must run onboarding.
    /// - `unknown`: network/decoding error — leave local flag untouched, don't force onboarding.
    enum RemoteCompletionState: Sendable {
        case complete
        case incomplete
        case unknown
    }

    /// Fetches the signed-in user's profile and decides whether onboarding has
    /// already been completed server-side. Source of truth is Supabase — local
    /// `completedKey` is only a cache. This catches pre-onboarding accounts
    /// (created before the flow existed) and cross-device sign-ins where the
    /// local flag isn't set.
    static func evaluateRemoteCompletion() async -> RemoteCompletionState {
        guard let userId = try? AuthService.shared.currentUserId() else { return .unknown }
        struct ProfileShape: Decodable, Sendable {
            let persona_track: String?
            let date_of_birth: String?
            let primary_goal: String?
            let display_name: String?
            let biological_sex: String?
        }
        do {
            let row: ProfileShape = try await SupabaseService.shared.client
                .from("profiles")
                .select("persona_track, date_of_birth, primary_goal, display_name, biological_sex")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            // Minimum fields that prove the user has been through the flow.
            let hasPersona = (row.persona_track?.isEmpty == false)
            let hasDOB = (row.date_of_birth?.isEmpty == false)
            let hasName = (row.display_name?.trimmingCharacters(in: .whitespaces).isEmpty == false)
            let hasSex = (row.biological_sex?.isEmpty == false)
            // primary_goal is a strong signal but not strictly required (Track B/C may skip),
            // so weight it as one of several markers. Require persona + DOB + (name OR sex).
            if hasPersona, hasDOB, (hasName || hasSex) {
                return .complete
            }
            return .incomplete
        } catch {
            print("OnboardingManager.evaluateRemoteCompletion failed: \(error)")
            return .unknown
        }
    }

    /// Reconciles local completion flag with remote profile state. Call after
    /// sign-in. Returns whether onboarding should be presented.
    @discardableResult
    static func reconcileCompletionAfterSignIn() async -> Bool {
        let remote = await evaluateRemoteCompletion()
        switch remote {
        case .complete:
            // Existing fully-onboarded account — trust it, mark local cache.
            UserDefaults.standard.set(true, forKey: completedKey)
            clearDraft()
            return false
        case .incomplete:
            // Pre-onboarding account or cross-device fresh install — force onboarding.
            UserDefaults.standard.removeObject(forKey: completedKey)
            return true
        case .unknown:
            // Network/decoding hiccup — fall back to local cache.
            return !hasCompleted
        }
    }

    static func saveDraft(_ draft: OnboardingDraft) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(draft) else { return }
        let d = UserDefaults.standard
        d.set(data, forKey: draftKey)
        d.set(draft.step, forKey: chapterCheckpointKey)
    }

    static func loadDraft() -> OnboardingDraft? {
        guard let data = UserDefaults.standard.data(forKey: draftKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OnboardingDraft.self, from: data)
    }

    static func clearDraft() {
        let d = UserDefaults.standard
        d.removeObject(forKey: draftKey)
        d.removeObject(forKey: chapterCheckpointKey)
    }

    static func persistPersona(_ persona: PersonaTrack) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        struct PersonaUpdate: Encodable { let persona_track: String }
        let payload = OnboardingPayloads.Persona(personaTrack: persona.rawValue)
        await OnboardingSyncQueue.shared.enqueue(kind: .persona, userId: userId, payload: payload)
        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(PersonaUpdate(persona_track: persona.rawValue))
                .eq("id", value: userId)
                .execute()
            await OnboardingSyncQueue.shared.flushNow()
        } catch {
            print("OnboardingManager.persistPersona failed (queued for retry): \(error)")
        }
    }

    static func persistSocialIdentity(
        username: String,
        avatarColorHex: String?,
        avatarImageData: Data?
    ) async -> String? {
        guard let userId = try? AuthService.shared.currentUserId() else { return nil }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        var avatarURL: String? = nil
        if let data = avatarImageData {
            do {
                avatarURL = try await ProfileService.shared.uploadAvatar(userId: userId, imageData: data)
            } catch {
                print("OnboardingManager.persistSocialIdentity avatar upload failed: \(error)")
            }
        }

        let update = ProfileUpdate(
            display_name: nil,
            username: trimmed.isEmpty ? nil : trimmed,
            bio: nil,
            avatar_url: avatarURL,
            avatar_color: avatarColorHex,
            banner_url: nil,
            active_program: nil,
            date_of_birth: nil,
            biological_sex: nil,
            height_cm: nil,
            is_private: nil,
            medical_disclaimer_accepted_at: nil
        )

        let payload = OnboardingPayloads.SocialIdentity(
            username: trimmed.isEmpty ? nil : trimmed,
            avatar_url: avatarURL,
            avatar_color: avatarColorHex
        )
        await OnboardingSyncQueue.shared.enqueue(kind: .socialIdentity, userId: userId, payload: payload)

        do {
            try await ProfileService.shared.updateProfile(userId: userId, update: update)
            await OnboardingSyncQueue.shared.flushNow()
        } catch {
            print("OnboardingManager.persistSocialIdentity failed (queued for retry): \(error)")
        }
        return avatarURL
    }

    /// Returns true when the trimmed handle is not yet taken by another user.
    /// Case-insensitive match. Excludes the signed-in user's existing row
    /// (so reopening the step shows their own handle as available).
    static func isUsernameAvailable(_ username: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SocialIdentityRules.isValidFormat(trimmed) else { return false }
        let myUserId = try? AuthService.shared.currentUserId()
        struct Row: Decodable, Sendable { let id: String; let username: String? }
        do {
            let rows: [Row] = try await SupabaseService.shared.client
                .from("profiles")
                .select("id, username")
                .ilike("username", pattern: trimmed)
                .limit(2)
                .execute()
                .value
            // Available if no rows OR the only row is mine.
            if rows.isEmpty { return true }
            if rows.count == 1, let me = myUserId, rows[0].id == me { return true }
            return false
        } catch {
            print("OnboardingManager.isUsernameAvailable check failed: \(error)")
            // Fail-open: don't block users on transient network errors.
            return true
        }
    }

    static func persistAboutYou(
        firstName: String,
        dateOfBirth: Date,
        biologicalSex: BiologicalSex,
        heightCm: Double,
        weightKg: Double,
        bodyFatPercent: Double?,
        activityLevel: ActivityLevel
    ) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let dobFormatter = DateFormatter()
        dobFormatter.dateFormat = "yyyy-MM-dd"
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let update = ProfileUpdate(
            display_name: trimmedName.isEmpty ? nil : trimmedName,
            username: nil,
            bio: nil,
            avatar_url: nil,
            avatar_color: nil,
            banner_url: nil,
            active_program: nil,
            date_of_birth: dobFormatter.string(from: dateOfBirth),
            biological_sex: biologicalSex.rawValue,
            height_cm: heightCm,
            is_private: nil,
            medical_disclaimer_accepted_at: nil
        )
        try? await ProfileService.shared.updateProfile(userId: userId, update: update)

        struct AboutYouExtras: Encodable {
            let weight_kg: Double
            let body_fat_percent: Double?
            let activity_level: String
        }
        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(AboutYouExtras(
                    weight_kg: weightKg,
                    body_fat_percent: bodyFatPercent,
                    activity_level: activityLevel.rawValue
                ))
                .eq("id", value: userId)
                .execute()
        } catch {
            print("OnboardingManager.persistAboutYou extras failed: \(error)")
        }

        UserDefaults.standard.set(UnitConversion.kgToPounds(weightKg), forKey: PrefKey.cachedWeightLbs.rawValue)

        // Enqueue a single combined payload so a network blip after the
        // first update but before the second still recovers cleanly.
        let trimmedNameForQueue = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let queuedPayload = OnboardingPayloads.AboutYou(
            display_name: trimmedNameForQueue.isEmpty ? nil : trimmedNameForQueue,
            date_of_birth: dobFormatter.string(from: dateOfBirth),
            biological_sex: biologicalSex.rawValue,
            height_cm: heightCm,
            weight_kg: weightKg,
            body_fat_percent: bodyFatPercent,
            activity_level: activityLevel.rawValue
        )
        await OnboardingSyncQueue.shared.enqueue(kind: .aboutYou, userId: userId, payload: queuedPayload)
        await OnboardingSyncQueue.shared.flushNow()
    }

    static func persistPregnancyAnswer(_ isPregnantOrNursing: Bool) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        struct PregnancyUpdate: Encodable { let is_pregnant_or_nursing: Bool }
        let payload = OnboardingPayloads.Pregnancy(is_pregnant_or_nursing: isPregnantOrNursing)
        await OnboardingSyncQueue.shared.enqueue(kind: .pregnancy, userId: userId, payload: payload)
        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(PregnancyUpdate(is_pregnant_or_nursing: isPregnantOrNursing))
                .eq("id", value: userId)
                .execute()
            await OnboardingSyncQueue.shared.flushNow()
        } catch {
            print("OnboardingManager.persistPregnancyAnswer failed (queued for retry): \(error)")
        }
    }

    struct GoalsSnapshot: Sendable {
        let primary: PrimaryGoal?
        let secondary: PrimaryGoal?
        let targetWeightKg: Double?
        let targetBodyFat: Double?
        let targetPerformance: String
        let targetDate: Date?
        let sessionsPerWeek: Int
        let modalities: Set<TrainingModality>
        let experience: TrainingExperience?
        let currentProgram: String
        let injuries: Set<InjuryArea>
        let otherInjury: String
        let dietStyle: DietStyle?
        let priorTracker: PriorTracker?
        let proteinPerKg: Double?
        let allergies: Set<String>
        let restrictions: Set<String>
        let defaults: GoalSmartDefaults?
    }

    static func persistGoals(_ snapshot: GoalsSnapshot) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }

        struct GoalsUpdate: Encodable {
            let primary_goal: String?
            let secondary_goal: String?
            let target_weight_kg: Double?
            let target_body_fat_percent: Double?
            let target_performance_metric: String?
            let target_date: String?
            let sessions_per_week: Int?
            let training_modalities: [String]?
            let experience_level: String?
            let current_program: String?
            let injuries: [String]?
            let other_injury_note: String?
            let diet_style: String?
            let prior_tracker: String?
            let protein_per_kg: Double?
            let allergies: [String]?
            let restrictions: [String]?
            let starter_calories: Int?
            let starter_protein_g: Int?
            let starter_carbs_g: Int?
            let starter_fat_g: Int?
            let daily_water_ml: Int?
            let daily_step_floor: Int?
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let trimmedPerf = snapshot.targetPerformance.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProgram = snapshot.currentProgram.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInjuryNote = snapshot.otherInjury.trimmingCharacters(in: .whitespacesAndNewlines)

        let update = GoalsUpdate(
            primary_goal: snapshot.primary?.rawValue,
            secondary_goal: snapshot.secondary?.rawValue,
            target_weight_kg: snapshot.targetWeightKg,
            target_body_fat_percent: snapshot.targetBodyFat,
            target_performance_metric: trimmedPerf.isEmpty ? nil : trimmedPerf,
            target_date: snapshot.targetDate.map { dateFormatter.string(from: $0) },
            sessions_per_week: snapshot.sessionsPerWeek,
            training_modalities: snapshot.modalities.isEmpty ? nil : snapshot.modalities.map { $0.rawValue }.sorted(),
            experience_level: snapshot.experience?.rawValue,
            current_program: trimmedProgram.isEmpty ? nil : trimmedProgram,
            injuries: snapshot.injuries.isEmpty ? nil : snapshot.injuries.map { $0.rawValue }.sorted(),
            other_injury_note: trimmedInjuryNote.isEmpty ? nil : trimmedInjuryNote,
            diet_style: snapshot.dietStyle?.rawValue,
            prior_tracker: snapshot.priorTracker?.rawValue,
            protein_per_kg: snapshot.proteinPerKg,
            allergies: snapshot.allergies.isEmpty ? nil : Array(snapshot.allergies).sorted(),
            restrictions: snapshot.restrictions.isEmpty ? nil : Array(snapshot.restrictions).sorted(),
            starter_calories: snapshot.defaults?.calories,
            starter_protein_g: snapshot.defaults?.proteinG,
            starter_carbs_g: snapshot.defaults?.carbsG,
            starter_fat_g: snapshot.defaults?.fatG,
            daily_water_ml: snapshot.defaults?.waterMl,
            daily_step_floor: snapshot.defaults?.stepFloor
        )

        let queued = OnboardingPayloads.Goals(
            primary_goal: snapshot.primary?.rawValue,
            secondary_goal: snapshot.secondary?.rawValue,
            target_weight_kg: snapshot.targetWeightKg,
            target_body_fat_percent: snapshot.targetBodyFat,
            target_performance_metric: trimmedPerf.isEmpty ? nil : trimmedPerf,
            target_date: snapshot.targetDate.map { dateFormatter.string(from: $0) },
            sessions_per_week: snapshot.sessionsPerWeek,
            training_modalities: snapshot.modalities.isEmpty ? nil : snapshot.modalities.map { $0.rawValue }.sorted(),
            experience_level: snapshot.experience?.rawValue,
            current_program: trimmedProgram.isEmpty ? nil : trimmedProgram,
            injuries: snapshot.injuries.isEmpty ? nil : snapshot.injuries.map { $0.rawValue }.sorted(),
            other_injury_note: trimmedInjuryNote.isEmpty ? nil : trimmedInjuryNote,
            diet_style: snapshot.dietStyle?.rawValue,
            prior_tracker: snapshot.priorTracker?.rawValue,
            protein_per_kg: snapshot.proteinPerKg,
            allergies: snapshot.allergies.isEmpty ? nil : Array(snapshot.allergies).sorted(),
            restrictions: snapshot.restrictions.isEmpty ? nil : Array(snapshot.restrictions).sorted(),
            starter_calories: snapshot.defaults?.calories,
            starter_protein_g: snapshot.defaults?.proteinG,
            starter_carbs_g: snapshot.defaults?.carbsG,
            starter_fat_g: snapshot.defaults?.fatG,
            daily_water_ml: snapshot.defaults?.waterMl,
            daily_step_floor: snapshot.defaults?.stepFloor
        )
        await OnboardingSyncQueue.shared.enqueue(kind: .goals, userId: userId, payload: queued)

        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
            await OnboardingSyncQueue.shared.flushNow()
        } catch {
            print("OnboardingManager.persistGoals failed (queued for retry): \(error)")
        }
    }

    static func persistProtocolChapter(
        compounds: [ProtocolCompound],
        preferredSites: Set<InjectionSite>,
        reminderStyle: ReminderStyle,
        morningBriefTime: Date,
        doseReminderTime: Date,
        personaTrack: PersonaTrack
    ) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }

        if !compounds.isEmpty {
            let proto = PeptideProtocol(
                name: "My Protocol",
                goal: .general,
                compounds: compounds,
                startDate: Date(),
                totalWeeks: 12,
                isActive: true
            )
            do {
                _ = try await ProtocolService.shared.createProtocol(proto)
            } catch {
                print("OnboardingManager.persistProtocolChapter create failed: \(error)")
            }
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        struct ProtocolChapterUpdate: Encodable {
            let preferred_injection_sites: [String]?
            let reminder_style: String
            let morning_brief_time: String
            let dose_reminder_time: String
        }
        let update = ProtocolChapterUpdate(
            preferred_injection_sites: preferredSites.isEmpty ? nil : preferredSites.map { $0.rawValue }.sorted(),
            reminder_style: reminderStyle.rawValue,
            morning_brief_time: timeFormatter.string(from: morningBriefTime),
            dose_reminder_time: timeFormatter.string(from: doseReminderTime)
        )
        let queued = OnboardingPayloads.ProtocolChapter(
            preferred_injection_sites: preferredSites.isEmpty ? nil : preferredSites.map { $0.rawValue }.sorted(),
            reminder_style: reminderStyle.rawValue,
            morning_brief_time: timeFormatter.string(from: morningBriefTime),
            dose_reminder_time: timeFormatter.string(from: doseReminderTime)
        )
        await OnboardingSyncQueue.shared.enqueue(kind: .protocolChapter, userId: userId, payload: queued)

        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
            await OnboardingSyncQueue.shared.flushNow()
        } catch {
            print("OnboardingManager.persistProtocolChapter profile update failed (queued for retry): \(error)")
        }
        _ = personaTrack
    }

    static func persistDisclaimerAcknowledgement(version: String, acceptedAt: Date) async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let iso = ISO8601DateFormatter().string(from: acceptedAt)
        let row = DisclaimerAcknowledgement(user_id: userId, version: version, accepted_at: iso)
        // Always enqueue first so a flaky network can't drop the audit row.
        await OnboardingSyncQueue.shared.enqueue(kind: .disclaimerAck, userId: userId, payload: row)
        do {
            try await SupabaseService.shared.client
                .from("disclaimer_acknowledgements")
                .insert(row)
                .execute()
            await OnboardingSyncQueue.shared.flushNow()
        } catch {
            print("OnboardingManager.persistDisclaimerAcknowledgement failed (queued for retry): \(error)")
        }
        UserDefaults.standard.set(true, forKey: MedicalDisclaimerManager.acceptedKey)
        UserDefaults.standard.set(acceptedAt, forKey: MedicalDisclaimerManager.acceptedDateKey)
        UserDefaults.standard.set(version, forKey: MedicalDisclaimerManager.acceptedVersionKey)
        await MedicalDisclaimerManager.persistAcceptance(at: acceptedAt)
    }
}

/*
 SUPABASE MIGRATION (run once):

 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS persona_track text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_pregnant_or_nursing boolean;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS weight_kg double precision;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS body_fat_percent double precision;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS activity_level text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS primary_goal text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS secondary_goal text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_weight_kg double precision;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_body_fat_percent double precision;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_performance_metric text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS target_date date;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS sessions_per_week integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS training_modalities text[];
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS experience_level text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_program text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS injuries text[];
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS other_injury_note text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diet_style text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS prior_tracker text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS protein_per_kg double precision;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS allergies text[];
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS restrictions text[];
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS starter_calories integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS starter_protein_g integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS starter_carbs_g integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS starter_fat_g integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_water_ml integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS daily_step_floor integer;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS preferred_injection_sites text[];
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reminder_style text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS morning_brief_time text;
 ALTER TABLE profiles ADD COLUMN IF NOT EXISTS dose_reminder_time text;

 CREATE TABLE IF NOT EXISTS disclaimer_acknowledgements (
   id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
   version text NOT NULL,
   accepted_at timestamptz NOT NULL DEFAULT now(),
   created_at timestamptz NOT NULL DEFAULT now()
 );
 ALTER TABLE disclaimer_acknowledgements ENABLE ROW LEVEL SECURITY;
 CREATE POLICY "users insert own ack" ON disclaimer_acknowledgements
   FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
 CREATE POLICY "users read own ack" ON disclaimer_acknowledgements
   FOR SELECT TO authenticated USING (auth.uid() = user_id);
 */
