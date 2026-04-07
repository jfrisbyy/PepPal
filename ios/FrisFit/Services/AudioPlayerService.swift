import AVFoundation
import Combine

@Observable
class AudioPlayerService {
    static let shared = AudioPlayerService()

    var isPlaying: Bool = false
    var currentProgress: Double = 0
    var currentDuration: TimeInterval = 0
    private(set) var currentURL: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var didPlayToEndObserver: NSObjectProtocol?

    private init() {}

    func play(urlString: String, duration: TimeInterval) {
        if currentURL == urlString && isPlaying {
            pause()
            return
        }

        if currentURL == urlString, let player {
            player.play()
            isPlaying = true
            return
        }

        stop()

        guard let url = URL(string: urlString) else { return }

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        self.currentURL = urlString
        self.currentDuration = duration

        configureAudioSession()

        statusObservation = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    newPlayer.play()
                    self?.isPlaying = true
                } else if item.status == .failed {
                    self?.stop()
                }
            }
        }

        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.currentDuration > 0 else { return }
            let seconds = CMTimeGetSeconds(time)
            self.currentProgress = min(seconds / self.currentDuration, 1.0)
        }

        didPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let didPlayToEndObserver {
            NotificationCenter.default.removeObserver(didPlayToEndObserver)
        }
        didPlayToEndObserver = nil

        player?.pause()
        player = nil
        isPlaying = false
        currentProgress = 0
        currentURL = nil
        currentDuration = 0
    }

    func isPlayingURL(_ urlString: String) -> Bool {
        currentURL == urlString && isPlaying
    }

    func progressForURL(_ urlString: String) -> Double {
        currentURL == urlString ? currentProgress : 0
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }
}
