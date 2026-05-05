import Foundation
import Supabase
import Security

nonisolated final class KeychainAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let service: String

    init(service: String = "peppal.supabase.auth") {
        self.service = service
    }

    private func baseQuery(key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }

    func store(key: String, value: Data) throws {
        var query = baseQuery(key: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainAuthLocalStorage.store", code: Int(status))
        }
    }

    func retrieve(key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainAuthLocalStorage.retrieve", code: Int(status))
        }
        return result as? Data
    }

    func remove(key: String) throws {
        let query = baseQuery(key: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "KeychainAuthLocalStorage.remove", code: Int(status))
        }
    }
}

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let supabaseURL = Config.EXPO_PUBLIC_SUPABASE_URL
        let supabaseKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

        if supabaseURL.isEmpty || supabaseKey.isEmpty {
            print("CRITICAL: Supabase URL or Anon Key is empty. Network requests will fail.")
        }

        let url: URL
        if let parsed = URL(string: supabaseURL), !supabaseURL.isEmpty {
            url = parsed
        } else {
            print("CRITICAL: Supabase URL is invalid or empty. Using placeholder URL.")
            url = URL(string: "https://placeholder.supabase.co")!
        }

        let key = supabaseKey.isEmpty ? "placeholder_key" : supabaseKey

        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                storage: KeychainAuthLocalStorage(service: "peppal.supabase.auth"),
                storageKey: "peppal.supabase.auth",
                autoRefreshToken: true
            )
        )

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: options
        )
        print("APP_INIT: SupabaseService initialized (URL valid: \(!supabaseURL.isEmpty), Key present: \(!supabaseKey.isEmpty), storage: Keychain)")
    }
}
