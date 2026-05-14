import Foundation
import Supabase

// MARK: - Row shapes

nonisolated struct AIDailyBriefingRow: Codable, Sendable {
    let user_id: String
    let day: String
    let plan_response: AnyCodableJSON
    let data_hash: String?
    let trigger: String
    let window_key: String?
    let is_final: Bool
    let generated_at: String
}

nonisolated struct AIDailyBriefingFetchRow: Codable, Sendable {
    let day: String
    let plan_response: AnyCodableJSON
    let data_hash: String?
    let trigger: String
    let window_key: String?
    let is_final: Bool
    let generated_at: String
}

nonisolated struct AIInvestigationRow: Codable, Sendable {
    let user_id: String
    let payload: AnyCodableJSON
    let data_hash: String?
    let trigger: String
    let generated_at: String
}

nonisolated struct AIInvestigationFetchRow: Codable, Sendable {
    let payload: AnyCodableJSON
    let data_hash: String?
    let trigger: String
    let generated_at: String
}

nonisolated struct AIWeeklySummaryRow: Codable, Sendable {
    let user_id: String
    let week_start: String
    let summary: AnyCodableJSON
    let data_hash: String?
    let is_final: Bool
    let generated_at: String
}

nonisolated struct SummaryOnlyRow: Codable, Sendable {
    let summary: AnyCodableJSON
}

nonisolated struct AIMonthlySummaryRow: Codable, Sendable {
    let user_id: String
    let month_start: String
    let summary: AnyCodableJSON
    let data_hash: String?
    let is_final: Bool
    let generated_at: String
}

/// Wraps an arbitrary JSON-serializable value so it can roundtrip through
/// PostgrestClient as a `jsonb` column.
nonisolated struct AnyCodableJSON: Codable, Sendable {
    let raw: Data

    init<T: Encodable>(_ value: T) throws {
        self.raw = try JSONEncoder().encode(value)
    }

    init(rawData: Data) {
        self.raw = rawData
    }

    func decoded<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: raw)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let obj = try? JSONSerialization.jsonObject(with: raw) {
            // Re-encode through JSONSerialization-aware encoder via Foundation bridging.
            let data = try JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed])
            // Round-trip through Decodable/Encodable using AnyCodable-like approach
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            try c.encode(value)
        } else {
            try c.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let value = try c.decode(JSONValue.self)
        let data = try JSONEncoder().encode(value)
        self.raw = data
    }
}

/// Minimal JSON value enum so we can round-trip arbitrary jsonb payloads.
nonisolated indirect enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

// MARK: - Service

/// Persists AI-generated briefings, insights, and weekly/monthly summaries
/// to Supabase so the app can serve the latest version instantly without
/// re-running expensive Sonnet calls on every open.
@MainActor
@Observable
final class BriefingCloudService {
    static let shared = BriefingCloudService()

    var lastError: String? = nil

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    // MARK: - Daily briefings

    /// Upsert today's (or any given date's) briefing. Marks `is_final` true
    /// when persisting a briefing for a day that has already ended.
    func saveBriefing(
        date: Date,
        plan: TodaysPlanResponse,
        dataHash: String?,
        trigger: String,
        windowKey: String?
    ) async {
        // Demo mode briefs are scratch — never persist them to the real
        // user's row or they will leak across personas / sessions.
        if DemoModeProbe.isActive { return }
        guard let userId = await currentUserId() else { return }
        do {
            let payload = try AnyCodableJSON(plan)
            let row = AIDailyBriefingRow(
                user_id: userId,
                day: isoDay(date),
                plan_response: payload,
                data_hash: dataHash,
                trigger: trigger,
                window_key: windowKey,
                is_final: !Calendar.current.isDateInToday(date),
                generated_at: isoTimestamp(Date())
            )
            try await supabase
                .from("ai_daily_briefings")
                .upsert(row, onConflict: "user_id,day")
                .execute()
        } catch {
            lastError = error.localizedDescription
            print("[BriefingCloud] saveBriefing error: \(error)")
        }
    }

    /// Fetch a saved briefing for the given date (e.g. when the user picks a
    /// past day in the calendar). Returns nil if nothing was generated that day.
    func fetchBriefing(for date: Date) async -> TodaysPlanResponse? {
        if DemoModeProbe.isActive { return nil }
        guard let userId = await currentUserId() else { return nil }
        do {
            let rows: [AIDailyBriefingFetchRow] = try await supabase
                .from("ai_daily_briefings")
                .select("day,plan_response,data_hash,trigger,window_key,is_final,generated_at")
                .eq("user_id", value: userId)
                .eq("day", value: isoDay(date))
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return try? row.plan_response.decoded(TodaysPlanResponse.self)
        } catch {
            print("[BriefingCloud] fetchBriefing error: \(error)")
            return nil
        }
    }

