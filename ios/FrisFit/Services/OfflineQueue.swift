import Foundation
import Supabase

nonisolated enum QueuedOp: String, Codable, Sendable {
    case insert
    case upsert
    case delete
}

nonisolated enum OutboxStatus: String, Codable, Sendable {
    case pending
    case failed
}

nonisolated struct QueuedWrite: Codable, Sendable, Identifiable {
    let id: UUID
    let op: QueuedOp
    let table: String
    let kind: String
    let payload: [String: JSONPrimitive]
    let filterColumn: String?
    let filterValue: String?
    let onConflict: String?
    let clientMutationId: String
    let createdAt: Date
    var attempts: Int
    var lastError: String?
    var nextAttemptAt: Date
    var status: OutboxStatus

    init(
        id: UUID = UUID(),
        op: QueuedOp,
        table: String,
        kind: String,
        payload: [String: JSONPrimitive] = [:],
        filterColumn: String? = nil,
        filterValue: String? = nil,
        onConflict: String? = nil,
        clientMutationId: String = UUID().uuidString,
        createdAt: Date = Date(),
        attempts: Int = 0,
        lastError: String? = nil,
        nextAttemptAt: Date = Date(),
        status: OutboxStatus = .pending
    ) {
        self.id = id
        self.op = op
        self.table = table
        self.kind = kind
        self.payload = payload
        self.filterColumn = filterColumn
        self.filterValue = filterValue
        self.onConflict = onConflict
        self.clientMutationId = clientMutationId
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastError = lastError
        self.nextAttemptAt = nextAttemptAt
        self.status = status
    }

    var label: String {
        if !kind.isEmpty { return kind }
        switch op {
        case .insert, .upsert: return "Save to \(table)"
        case .delete: return "Delete from \(table)"
        }
    }
}

nonisolated enum JSONPrimitive: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }

    static func from(_ any: Any?) -> JSONPrimitive {
        guard let any = any else { return .null }
        if let v = any as? Bool { return .bool(v) }
        if let v = any as? Int { return .int(v) }
        if let v = any as? Double { return .double(v) }
        if let v = any as? String { return .string(v) }
        return .null
    }
}

@Observable
@MainActor
final class OfflineQueue {
    static let shared = OfflineQueue()

    private(set) var pending: [QueuedWrite] = []
    private(set) var isFlushing: Bool = false
    private(set) var lastError: String?

    private let fileName = "outbox.v2.json"
    private let maxAttempts = 8
    private var flushTask: Task<Void, Never>?

    var pendingCount: Int { pending.filter { $0.status == .pending }.count }
    var failedCount: Int { pending.filter { $0.status == .failed }.count }
    var hasFailures: Bool { failedCount > 0 }

    private init() {
        load()
    }

    // MARK: - Enqueue

    func enqueueInsert(
        table: String,
        payload: [String: JSONPrimitive],
        kind: String? = nil,
        clientMutationId: String = UUID().uuidString
    ) {
        var p = payload
        if p["client_mutation_id"] == nil {
            p["client_mutation_id"] = .string(clientMutationId)
        }
        let item = QueuedWrite(
            op: .insert,
            table: table,
            kind: kind ?? "Save to \(table)",
            payload: p,
            clientMutationId: clientMutationId
        )
        append(item)
    }

    func enqueueUpsert(
        table: String,
        payload: [String: JSONPrimitive],
        onConflict: String,
        kind: String? = nil,
        clientMutationId: String = UUID().uuidString
    ) {
        var p = payload
        if p["client_mutation_id"] == nil {
            p["client_mutation_id"] = .string(clientMutationId)
        }
        let item = QueuedWrite(
            op: .upsert,
            table: table,
            kind: kind ?? "Save to \(table)",
            payload: p,
            onConflict: onConflict,
            clientMutationId: clientMutationId
        )
        append(item)
    }

    func enqueueDelete(table: String, column: String, value: String, kind: String? = nil) {
        let item = QueuedWrite(
            op: .delete,
            table: table,
            kind: kind ?? "Delete from \(table)",
            filterColumn: column,
            filterValue: value
        )
        append(item)
    }

    private func append(_ item: QueuedWrite) {
        pending.append(item)
        save()
        notifyChanged()
        scheduleFlush()
    }

    // MARK: - Public actions

    func flush() {
        scheduleFlush(delay: .milliseconds(100))
    }

