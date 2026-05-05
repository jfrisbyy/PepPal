import Foundation
import Supabase

nonisolated struct SupabaseBodyProgressPhoto: Codable, Sendable {
    let id: String?
    let user_id: String?
    let captured_at: String
    let label: String?
    let photo_url: String?
    let storage_path: String?
    let orientation: String?
    let weight_lbs: Double?
    let note: String?
    let created_at: String?
}

nonisolated struct SupabaseBodyProgressPhotoInsert: Codable, Sendable {
    let user_id: String
    let captured_at: String
    let label: String?
    let photo_url: String?
    let storage_path: String?
    let orientation: String?
    let weight_lbs: Double?
    let note: String?
}

final class BodyProgressPhotoService {
    static let shared = BodyProgressPhotoService()
    private init() {}

    private let bucket = "body-progress-photos"
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parse(_ s: String?) -> Date {
        guard let s else { return Date() }
        return iso.date(from: s) ?? isoBasic.date(from: s) ?? Date()
    }

    private func userId() async -> String? {
        guard let session = try? await supabase.auth.session else { return nil }
        return session.user.id.uuidString.lowercased()
    }

    func fetchAll() async -> [ProgressPhoto] {
        guard let uid = await userId() else { return [] }
        do {
            let rows: [SupabaseBodyProgressPhoto] = try await supabase
                .from("body_progress_photos")
                .select()
                .eq("user_id", value: uid)
                .order("captured_at", ascending: false)
                .execute()
                .value
            return rows.map { row in
                ProgressPhoto(
                    date: parse(row.captured_at),
                    label: row.label ?? "",
                    photoUrl: row.photo_url,
                    category: row.orientation,
                    orientation: row.orientation,
                    supabaseId: row.id
                )
            }
        } catch {
            print("[BodyProgressPhotoService] fetch error: \(error)")
            return []
        }
    }

    func uploadPhoto(_ data: Data) async throws -> (publicUrl: String, storagePath: String) {
        guard let uid = await userId() else {
            throw NSError(domain: "BodyProgressPhotoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let fileName = "\(uid)/photo_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpg"
        try await supabase.storage
            .from(bucket)
            .upload(
                fileName,
                data: data,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
            )
        let url = try supabase.storage.from(bucket).getPublicURL(path: fileName)
        return (url.absoluteString, fileName)
    }

    @discardableResult
    func insert(date: Date, label: String, photoUrl: String?, storagePath: String?, orientation: String?, weightLbs: Double? = nil, note: String? = nil) async -> ProgressPhoto? {
        guard let uid = await userId() else { return nil }
        let payload = SupabaseBodyProgressPhotoInsert(
            user_id: uid,
            captured_at: iso.string(from: date),
            label: label.isEmpty ? nil : label,
            photo_url: photoUrl,
            storage_path: storagePath,
            orientation: orientation,
            weight_lbs: weightLbs,
            note: note
        )
        do {
            let row: SupabaseBodyProgressPhoto = try await supabase
                .from("body_progress_photos")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            return ProgressPhoto(
                date: parse(row.captured_at),
                label: row.label ?? "",
                photoUrl: row.photo_url,
                category: row.orientation,
                orientation: row.orientation,
                supabaseId: row.id
            )
        } catch {
            print("[BodyProgressPhotoService] insert error: \(error)")
            return nil
        }
    }

    func delete(id: String, storagePath: String?) async {
        do {
            try await supabase.from("body_progress_photos").delete().eq("id", value: id).execute()
            if let path = storagePath {
                _ = try? await supabase.storage.from(bucket).remove(paths: [path])
            }
        } catch {
            print("[BodyProgressPhotoService] delete error: \(error)")
        }
    }
}
