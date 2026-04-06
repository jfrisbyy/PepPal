import SwiftUI
import PhotosUI

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

    private var voiceTimer: Timer?
    private let maxPhotos = 4
    private let maxCharacters = 500

    var canPost: Bool {
        !isPosting && (!textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !loadedImages.isEmpty || hasVoiceRecording || selectedMarketProgram != nil || selectedWorkoutLog != nil)
    }

    var characterCount: Int { textContent.count }
    var characterProgress: Double { Double(characterCount) / Double(maxCharacters) }
    var isOverLimit: Bool { characterCount > maxCharacters }
    var remainingPhotos: Int { maxPhotos - loadedImages.count }

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
        isRecordingVoice = true
        voiceRecordingDuration = 0
        voiceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.voiceRecordingDuration += 0.1
            }
        }
    }

    func stopVoiceRecording() {
        isRecordingVoice = false
        hasVoiceRecording = voiceRecordingDuration > 0.5
        voiceTimer?.invalidate()
        voiceTimer = nil
    }

    func removeVoiceRecording() {
        hasVoiceRecording = false
        voiceRecordingDuration = 0
    }

    func removeMarketLink() {
        selectedMarketProgram = nil
    }

    func removeWorkoutLog() {
        selectedWorkoutLog = nil
    }

    func createPost(user: SocialUser) -> FeedPost {
        var mediaItems: [FeedMediaItem] = []

        for image in loadedImages {
            mediaItems.append(FeedMediaItem(type: .photo, imageURL: "local://photo-\(UUID().uuidString)"))
        }

        if hasVoiceRecording {
            mediaItems.append(FeedMediaItem(type: .voice, voiceDuration: voiceRecordingDuration))
        }

        if let program = selectedMarketProgram {
            mediaItems.append(FeedMediaItem(type: .marketLink, marketProgram: program))
        }

        if let log = selectedWorkoutLog {
            mediaItems.append(FeedMediaItem(type: .workoutLog, workoutLog: log))
        }

        return FeedPost(
            user: user,
            timestamp: Date(),
            textContent: textContent.trimmingCharacters(in: .whitespacesAndNewlines),
            media: mediaItems,
            tags: Array(selectedTags)
        )
    }

    func reset() {
        textContent = ""
        selectedPhotos = []
        loadedImages = []
        isRecordingVoice = false
        voiceRecordingDuration = 0
        hasVoiceRecording = false
        selectedMarketProgram = nil
        selectedWorkoutLog = nil
        selectedTags = []
        isPosting = false
    }
}
