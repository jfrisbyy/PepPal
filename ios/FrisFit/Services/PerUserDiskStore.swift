import Foundation

/// Disk-backed per-user JSON store that lives under
/// `Application Support/PerUserStore/<userId>/<file>.json`.
///
/// We use Application Support (not Documents) so the OS doesn't surface these
/// files in iCloud / Files.app, and so they're excluded from user-visible
/// backups by default. Each user gets their own folder so account switches /
/// sign-outs can purge a single subtree atomically.
///
/// This replaces large blob writes that used to hit `UserDefaults`. Anything
/// over a few KB (HealthKit series, journey-event cache, story narrations,
/// food favorites) belongs here, both for memory pressure (UserDefaults loads
/// the entire plist) and because those values are user-scoped data, not
/// global preferences.
nonisolated enum PerUserDiskStore {

    // MARK: - Folders

    private static let rootFolderName = "PerUserStore"

    private static func appSupportRoot() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent(rootFolderName, isDirectory: true)
        if !fm.fileExists(atPath: root.path) {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            // Exclude the cache root from iCloud backups — these are derived
            // caches that can be rebuilt from Supabase on demand.
            var u = root
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? u.setResourceValues(values)
        }
        return root
    }

    private static func folder(for userId: String) throws -> URL {
        let safe = userId.isEmpty ? "__anon__" : userId
        let url = try appSupportRoot().appendingPathComponent(safe, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static func file(for userId: String, name: String) throws -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "_")
        return try folder(for: userId).appendingPathComponent("\(safe).json")
    }

    // MARK: - Read / Write

    /// Load a Decodable from disk. Returns nil for any error (missing file,
    /// corrupt data, schema drift). Callers treat this as a best-effort cache.
    static func load<T: Decodable>(_ type: T.Type, userId: String, name: String) -> T? {
        guard !userId.isEmpty else { return nil }
        do {
            let url = try file(for: userId, name: name)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    /// Atomically write a Codable to disk. Errors are swallowed — write
    /// failures must never crash the UI.
    static func save<T: Encodable>(_ value: T, userId: String, name: String) {
        guard !userId.isEmpty else { return }
        do {
            let url = try file(for: userId, name: name)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // Intentionally swallowed: the cache is rebuildable from Supabase.
        }
    }

    /// Remove a single file for a user. Safe to call when the file is missing.
    static func remove(userId: String, name: String) {
        guard !userId.isEmpty else { return }
        if let url = try? file(for: userId, name: name) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Purge

    /// Wipe the entire folder for a single user (sign-out / account switch).
    static func purge(userId: String) {
        guard !userId.isEmpty else { return }
        if let url = try? folder(for: userId) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Wipe every per-user folder on disk (defense-in-depth on full reset).
    static func purgeAll() {
        guard let root = try? appSupportRoot() else { return }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for url in contents {
            try? fm.removeItem(at: url)
        }
    }
}
