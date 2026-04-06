import Foundation
import Supabase

@Observable
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: Config.EXPO_PUBLIC_SUPABASE_URL), !Config.EXPO_PUBLIC_SUPABASE_URL.isEmpty else {
            fatalError("Missing EXPO_PUBLIC_SUPABASE_URL")
        }
        let anonKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
        guard !anonKey.isEmpty else {
            fatalError("Missing EXPO_PUBLIC_SUPABASE_ANON_KEY")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
}
