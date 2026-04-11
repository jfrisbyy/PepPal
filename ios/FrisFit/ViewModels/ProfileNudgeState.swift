import SwiftUI

@Observable
final class ProfileNudgeState {
    var isComplete: Bool = true
    var isDismissed: Bool = false
    var profileViewModel = ProfileViewModel()

    func checkProfile() async {
        await profileViewModel.loadProfile()
        isComplete = profileViewModel.profile.isBiometricProfileComplete
    }
}
