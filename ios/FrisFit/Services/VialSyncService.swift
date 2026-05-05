import Foundation
import Supabase

nonisolated struct SupabaseVial: Codable, Sendable {
    let id: String?
    let user_id: String?
    let client_id: String
    let compound_name: String
    let vial_size_mg: Double
    let diluent_ml: Double?
    let reconstituted_on: String?
    let storage: String
    let lot_number: String?
    let vial_number: String?
    let expiration_date: String?
    let typical_dose_mcg: Double
    let mcg_used: Double
    let bud_days: Int
    let label_image_filename: String?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct SupabaseVialUpsert: Codable, Sendable {
    let user_id: String
    let client_id: String
    let compound_name: String
    let vial_size_mg: Double
    let diluent_ml: Double?
    let reconstituted_on: String?
    let storage: String
    let lot_number: String?
    let vial_number: String?
    let expiration_date: String?
    let typical_dose_mcg: Double
    let mcg_used: Double
    let bud_days: Int
    let label_image_filename: String?
}

final class VialSyncService {
    static let shared = VialSyncService()
    private init() {}

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

    private func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s) ?? isoBasic.date(from: s)
    }

    private func userId() async -> String? {
        guard let session = try? await supabase.auth.session else { return nil }
        return session.user.id.uuidString.lowercased()
    }

    func fetchAll() async -> [Vial] {
        guard let uid = await userId() else { return [] }
        do {
            let rows: [SupabaseVial] = try await supabase
                .from("vials")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map { row in
                Vial(
                    id: UUID(uuidString: row.client_id) ?? UUID(),
                    compoundName: row.compound_name,
                    vialSizeMg: row.vial_size_mg,
                    diluentMl: row.diluent_ml,
                    reconstitutedOn: parse(row.reconstituted_on),
                    storage: VialStorageLocation(rawValue: row.storage) ?? .fridge,
                    lotNumber: row.lot_number ?? "",
                    vialNumber: row.vial_number ?? "",
                    expirationDate: parse(row.expiration_date),
                    typicalDoseMcg: row.typical_dose_mcg,
                    mcgUsed: row.mcg_used,
                    budDays: row.bud_days,
                    createdAt: parse(row.created_at) ?? Date(),
                    labelImageFilename: row.label_image_filename
                )
            }
        } catch {
            print("[VialSyncService] fetch error: \(error)")
            return []
        }
    }

    func upsert(_ vial: Vial) async {
        guard let uid = await userId() else { return }
        let payload = SupabaseVialUpsert(
            user_id: uid,
            client_id: vial.id.uuidString.lowercased(),
            compound_name: vial.compoundName,
            vial_size_mg: vial.vialSizeMg,
            diluent_ml: vial.diluentMl,
            reconstituted_on: vial.reconstitutedOn.map { iso.string(from: $0) },
            storage: vial.storage.rawValue,
            lot_number: vial.lotNumber.isEmpty ? nil : vial.lotNumber,
            vial_number: vial.vialNumber.isEmpty ? nil : vial.vialNumber,
            expiration_date: vial.expirationDate.map { iso.string(from: $0) },
            typical_dose_mcg: vial.typicalDoseMcg,
            mcg_used: vial.mcgUsed,
            bud_days: vial.budDays,
            label_image_filename: vial.labelImageFilename
        )
        do {
            try await supabase
                .from("vials")
                .upsert(payload, onConflict: "user_id,client_id")
                .execute()
        } catch {
            print("[VialSyncService] upsert error: \(error)")
        }
    }

    func delete(clientId: UUID) async {
        guard let uid = await userId() else { return }
        do {
            try await supabase
                .from("vials")
                .delete()
                .eq("user_id", value: uid)
                .eq("client_id", value: clientId.uuidString.lowercased())
                .execute()
        } catch {
            print("[VialSyncService] delete error: \(error)")
        }
    }
}
