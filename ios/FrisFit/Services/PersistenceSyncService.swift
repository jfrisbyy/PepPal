import Foundation
import Supabase

// MARK: - DTOs

nonisolated struct PersonalRecordRow: Codable, Sendable {
    let user_id: String
    let exercise_id: String
    let exercise_name: String
    let best_weight: Double
    let best_one_rm: Double
    let best_volume: Double
    let updated_at: String?
}

nonisolated struct RoutineRow: Codable, Sendable {
    let id: String
    let user_id: String
    let name: String
    let notes: String
    let exercises: String   // JSON-encoded ProgramExercise array
    let times_performed: Int
    let last_performed_at: String?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct TrackedCompoundRow: Codable, Sendable {
    let user_id: String
    let compound_name: String
    let created_at: String?
}

nonisolated struct FoodFavoriteRow: Codable, Sendable {
    let id: String
    let user_id: String
    let name: String
    let brand: String
    let serving_size: String
    let serving_grams: Double
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let added_at: String?
}

nonisolated struct AIMemoryFactRow: Codable, Sendable {
    let id: String
    let user_id: String
    let category: String
    let content: String   // JSON-encoded AIMemoryFact
    let confidence: Double
    let source: String?
    let created_at: String?
    let updated_at: String?
}

nonisolated struct ConversationMuteRow: Codable, Sendable {
    let user_id: String
    let conversation_id: String
}

nonisolated struct ModerationMutedUserRow: Codable, Sendable {
    let user_id: String
    let target_user_id: String
}

nonisolated struct ModerationTagRow: Codable, Sendable {
    let user_id: String
    let tag: String
}

nonisolated struct ModerationKeywordRow: Codable, Sendable {
    let user_id: String
    let keyword: String
}

nonisolated struct ModerationReportRow: Codable, Sendable {
    let user_id: String
    let target_kind: String   // 'post' | 'comment' | 'message'
    let target_id: String
}

/// Centralised Supabase persistence helpers for what used to live in
/// `UserDefaults`. Every method swallows errors so writes never crash the UI;
/// the local cache stays the source of truth between sync windows.
nonisolated final class PersistenceSyncService: @unchecked Sendable {
    static let shared = PersistenceSyncService()
    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func currentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString.lowercased()
        } catch {
            return nil
        }
    }

    // MARK: - Personal Records

    func upsertPersonalRecord(
        exerciseId: String,
        exerciseName: String,
        bestWeight: Double,
        bestOneRM: Double,
        bestVolume: Double
    ) async {
        guard let uid = await currentUserId() else { return }
        let row = PersonalRecordRow(
            user_id: uid,
            exercise_id: exerciseId,
            exercise_name: exerciseName,
            best_weight: bestWeight,
            best_one_rm: bestOneRM,
            best_volume: bestVolume,
            updated_at: Self.iso.string(from: Date())
        )
        do {
            try await supabase.from("personal_records").upsert(row, onConflict: "user_id,exercise_id").execute()
        } catch {
            print("PR upsert failed: \(error.localizedDescription)")
        }
    }

    func fetchPersonalRecords() async -> [PersonalRecordRow] {
        guard let uid = await currentUserId() else { return [] }
        do {
            return try await supabase.from("personal_records")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
        } catch {
            print("PR fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Routines

    func upsertRoutine(_ row: RoutineRow) async {
        do {
            try await supabase.from("routines").upsert(row, onConflict: "id").execute()
        } catch {
            print("Routine upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteRoutine(id: String) async {
        do {
            try await supabase.from("routines").delete().eq("id", value: id).execute()
        } catch {
            print("Routine delete failed: \(error.localizedDescription)")
        }
    }

    func fetchRoutines() async -> [RoutineRow] {
        guard let uid = await currentUserId() else { return [] }
        do {
            return try await supabase.from("routines")
                .select()
                .eq("user_id", value: uid)
                .order("updated_at", ascending: false)
                .execute()
                .value
        } catch {
            print("Routine fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Tracked Compounds

    func setTrackedCompound(_ name: String, tracked: Bool) async {
        guard let uid = await currentUserId() else { return }
        do {
            if tracked {
                let row = TrackedCompoundRow(user_id: uid, compound_name: name, created_at: nil)
                try await supabase.from("tracked_compounds").upsert(row, onConflict: "user_id,compound_name").execute()
            } else {
                try await supabase.from("tracked_compounds")
                    .delete()
                    .eq("user_id", value: uid)
                    .eq("compound_name", value: name)
                    .execute()
            }
        } catch {
            print("Tracked compound sync failed: \(error.localizedDescription)")
        }
    }

    func fetchTrackedCompounds() async -> [String] {
        guard let uid = await currentUserId() else { return [] }
        do {
            let rows: [TrackedCompoundRow] = try await supabase.from("tracked_compounds")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
            return rows.map { $0.compound_name }
        } catch {
            print("Tracked compound fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Food Favorites

    func upsertFoodFavorite(_ row: FoodFavoriteRow) async {
        do {
            try await supabase.from("food_favorites").upsert(row, onConflict: "id").execute()
        } catch {
            print("Food favorite upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteFoodFavorite(id: String) async {
        do {
            try await supabase.from("food_favorites").delete().eq("id", value: id).execute()
        } catch {
            print("Food favorite delete failed: \(error.localizedDescription)")
        }
    }

    func fetchFoodFavorites() async -> [FoodFavoriteRow] {
        guard let uid = await currentUserId() else { return [] }
        do {
            return try await supabase.from("food_favorites")
                .select()
                .eq("user_id", value: uid)
                .order("added_at", ascending: false)
                .execute()
                .value
        } catch {
            print("Food favorites fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - AI Memory Facts

    func upsertAIMemoryFact(id: String, category: String, contentJSON: String, confidence: Double, source: String?) async {
        guard let uid = await currentUserId() else { return }
        let row = AIMemoryFactRow(
            id: id,
            user_id: uid,
            category: category,
            content: contentJSON,
            confidence: confidence,
            source: source,
            created_at: nil,
            updated_at: Self.iso.string(from: Date())
        )
        do {
            try await supabase.from("ai_memory_facts").upsert(row, onConflict: "id").execute()
        } catch {
            print("AI memory upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteAIMemoryFact(id: String) async {
        do {
            try await supabase.from("ai_memory_facts").delete().eq("id", value: id).execute()
        } catch {
            print("AI memory delete failed: \(error.localizedDescription)")
        }
    }

    func fetchAIMemoryFacts() async -> [AIMemoryFactRow] {
        guard let uid = await currentUserId() else { return [] }
        do {
            return try await supabase.from("ai_memory_facts")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
        } catch {
            print("AI memory fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Conversation Mutes

    func upsertConversationMute(conversationId: String) async {
        guard let uid = await currentUserId() else { return }
        let row = ConversationMuteRow(user_id: uid, conversation_id: conversationId)
        do {
            try await supabase.from("conversation_mutes")
                .upsert(row, onConflict: "user_id,conversation_id")
                .execute()
        } catch {
            print("Conversation mute upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteConversationMute(conversationId: String) async {
        guard let uid = await currentUserId() else { return }
        do {
            try await supabase.from("conversation_mutes")
                .delete()
                .eq("user_id", value: uid)
                .eq("conversation_id", value: conversationId)
                .execute()
        } catch {
            print("Conversation mute delete failed: \(error.localizedDescription)")
        }
    }

    func fetchConversationMutes() async -> [String] {
        guard let uid = await currentUserId() else { return [] }
        do {
            let rows: [ConversationMuteRow] = try await supabase.from("conversation_mutes")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
            return rows.map { $0.conversation_id }
        } catch {
            print("Conversation mute fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Moderation: muted users

    func upsertModerationMutedUser(_ targetUserId: String) async {
        guard let uid = await currentUserId() else { return }
        let row = ModerationMutedUserRow(user_id: uid, target_user_id: targetUserId)
        do {
            try await supabase.from("moderation_muted_users")
                .upsert(row, onConflict: "user_id,target_user_id")
                .execute()
        } catch {
            print("Moderation muted user upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteModerationMutedUser(_ targetUserId: String) async {
        guard let uid = await currentUserId() else { return }
        do {
            try await supabase.from("moderation_muted_users")
                .delete()
                .eq("user_id", value: uid)
                .eq("target_user_id", value: targetUserId)
                .execute()
        } catch {
            print("Moderation muted user delete failed: \(error.localizedDescription)")
        }
    }

    func fetchModerationMutedUsers() async -> [String] {
        guard let uid = await currentUserId() else { return [] }
        do {
            let rows: [ModerationMutedUserRow] = try await supabase.from("moderation_muted_users")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
            return rows.map { $0.target_user_id }
        } catch {
            print("Moderation muted users fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Moderation: muted tags

    func upsertModerationMutedTag(_ tag: String) async {
        guard let uid = await currentUserId() else { return }
        let row = ModerationTagRow(user_id: uid, tag: tag)
        do {
            try await supabase.from("moderation_muted_tags")
                .upsert(row, onConflict: "user_id,tag")
                .execute()
        } catch {
            print("Moderation muted tag upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteModerationMutedTag(_ tag: String) async {
        guard let uid = await currentUserId() else { return }
        do {
            try await supabase.from("moderation_muted_tags")
                .delete()
                .eq("user_id", value: uid)
                .eq("tag", value: tag)
                .execute()
        } catch {
            print("Moderation muted tag delete failed: \(error.localizedDescription)")
        }
    }

    func fetchModerationMutedTags() async -> [String] {
        guard let uid = await currentUserId() else { return [] }
        do {
            let rows: [ModerationTagRow] = try await supabase.from("moderation_muted_tags")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
            return rows.map { $0.tag }
        } catch {
            print("Moderation muted tags fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Moderation: followed tags

    func upsertModerationFollowedTag(_ tag: String) async {
        guard let uid = await currentUserId() else { return }
        let row = ModerationTagRow(user_id: uid, tag: tag)
        do {
            try await supabase.from("moderation_followed_tags")
                .upsert(row, onConflict: "user_id,tag")
                .execute()
        } catch {
            print("Moderation followed tag upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteModerationFollowedTag(_ tag: String) async {
        guard let uid = await currentUserId() else { return }
        do {
            try await supabase.from("moderation_followed_tags")
                .delete()
                .eq("user_id", value: uid)
                .eq("tag", value: tag)
                .execute()
        } catch {
            print("Moderation followed tag delete failed: \(error.localizedDescription)")
        }
    }

    func fetchModerationFollowedTags() async -> [String] {
        guard let uid = await currentUserId() else { return [] }
        do {
            let rows: [ModerationTagRow] = try await supabase.from("moderation_followed_tags")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
            return rows.map { $0.tag }
        } catch {
            print("Moderation followed tags fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Moderation: keyword filters

    func upsertModerationKeyword(_ keyword: String) async {
        guard let uid = await currentUserId() else { return }
        let row = ModerationKeywordRow(user_id: uid, keyword: keyword)
        do {
            try await supabase.from("moderation_keyword_filters")
                .upsert(row, onConflict: "user_id,keyword")
                .execute()
        } catch {
            print("Moderation keyword upsert failed: \(error.localizedDescription)")
        }
    }

    func deleteModerationKeyword(_ keyword: String) async {
        guard let uid = await currentUserId() else { return }
        do {
            try await supabase.from("moderation_keyword_filters")
                .delete()
                .eq("user_id", value: uid)
                .eq("keyword", value: keyword)
                .execute()
        } catch {
            print("Moderation keyword delete failed: \(error.localizedDescription)")
        }
    }

    func fetchModerationKeywords() async -> [String] {
        guard let uid = await currentUserId() else { return [] }
        do {
            let rows: [ModerationKeywordRow] = try await supabase.from("moderation_keyword_filters")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
            return rows.map { $0.keyword }
        } catch {
            print("Moderation keywords fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Moderation: reports

    func upsertModerationReport(kind: String, targetId: String) async {
        guard let uid = await currentUserId() else { return }
        let row = ModerationReportRow(user_id: uid, target_kind: kind, target_id: targetId)
        do {
            try await supabase.from("moderation_reports")
                .upsert(row, onConflict: "user_id,target_kind,target_id")
                .execute()
        } catch {
            print("Moderation report upsert failed: \(error.localizedDescription)")
        }
    }

    /// Returns rows grouped by `target_kind` so callers can hydrate each set in
    /// one round-trip.
    func fetchModerationReports() async -> [ModerationReportRow] {
        guard let uid = await currentUserId() else { return [] }
        do {
            return try await supabase.from("moderation_reports")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value
        } catch {
            print("Moderation reports fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
