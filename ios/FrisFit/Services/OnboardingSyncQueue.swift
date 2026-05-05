import Foundation
import Supabase

/// Disk-backed retry queue for onboarding Supabase writes. The persist*
/// functions in `OnboardingManager` are fire-and-forget awaits — if the
/// network blips mid-chapter the row is silently lost. Every persist call
/// now also enqueues a task here. The queue replays pending tasks when
/// connectivity returns or auth becomes valid.
nonisolated enum OnboardingSyncTaskKind: String, Codable, Sendable {
    case persona
    case aboutYou
    case pregnancy
    case goals
    case protocolChapter
    case disclaimerAck
    case socialIdentity
}

nonisolated struct OnboardingSyncTask: Codable, Sendable, Identifiable {
    let id: UUID
    let kind: OnboardingSyncTaskKind
    let userId: String
    /// Opaque JSON payload. Each kind decodes its own shape from this string.
    let payloadJSON: String
    let createdAt: Date
    var attempts: Int
    var lastError: String?
    var nextAttemptAt: Date

    init(
        id: UUID = UUID(),
        kind: OnboardingSyncTaskKind,
        userId: String,
        payloadJSON: String,
        createdAt: Date = Date(),
        attempts: Int = 0,
        lastError: String? = nil,
        nextAttemptAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.userId = userId
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastError = lastError
        self.nextAttemptAt = nextAttemptAt
    }
}

@Observable
@MainActor
final class OnboardingSyncQueue {
    static let shared = OnboardingSyncQueue()

    private(set) var pending: [OnboardingSyncTask] = []
    private(set) var isFlushing: Bool = false

    private let fileName = "onboarding_sync_queue.v1.json"
    private let maxAttempts = 12
    private var flushTask: Task<Void, Never>?

    var hasPending: Bool { !pending.isEmpty }

    private init() {
        load()
        NotificationCenter.default.addObserver(
            forName: .networkReachabilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let online = (note.userInfo?["online"] as? Bool) ?? false
            if online {
                Task { @MainActor in self?.scheduleFlush(delay: .milliseconds(200)) }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .authUserChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleFlush(delay: .milliseconds(400)) }
        }
        // Replay anything that was pending from a prior launch.
        scheduleFlush(delay: .seconds(2))
    }

    // MARK: - Enqueue

    func enqueue(kind: OnboardingSyncTaskKind, userId: String, payload: Encodable) {
        let json = encode(payload) ?? "{}"
        let task = OnboardingSyncTask(kind: kind, userId: userId, payloadJSON: json)
        pending.append(task)
        save()
        scheduleFlush()
    }

    func ack(taskId: UUID) {
        pending.removeAll { $0.id == taskId }
        save()
    }

    // MARK: - Flush

    func flushNow() async {
        await performFlush()
    }