    /// Hydrate the most recent saved briefing on cold start.
    func fetchLatestBriefing() async -> (plan: TodaysPlanResponse, day: Date, hash: String?)? {
        // Don't bleed the real account's cloud brief onto a demo persona's
        // home screen on cold start.
        if DemoModeProbe.isActive { return nil }
        guard let userId = await currentUserId() else { return nil }
        do {
            let rows: [AIDailyBriefingFetchRow] = try await supabase
                .from("ai_daily_briefings")
                .select("day,plan_response,data_hash,trigger,window_key,is_final,generated_at")
                .eq("user_id", value: userId)
                .order("day", ascending: false)
                .limit(1)
                .execute()
                .value
            guard
                let row = rows.first,
                let plan = try? row.plan_response.decoded(TodaysPlanResponse.self),
                let day = parseIsoDay(row.day)
            else { return nil }
            return (plan, day, row.data_hash)
        } catch {
            return nil
        }
    }

    /// Marks yesterday's briefing as the locked "final" version for history.
    /// Safe to call on every cold start; no-op if already final.
    func lockYesterdayIfNeeded() async {
        if DemoModeProbe.isActive { return }
        guard let userId = await currentUserId() else { return }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
        struct UpdateOnly: Encodable { let is_final: Bool }
        do {
            try await supabase
                .from("ai_daily_briefings")
                .update(UpdateOnly(is_final: true))
                .eq("user_id", value: userId)
                .eq("day", value: isoDay(yesterday))
                .eq("is_final", value: false)
                .execute()
        } catch {
            // ignore
        }
    }

    // MARK: - Investigations (insights)

    func saveInvestigation(_ result: AgentInvestigationResult, trigger: String) async {
        guard let userId = await currentUserId() else { return }
        do {
            let payload = try AnyCodableJSON(result)
            let row = AIInvestigationRow(
                user_id: userId,
                payload: payload,
                data_hash: result.dataHash,
                trigger: trigger,
                generated_at: isoTimestamp(result.generatedAt)
            )
            try await supabase
                .from("ai_investigations")
                .insert(row)
                .execute()
        } catch {
            print("[BriefingCloud] saveInvestigation error: \(error)")
        }
    }

    func fetchLatestInvestigation() async -> AgentInvestigationResult? {
        guard let userId = await currentUserId() else { return nil }
        do {
            let rows: [AIInvestigationFetchRow] = try await supabase
                .from("ai_investigations")
                .select("payload,data_hash,trigger,generated_at")
                .eq("user_id", value: userId)
                .order("generated_at", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return try? row.payload.decoded(AgentInvestigationResult.self)
        } catch {
            return nil
        }
    }

    // MARK: - Weekly / monthly summaries

    func saveWeeklySummary<T: Encodable>(weekStart: Date, summary: T, dataHash: String?, isFinal: Bool) async {
        guard let userId = await currentUserId() else { return }
        do {
            let payload = try AnyCodableJSON(summary)
            let row = AIWeeklySummaryRow(
                user_id: userId,
                week_start: isoDay(weekStart),
                summary: payload,
                data_hash: dataHash,
                is_final: isFinal,
                generated_at: isoTimestamp(Date())
            )
            try await supabase
                .from("ai_weekly_summaries")
                .upsert(row, onConflict: "user_id,week_start")
                .execute()
        } catch {
            print("[BriefingCloud] saveWeeklySummary error: \(error)")
        }
    }

    func fetchWeeklySummary<T: Decodable>(weekStart: Date, as type: T.Type) async -> T? {
        guard let userId = await currentUserId() else { return nil }
        do {
            let rows: [SummaryOnlyRow] = try await supabase
                .from("ai_weekly_summaries")
                .select("summary")
                .eq("user_id", value: userId)
                .eq("week_start", value: isoDay(weekStart))
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return try? row.summary.decoded(T.self)
        } catch {
            return nil
        }
    }

    func saveMonthlySummary<T: Encodable>(monthStart: Date, summary: T, dataHash: String?, isFinal: Bool) async {
        guard let userId = await currentUserId() else { return }
        do {
            let payload = try AnyCodableJSON(summary)
            let row = AIMonthlySummaryRow(
                user_id: userId,
                month_start: isoDay(monthStart),
                summary: payload,
                data_hash: dataHash,
                is_final: isFinal,
                generated_at: isoTimestamp(Date())
            )
            try await supabase
                .from("ai_monthly_summaries")
                .upsert(row, onConflict: "user_id,month_start")
                .execute()
        } catch {
            print("[BriefingCloud] saveMonthlySummary error: \(error)")
        }
    }

    func fetchMonthlySummary<T: Decodable>(monthStart: Date, as type: T.Type) async -> T? {
        guard let userId = await currentUserId() else { return nil }
        do {
            let rows: [SummaryOnlyRow] = try await supabase
                .from("ai_monthly_summaries")
                .select("summary")
                .eq("user_id", value: userId)
                .eq("month_start", value: isoDay(monthStart))
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return try? row.summary.decoded(T.self)
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func currentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }

    private func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func parseIsoDay(_ str: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }

    private func isoTimestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
