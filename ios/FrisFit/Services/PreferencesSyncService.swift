import Foundation
import Supabase

/// Tracked preference keys + their value type. Keys listed here are
/// automatically mirrored from UserDefaults to Supabase so that settings
/// survive app reinstalls and follow the user across devices.
nonisolated enum PrefKey: String, CaseIterable, Sendable {
    case healthKitEnabled = "healthkit_enabled"
    case appearanceMode = "appearance_mode"
    case weightUnitPref = "weightUnitPref"
    case waterUnit = "com.frisfit.waterUnit"
    case waterGoalMl = "com.frisfit.waterGoalMl"
    case stepGoal = "step_goal"
    case programStartDayOffset = "programStartDayOffset"
    case cachedWeightLbs = "cachedWeightLbs"
    case lastLoggedSport = "logActivity.lastSport"
    case aiMemoryEnabled = "ai_memory_enabled"
    case adaptiveMacrosEnabled = "adaptive_macros_enabled"
    case medicalDisclaimerAccepted = "medicalDisclaimerAccepted"

    enum ValueType: Sendable {
        case bool, int, double, string
    }

    var type: ValueType {
        switch self {
        case .healthKitEnabled, .aiMemoryEnabled, .adaptiveMacrosEnabled, .medicalDisclaimerAccepted:
            return .bool
        case .appearanceMode, .waterGoalMl, .stepGoal, .programStartDayOffset:
            return .int
        case .cachedWeightLbs:
            return .double
        case .weightUnitPref, .waterUnit, .lastLoggedSport:
            return .string
        }
    }
}

nonisolated enum PrefValue: Codable, Sendable, Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported pref value")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }
}

nonisolated struct UserPreferencesRow: Codable, Sendable {
    let user_id: String
    let data: [String: PrefValue]
    let updated_at: String?
}

/// Extension on Notification.Name so other services can observe when
/// preferences are applied from the cloud on launch.
extension Notification.Name {
    static let preferencesDidHydrate = Notification.Name("preferencesDidHydrate")
}

@Observable
@MainActor
final class PreferencesSyncService {
    static let shared = PreferencesSyncService()