    private func scheduleFlush(delay: Duration = .milliseconds(300)) {
        flushTask?.cancel()
        flushTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }
            await performFlush()
        }
    }

    private func performFlush() async {
        guard !isFlushing else { return }
        guard !pending.isEmpty else { return }
        guard NetworkMonitor.shared.isOnline else { return }
        guard AuthService.shared.authState == .signedIn else { return }
        guard let currentUserId = try? AuthService.shared.currentUserId() else { return }

        isFlushing = true
        defer { isFlushing = false }

        let now = Date()
        for idx in pending.indices {
            if Task.isCancelled { break }
            guard pending[idx].nextAttemptAt <= now else { continue }
            // Only flush rows belonging to the currently signed-in user.
            // Tasks from a different user stay queued (e.g. signed out before
            // flush completed) — they'll fire when that account signs back in.
            guard pending[idx].userId == currentUserId else { continue }

            do {
                try await execute(pending[idx])
                pending[idx].attempts = -1 // mark for removal
            } catch {
                pending[idx].attempts += 1
                pending[idx].lastError = error.localizedDescription
                if pending[idx].attempts >= maxAttempts {
                    print("[OnboardingSyncQueue] giving up on \(pending[idx].kind): \(error)")
                    pending[idx].attempts = -1
                } else {
                    let backoff = min(pow(2.0, Double(pending[idx].attempts)), 300)
                    let jitter = Double.random(in: 0...(backoff * 0.25))
                    pending[idx].nextAttemptAt = Date().addingTimeInterval(backoff + jitter)
                }
            }
        }
        pending.removeAll { $0.attempts == -1 }
        save()
        scheduleNextWakeIfNeeded()
    }

    private func scheduleNextWakeIfNeeded() {
        guard let next = pending.map({ $0.nextAttemptAt }).min() else { return }
        let delay = max(0.5, next.timeIntervalSinceNow)
        flushTask?.cancel()
        flushTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            await performFlush()
        }
    }

    private func execute(_ task: OnboardingSyncTask) async throws {
        let supabase = SupabaseService.shared.client
        switch task.kind {
        case .persona:
            let p = try decode(OnboardingPayloads.Persona.self, from: task.payloadJSON)
            try await supabase.from("profiles")
                .update(["persona_track": p.personaTrack])
                .eq("id", value: task.userId)
                .execute()
        case .aboutYou:
            let p = try decode(OnboardingPayloads.AboutYou.self, from: task.payloadJSON)
            try await supabase.from("profiles").update(p).eq("id", value: task.userId).execute()
        case .pregnancy:
            let p = try decode(OnboardingPayloads.Pregnancy.self, from: task.payloadJSON)
            try await supabase.from("profiles").update(p).eq("id", value: task.userId).execute()
        case .goals:
            let p = try decode(OnboardingPayloads.Goals.self, from: task.payloadJSON)
            try await supabase.from("profiles").update(p).eq("id", value: task.userId).execute()
        case .protocolChapter:
            let p = try decode(OnboardingPayloads.ProtocolChapter.self, from: task.payloadJSON)
            try await supabase.from("profiles").update(p).eq("id", value: task.userId).execute()
        case .disclaimerAck:
            let p = try decode(DisclaimerAcknowledgement.self, from: task.payloadJSON)
            try await supabase.from("disclaimer_acknowledgements").insert(p).execute()
        case .socialIdentity:
            let p = try decode(OnboardingPayloads.SocialIdentity.self, from: task.payloadJSON)
            try await supabase.from("profiles").update(p).eq("id", value: task.userId).execute()
        }
    }

    // MARK: - Persistence

    private var fileURL: URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let bundle = dir.appendingPathComponent("FrisFit", isDirectory: true)
        if !FileManager.default.fileExists(atPath: bundle.path) {
            try? FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        }
        return bundle.appendingPathComponent(fileName)
    }

    private func save() {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(pending) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([OnboardingSyncTask].self, from: data) {
            pending = decoded
        }
    }

    private func encode<T: Encodable>(_ payload: T) -> String? {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "OnboardingSyncQueue", code: -1)
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(type, from: data)
    }
}

/// Codable payload shapes mirrored from the Supabase columns. These have to
/// match `OnboardingManager.persist*` row shapes exactly so a queued retry
/// hits the same columns the original write would have.
nonisolated enum OnboardingPayloads {
    struct Persona: Codable, Sendable {
        let personaTrack: String
    }

    struct AboutYou: Codable, Sendable {
        let display_name: String?
        let date_of_birth: String?
        let biological_sex: String?
        let height_cm: Double?
        let weight_kg: Double?
        let body_fat_percent: Double?
        let activity_level: String?
    }

    struct Pregnancy: Codable, Sendable {
        let is_pregnant_or_nursing: Bool
    }

    struct Goals: Codable, Sendable {
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

    struct ProtocolChapter: Codable, Sendable {
        let preferred_injection_sites: [String]?
        let reminder_style: String
        let morning_brief_time: String
        let dose_reminder_time: String
    }

    struct SocialIdentity: Codable, Sendable {
        let username: String?
        let avatar_url: String?
        let avatar_color: String?
    }
}
