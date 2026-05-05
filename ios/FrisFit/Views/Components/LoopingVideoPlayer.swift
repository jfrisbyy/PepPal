import SwiftUI
import AVKit

/// A silent, auto-looping AVPlayer view for exercise form demos.
struct LoopingVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .disabled(false)
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }
        }
        .onAppear { setup() }
        .onDisappear {
            player?.pause()
            player = nil
            looper = nil
        }
    }

    private func setup() {
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        queue.play()
    }
}
