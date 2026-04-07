import SwiftUI
import PhotosUI
import AVFoundation

@Observable
final class PostComposerViewModel {
    var textContent: String = ""
    var selectedPhotos: [PhotosPickerItem] = []
    var loadedImages: [UIImage] = []
    var isRecordingVoice: Bool = false
    var voiceRecordingDuration: TimeInterval = 0
    var hasVoiceRecording: Bool = false
    var selectedMarketProgram: MarketProgram?
    var selectedWorkoutLog: WorkoutLogAttachment?
    var isPosting: Bool = false
    var showPhotoPicker: Bool = false
    var showMarketPicker: Bool = false
    var showWorkoutPicker: Bool = false
    var showAttachmentMenu: Bool = false
    var selectedTags: Set<FeedTag> = []
    var showTagPicker: Bool = false
    var recordingError: String?

    private var voiceTimer: Timer?
    private var audioRecorder: AVAudioRecorder?
    private(set) var voiceRecordingURL: URL?
    private let maxPhotos = 4
    private let maxCharacters = 500

    var canPost: Bool {
        !isPosting && (!textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !loadedImages.isEmpty || hasVoiceRecording || selectedMarketProgram != nil || selectedWorkoutLog != nil)
    }

    var characterCount: Int { textContent.count }
    var characterProgress: Double { Double(characterCount) / Double(maxCharacters) }
    var isOverLimit: Bool { characterCount > maxCharacters }
    var remainingPhotos: Int { maxPhotos - loadedImages.count }

    var voiceRecordingData: Data? {
        guard let url = voiceRecordingURL else { return nil }
        return try? Data(contentsOf: url)
    }

    func loadPhotos() async {
        var images: [UIImage] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        loadedImages = images
    }

    func removePhoto(at index: Int) {
        guard index < loadedImages.count else { return }
        loadedImages.remove(at: index)
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }
    }

    func startVoiceRecording() {
        recordingError = nil
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            recordingError = "Could not set up audio session"
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("voice_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.record()
            audioRecorder = recorder
            voiceRecordingURL = fileURL
            isRecordingVoice = true
            voiceRecordingDuration = 0
            voiceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.voiceRecordingDuration += 0.1
                }
            }
        } catch {
            recordingError = "Could not start recording"
        }
    }

    func stopVoiceRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        voiceTimer?.invalidate()
        voiceTimer = nil
        isRecordingVoice = false
        hasVoiceRecording = voiceRecordingDuration > 0.5
        if !hasVoiceRecording {
            cleanupRecordingFile()
        }
    }

    func removeVoiceRecording() {
        hasVoiceRecording = false
        voiceRecordingDuration = 0
        cleanupRecordingFile()
    }

    private func cleanupRecordingFile() {
        if let url = voiceRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        voiceRecordingURL = nil
    }

    func removeMarketLink() {
        selectedMarketProgram = nil
    }

    func removeWorkoutLog() {
        selectedWorkoutLog = nil
    }

    func reset() {
        textContent = ""
        selectedPhotos = []
        loadedImages = []
        isRecordingVoice = false
        voiceRecordingDuration = 0
        hasVoiceRecording = false
        cleanupRecordingFile()
        selectedMarketProgram = nil
        selectedWorkoutLog = nil
        selectedTags = []
        isPosting = false
        recordingError = nil
    }
}
