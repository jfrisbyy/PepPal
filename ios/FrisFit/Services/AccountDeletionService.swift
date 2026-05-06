import Foundation
import Supabase
import Functions

/// Single source of truth for "delete my account".
///
/// Calls the `super-action` edge function with `action: "deleteAccount"`,
/// which:
///   1. Wipes every `public.<table>` row keyed to the user via the
///      `delete_user_data` SECURITY DEFINER RPC.
///   2. Removes per-user folders from every storage bucket.
///   3. Deletes the `auth.users` row.
/// On success we sign the local session out so the app returns to the
/// auth gate immediately.
enum AccountDeletionService {
    private struct DeleteAccountBody: Encodable, Sendable {
        let action: String
    }

    /// Performs the full server-side wipe and signs out.
    /// Throws if the edge function call fails so the UI can surface an error.
    static func deleteAccountAndSignOut() async throws {
        try await SupabaseService.shared.client.functions
            .invoke(
                "super-action",
                options: FunctionInvokeOptions(
                    body: DeleteAccountBody(action: "deleteAccount")
                )
            )
        try? await AuthService.shared.signOut()
    }
}
