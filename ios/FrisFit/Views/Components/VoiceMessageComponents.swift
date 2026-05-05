import SwiftUI
import AVFoundation

@Observable
final class DMVoiceRecorder {
    var isRecording: Bool = false
    var duration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?

    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch { return }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dmvoice_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.record()
            recorder = r
            fileURL = url
            duration = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.duration += 0.1 }
            }
        } catch {}
    }

    func finish() -> (Data, TimeInterval)? {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        let dur = duration
        defer { cleanup() }
        guard dur > 0.3, let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return (data, dur)
    }

    func cancel() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        cleanup()
    }

    private func cleanup() {
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
        recorder = nil
        duration = 0
    }
}

struct VoiceMessagePlayer: View {
    let attachment: DirectMessageAttachment
    let isFromMe: Bool

    private var player: AudioPlayerService { AudioPlayerService.shared }

    private var isCurrent: Bool { player.currentURL == attachment.url }
    private var isPlaying: Bool { isCurrent && player.isPlaying }
    private var progress: Double { isCurrent ? player.currentProgress : 0 }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                player.play(urlString: attachment.url, duration: attachment.durationSeconds ?? 0)
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isFromMe ? .white : PepTheme.teal)
                    .contentTransition(.symbolEffect(.replace))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill((isFromMe ? Color.white : PepTheme.textSecondary).opacity(0.25))
                        .frame(height: 3)
                    Capsule()
                        .fill(isFromMe ? Color.white : PepTheme.teal)
                        .frame(width: geo.size.width * progress, height: 3)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 30)

            Text(formatVoiceDuration(attachment.durationSeconds ?? 0))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isFromMe ? .white.opacity(0.9) : PepTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 220)
        .background(
            isFromMe
                ? AnyShapeStyle(LinearGradient(colors: [PepTheme.teal, PepTheme.teal.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyShapeStyle(PepTheme.elevated)
        )
        .clipShape(.rect(
            topLeadingRadius: isFromMe ? 18 : 6,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: isFromMe ? 6 : 18,
            topTrailingRadius: 18
        ))
    }

}

func formatVoiceDuration(_ duration: TimeInterval) -> String {
    let m = Int(duration) / 60
    let s = Int(duration) % 60
    return String(format: "%d:%02d", m, s)
}
