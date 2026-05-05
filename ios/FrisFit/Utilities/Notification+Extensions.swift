import Foundation

extension Notification.Name {
    static let mealDataChanged = Notification.Name("mealDataChanged")
    static let mealPersistedToSupabase = Notification.Name("mealPersistedToSupabase")
    static let switchToHomeTab = Notification.Name("switchToHomeTab")
    static let switchToInsightsTab = Notification.Name("switchToInsightsTab")
    /// Posted whenever any user data is successfully written to Supabase
    /// (meals, workouts, activities, weight, protocol doses, side effects, etc.).
    /// AI insight generators observe this to refresh when fresh data is available.
    static let supabaseDataChanged = Notification.Name("supabaseDataChanged")
    /// Posted when the user taps a quick-action button inside a linked task's
    /// "auto-completes when…" dialog (e.g. "Log a Meal" from the calorie task).
    /// userInfo["action"] is the `LinkedTaskQuickAction.label`.
    static let linkedTaskQuickAction = Notification.Name("linkedTaskQuickAction")
    /// Posted when an active workout completes, carrying per-exercise results so
    /// the training program can auto-advance prescribed weights.
    static let workoutCompletedForProgression = Notification.Name("workoutCompletedForProgression")
    /// Posted when the set of active programs (or the displayed/primary program) changes.
    static let activeProgramsChanged = Notification.Name("activeProgramsChanged")
    /// Posted whenever the signed-in Supabase user changes (sign-in, sign-out, account switch).
    /// userInfo["userId"] is the new user id String, or nil/missing on sign-out.
    static let authUserChanged = Notification.Name("authUserChanged")
}
