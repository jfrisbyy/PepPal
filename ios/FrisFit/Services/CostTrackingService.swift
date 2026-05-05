import Foundation
import Supabase

nonisolated struct CompoundCost: Identifiable, Sendable {
    let id: UUID = UUID()
    var supabaseId: String?
    let compoundName: String
    let pricePerVial: Double
    let vialSizeMg: Double
    let currency: String
}

nonisolated struct SupabaseCompoundCost: Codable, Sendable {
    let id: String?
    let user_id: String?
    let protocol_id: String
    let compound_name: String
    let price_per_vial: Double
    let vial_size_mg: Double
    let currency: String?
    let created_at: String?
}

nonisolated struct SupabaseCompoundCostInsert: Codable, Sendable {
    let user_id: String
    let protocol_id: String
    let compound_name: String
    let price_per_vial: Double
    let vial_size_mg: Double
    let currency: String
}

final class CostTrackingService {
    static let shared = CostTrackingService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    func fetchCosts(protocolId: String) async throws -> [CompoundCost] {
        let rows: [SupabaseCompoundCost] = try await supabase
            .from("compound_costs")
            .select()
            .eq("protocol_id", value: protocolId)
            .execute()
            .value
        return rows.map {
            var c = CompoundCost(
                compoundName: $0.compound_name,
                pricePerVial: $0.price_per_vial,
                vialSizeMg: $0.vial_size_mg,
                currency: $0.currency ?? "USD"
            )
            c.supabaseId = $0.id
            return c
        }
    }

    func upsertCost(protocolId: String, compoundName: String, pricePerVial: Double, vialSizeMg: Double, currency: String = "USD") async throws {
        guard let session = try? await supabase.auth.session else { return }
        let userId = session.user.id.uuidString.lowercased()
        let payload = SupabaseCompoundCostInsert(
            user_id: userId,
            protocol_id: protocolId,
            compound_name: compoundName,
            price_per_vial: pricePerVial,
            vial_size_mg: vialSizeMg,
            currency: currency
        )
        _ = try await supabase
            .from("compound_costs")
            .upsert(payload, onConflict: "protocol_id,compound_name")
            .execute()
    }

    func delete(id: String) async throws {
        try await supabase.from("compound_costs").delete().eq("id", value: id).execute()
    }

    // MARK: - Math helpers

    /// Cost per mg = pricePerVial / vialSizeMg
    static func costPerDose(cost: CompoundCost, doseMcg: Double) -> Double {
        guard cost.vialSizeMg > 0 else { return 0 }
        let pricePerMg = cost.pricePerVial / cost.vialSizeMg
        return pricePerMg * (doseMcg / 1000.0)
    }

    /// Estimated monthly spend for a compound assuming X doses per week.
    static func monthlySpend(cost: CompoundCost, doseMcg: Double, dosesPerWeek: Double) -> Double {
        costPerDose(cost: cost, doseMcg: doseMcg) * dosesPerWeek * 4.33
    }
}
