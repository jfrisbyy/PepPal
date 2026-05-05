import AVFoundation
import AudioToolbox
import UIKit

@MainActor
final class RestTimerAudio {
    static let shared = RestTimerAudio()
    private init() {}

    private var player: AVAudioPlayer?

    func prepare() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[RestTimerAudio] prepare: \(error)")
        }
    }

    func fireCompletion() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            let notice = UINotificationFeedbackGenerator()
            notice.notificationOccurred(.success)
        }

        AudioServicesPlaySystemSound(1057)
    }
}