    func retry(itemId: UUID) {
        guard let idx = pending.firstIndex(where: { $0.id == itemId }) else { return }
        pending[idx].status = .pending
        pending[idx].attempts = 0
        pending[idx].nextAttemptAt = Date()
        pending[idx].lastError = nil
        save()
        notifyChanged()
        scheduleFlush()
    }

    func retryAllFailed() {
        for idx in pending.indices where pending[idx].status == .failed {
            pending[idx].status = .pending
            pending[idx].attempts = 0
            pending[idx].nextAttemptAt = Date()
            pending[idx].lastError = nil
        }
        save()
        notifyChanged()
        scheduleFlush()
    }

    func discard(itemId: UUID) {
        pending.removeAll { $0.id == itemId }
        save()
        notifyChanged()
    }

    func discardAllFailed() {
        pending.removeAll { $0.status == .failed }
        save()
        notifyChanged()
    }

    /// Returns true if there's a pending/failed write matching the predicate. Used by per-row indicators.
    func hasPending(table: String, matching: (QueuedWrite) -> Bool) -> Bool {
        pending.contains { $0.table == table && matching($0) }
    }

    // MARK: - Flush loop

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
        guard NetworkMonitor.shared.isOnline else { return }
        guard AuthService.shared.authState == .signedIn else { return }

        let now = Date()
        guard pending.contains(where: { $0.status == .pending && $0.nextAttemptAt <= now }) else {
            scheduleNextWakeIfNeeded()
            return
        }

        isFlushing = true
        defer { isFlushing = false }

        let supabase = SupabaseService.shared.client

        for idx in pending.indices {
            if Task.isCancelled { break }
            guard pending[idx].status == .pending else { continue }
            guard pending[idx].nextAttemptAt <= Date() else { continue }

            do {
                try await executeItem(pending[idx], supabase: supabase)
                pending[idx].status = .pending
                pending[idx].lastError = nil
                // Mark for removal
                pending[idx].attempts = -1
            } catch {
                pending[idx].attempts += 1
                pending[idx].lastError = error.localizedDescription
                lastError = error.localizedDescription

                if pending[idx].attempts >= maxAttempts {
                    pending[idx].status = .failed
                    DebugBanner.shared.log(
                        .error,
                        "Sync failed: \(pending[idx].label)",
                        error.localizedDescription
                    )
                } else {
                    let backoff = exponentialBackoff(attempts: pending[idx].attempts)
                    pending[idx].nextAttemptAt = Date().addingTimeInterval(backoff)
                }
            }
        }

        pending.removeAll { $0.attempts == -1 }
        save()
        notifyChanged()

        scheduleNextWakeIfNeeded()
    }

    private func scheduleNextWakeIfNeeded() {
        let upcoming = pending
            .filter { $0.status == .pending }
            .map { $0.nextAttemptAt }
            .min()
        guard let next = upcoming else { return }
        let delay = max(0.5, next.timeIntervalSinceNow)
        flushTask?.cancel()
        flushTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            await performFlush()
        }
    }

    private func exponentialBackoff(attempts: Int) -> TimeInterval {
        let base = min(pow(2.0, Double(attempts)), 300)
        let jitter = Double.random(in: 0...(base * 0.25))
        return base + jitter
    }

    private func executeItem(_ item: QueuedWrite, supabase: SupabaseClient) async throws {
        switch item.op {
        case .delete:
            guard let col = item.filterColumn, let val = item.filterValue else { return }
            try await supabase.from(item.table).delete().eq(col, value: val).execute()
        case .insert:
            try await supabase.from(item.table).insert(item.payload).execute()
        case .upsert:
            let conflict = item.onConflict ?? "client_mutation_id"
            try await supabase
                .from(item.table)
                .upsert(item.payload, onConflict: conflict, ignoreDuplicates: false)
                .execute()
        }
    }

    // MARK: - Persistence (disk-backed)

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
        guard let url = fileURL, let data = try? Data(contentsOf: url) else {
            migrateFromUserDefaults()
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([QueuedWrite].self, from: data) {
            pending = decoded
        }
    }

    private func migrateFromUserDefaults() {
        let legacyKey = "com.frisfit.offlineQueue.v1"
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([QueuedWrite].self, from: data) {
            pending = decoded
            save()
        }
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .offlineQueueChanged, object: nil)
    }
}