    private(set) var hasHydrated: Bool = false
    private var pushTask: Task<Void, Never>?
    private var lastPushedSnapshot: [String: PrefValue] = [:]
    private var isApplyingRemote: Bool = false
    private var authWatchTask: Task<Void, Never>?

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    /// Call once at app startup. Begins watching auth state — every time the
    /// user becomes signed-in, pulls remote preferences and applies them.
    func start() {
        authWatchTask?.cancel()
        authWatchTask = Task { [weak self] in
            for await (event, session) in SupabaseService.shared.client.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed:
                    if session != nil { await self.hydrateFromRemote() }
                case .signedOut:
                    await MainActor.run {
                        self.hasHydrated = false
                        self.lastPushedSnapshot = [:]
                    }
                default:
                    break
                }
            }
        }
    }

    @objc private func userDefaultsChanged() {
        guard hasHydrated, !isApplyingRemote else { return }
        schedulePush()
    }

    private func schedulePush() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            await self?.pushNow()
        }
    }

    private func pushNow() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        let snapshot = currentSnapshot()
        guard snapshot != lastPushedSnapshot else { return }
        let row = UserPreferencesRow(
            user_id: userId,
            data: snapshot,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        do {
            try await supabase
                .from("user_preferences")
                .upsert(row, onConflict: "user_id")
                .execute()
            lastPushedSnapshot = snapshot
        } catch {
            print("[PreferencesSync] push failed: \(error.localizedDescription)")
        }
    }

    func hydrateFromRemote() async {
        guard let userId = try? AuthService.shared.currentUserId() else { return }
        do {
            let rows: [UserPreferencesRow] = try await supabase
                .from("user_preferences")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            if let row = rows.first, !row.data.isEmpty {
                await MainActor.run {
                    self.isApplyingRemote = true
                    for (key, value) in row.data {
                        guard let prefKey = PrefKey(rawValue: key) else { continue }
                        self.applyValue(value, for: prefKey)
                    }
                    self.isApplyingRemote = false
                    self.lastPushedSnapshot = row.data
                    self.hasHydrated = true
                    NotificationCenter.default.post(name: .preferencesDidHydrate, object: nil)
                }
                print("[PreferencesSync] hydrated \(row.data.count) keys from remote")
                await reSyncObservers()
            } else {
                await MainActor.run {
                    self.hasHydrated = true
                    NotificationCenter.default.post(name: .preferencesDidHydrate, object: nil)
                }
                await pushNow()
                print("[PreferencesSync] no remote prefs yet — pushed local as initial")
            }
        } catch {
            print("[PreferencesSync] hydrate failed: \(error.localizedDescription)")
            await MainActor.run {
                self.hasHydrated = true
            }
        }
    }

    /// After remote values are written to UserDefaults, certain observable
    /// singletons cache their values and need to be notified to reload.
    private func reSyncObservers() async {
        await MainActor.run {
            let savedAppearance = UserDefaults.standard.integer(forKey: PrefKey.appearanceMode.rawValue)
            if let mode = AppearanceMode(rawValue: savedAppearance) {
                AppearanceManager.shared.mode = mode
            }
            WaterViewModel.shared.reloadPreferencesFromDefaults()
            HealthKitService.shared.reloadEnabledFlagFromDefaults()
        }
    }

    private func applyValue(_ value: PrefValue, for key: PrefKey) {
        let defaults = UserDefaults.standard
        // The HealthKit toggle is per-user locally (so two accounts on the
        // same device don't share a toggle). Route writes through the
        // user-scoped store. The Supabase row keeps the unscoped column name.
        if key == .healthKitEnabled, case .bool(let b) = value {
            LocalStateResetCoordinator.setHealthKitEnabled(
                b,
                forUserId: LocalStateResetCoordinator.currentUserId()
            )
            return
        }
        switch (key.type, value) {
        case (.bool, .bool(let b)):
            defaults.set(b, forKey: key.rawValue)
        case (.int, .int(let i)):
            defaults.set(i, forKey: key.rawValue)
        case (.int, .double(let d)):
            defaults.set(Int(d), forKey: key.rawValue)
        case (.double, .double(let d)):
            defaults.set(d, forKey: key.rawValue)
        case (.double, .int(let i)):
            defaults.set(Double(i), forKey: key.rawValue)
        case (.string, .string(let s)):
            defaults.set(s, forKey: key.rawValue)
        default:
            break
        }
    }

    private func currentSnapshot() -> [String: PrefValue] {
        let defaults = UserDefaults.standard
        let uid = LocalStateResetCoordinator.currentUserId()
        var out: [String: PrefValue] = [:]
        for key in PrefKey.allCases {
            // HealthKit toggle is stored under a per-user key locally; mirror
            // it to the shared column name so cross-device hydrate still works.
            if key == .healthKitEnabled {
                let scopedKey = LocalStateResetCoordinator.healthKitEnabledKey(for: uid)
                if defaults.object(forKey: scopedKey) != nil {
                    out[key.rawValue] = .bool(defaults.bool(forKey: scopedKey))
                }
                continue
            }
            guard defaults.object(forKey: key.rawValue) != nil else { continue }
            switch key.type {
            case .bool:
                out[key.rawValue] = .bool(defaults.bool(forKey: key.rawValue))
            case .int:
                out[key.rawValue] = .int(defaults.integer(forKey: key.rawValue))
            case .double:
                out[key.rawValue] = .double(defaults.double(forKey: key.rawValue))
            case .string:
                if let s = defaults.string(forKey: key.rawValue) {
                    out[key.rawValue] = .string(s)
                }
            }
        }
        return out
    }
}
