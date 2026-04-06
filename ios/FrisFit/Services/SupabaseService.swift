import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let supabaseURL = Config.EXPO_PUBLIC_SUPABASE_URL
        let supabaseKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

        guard let url = URL(string: supabaseURL), !supabaseURL.isEmpty, !supabaseKey.isEmpty else {
            fatalError("Supabase URL or Anon Key not configured in environment variables.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
    }
}
