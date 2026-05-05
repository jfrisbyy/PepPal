import Foundation
import Supabase

nonisolated struct SupabaseBloodworkEntry: Codable, Sendable {
    let id: String?
    let user_id: String
    let entry_date: String
    let photo_url: String?
    let notes: String?
    let created_at: String?
}

nonisolated struct SupabaseBiomarkerResult: Codable, Sendable {
    let id: String?
    let entry_id: String
    let biomarker: String
    let value: Double
    let created_at: String?
}

nonisolated struct CreateBloodworkEntryPayload: Codable, Sendable {
    let user_id: String
    let entry_date: String
    let photo_url: String?
    let notes: String?
}

nonisolated struct CreateBiomarkerResultPayload: Codable, Sendable {
    let entry_id: String
    let biomarker: String
    let value: Double
}

final class BloodworkService {
    static let shared = BloodworkService()

    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func fetchEntries(userId: String) async throws -> [SupabaseBloodworkEntry] {
        let response: [SupabaseBloodworkEntry] = try await supabase
            .from("bloodwork_entries")
            .select()
            .eq("user_id", value: userId)
            .order("entry_date", ascending: false)
            .execute()
            .value
        return response
    }

    func fetchBiomarkerResults(entryId: String) async throws -> [SupabaseBiomarkerResult] {
        let response: [SupabaseBiomarkerResult] = try await supabase
            .from("biomarker_results")
            .select()
            .eq("entry_id", value: entryId)
            .execute()
            .value
        return response
    }

    func createEntry(userId: String, date: Date, notes: String?, photoUrl: String?) async throws -> SupabaseBloodworkEntry {
        let payload = CreateBloodworkEntryPayload(
            user_id: userId,
            entry_date: dateOnly.string(from: date),
            photo_url: photoUrl,
            notes: notes
        )
        let created: SupabaseBloodworkEntry = try await supabase
            .from("bloodwork_entries")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let entryDate = date
        let entryNotes = notes
        let entryPhotoString = photoUrl
        await MainActor.run {
            var attachments: [URL] = []
            if let p = entryPhotoString, let u = URL(string: p) { attachments.append(u) }
            let event = JourneyEvent(
                userId: UUID(uuidString: userId) ?? UUID(),
                lane: .bloodwork,
                timestamp: entryDate,
                title: "Bloodwork draw",
                description: entryNotes,
                sourceType: .bloodwork,
                attachments: attachments
            )
            Task { await JourneyEventService.shared.add(event) }
        }
        return created
    }

    func addBiomarkerResult(entryId: String, biomarker: String, value: Double) async throws -> SupabaseBiomarkerResult {
        let payload = CreateBiomarkerResultPayload(
            entry_id: entryId,
            biomarker: biomarker,
            value: value
        )
        let created: SupabaseBiomarkerResult = try await supabase
            .from("biomarker_results")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return created
    }

    func addBiomarkerResults(entryId: String, results: [BiomarkerResult]) async throws {
        for result in results {
            _ = try await addBiomarkerResult(entryId: entryId, biomarker: result.biomarker.rawValue, value: result.value)
        }
    }

    func deleteEntry(entryId: String) async throws {
        try await supabase
            .from("biomarker_results")
            .delete()
            .eq("entry_id", value: entryId)
            .execute()

        try await supabase
            .from("bloodwork_entries")
            .delete()
            .eq("id", value: entryId)
            .execute()
    }

    func uploadPhoto(userId: String, imageData: Data) async throws -> String {
        let fileName = "\(userId)/bloodwork_\(Int(Date().timeIntervalSince1970)).jpg"
        try await supabase.storage
            .from("bloodwork-photos")
            .upload(fileName, data: imageData, options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: false
            ))

        let publicURL = try supabase.storage
            .from("bloodwork-photos")
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    func toBloodworkEntry(_ entry: SupabaseBloodworkEntry, results: [SupabaseBiomarkerResult]) -> BloodworkEntry {
        let bioResults = results.compactMap { r -> BiomarkerResult? in
            guard let biomarker = Biomarker(rawValue: r.biomarker) else { return nil }
            return BiomarkerResult(biomarker: biomarker, value: r.value)
        }
        let date: Date
        if let d = dateOnly.date(from: entry.entry_date) {
            date = d
        } else {
            date = iso8601.date(from: entry.entry_date) ?? Date()
        }
        return BloodworkEntry(date: date, results: bioResults, notes: entry.notes ?? "")
    }
}
