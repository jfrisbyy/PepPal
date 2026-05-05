import Foundation
import Supabase

nonisolated struct SupabaseMacroTarget: Codable, Sendable {
    let user_id: String?
    let calories: Int
    let protein_g: Int
    let carbs_g: Int
    let fat_g: Int
    let source: String?
    let updated_at: String?
}

nonisolated struct SupabaseMacroTargetUpsert: Codable, Sendable {
    let user_id: String
    let calories: Int
    let protein_g: Int
    let carbs_g: Int
    let fat_g: Int
    let source: String
}

final class MacroTargetService {
    static let shared = MacroTargetService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private func userId() async -> String? {
        guard let session = try? await supabase.auth.session else { return nil }
        return session.user.id.uuidString.lowercased()
    }

    func fetch() async -> MacroTarget? {
        guard let uid = await userId() else { return nil }
        do {
            let rows: [SupabaseMacroTarget] = try await supabase
                .from("macro_targets")
                .select()
                .eq("user_id", value: uid)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return nil }
            return MacroTarget(
                calories: row.calories,
                protein: row.protein_g,
                carbs: row.carbs_g,
                fat: row.fat_g
            )
        } catch {
            print("[MacroTargetService] fetch error: \(error)")
            return nil
        }
    }

    func upsert(_ target: MacroTarget, source: String = "manual") async {
        guard let uid = await userId() else { return }
        let payload = SupabaseMacroTargetUpsert(
            user_id: uid,
            calories: target.calories,
            protein_g: target.protein,
            carbs_g: target.carbs,
            fat_g: target.fat,
            source: source
        )
        do {
            try await supabase
                .from("macro_targets")
                .upsert(payload, onConflict: "user_id")
                .execute()
        } catch {
            print("[MacroTargetService] upsert error: \(error)")
        }
    }
}
