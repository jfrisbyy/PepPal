import Foundation
import AVFoundation
import Speech

nonisolated enum WhisperError: Error, LocalizedError, Sendable {
    case noAudio
    case recordingFailed
    case notAuthorized
    case recognizerUnavailable
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudio: return "No audio captured."
        case .recordingFailed: return "Recording failed."
        case .notAuthorized: return "Speech recognition not authorized."
        case .recognizerUnavailable: return "On-device speech recognition is unavailable on this device."
        case .recognitionFailed(let msg): return msg
        }
    }
}

@Observable
final class WhisperRecorder: NSObject {
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var errorMessage: String?
    var partialTranscript: String = ""

    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var finalTranscript: String = ""
    private var continuation: CheckedContinuation<String, Never>?

    func requestPermission() async -> Bool {
        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else { return false }

        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        return speechStatus == .authorized
    }

    func startRecording() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw WhisperError.recognizerUnavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        finalTranscript = ""
        partialTranscript = ""

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.partialTranscript = text
                }
                if result.isFinal {
                    self.finalTranscript = text
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.finishTask()
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecordingAndTranscribe() async -> String? {
        guard isRecording else { return nil }
        isRecording = false
        isTranscribing = true
        defer { isTranscribing = false }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()

        let result: String = await withCheckedContinuation { cont in
            continuation = cont
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func cancel() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        continuation?.resume(returning: "")
        continuation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finishTask() {
        let text = finalTranscript.isEmpty ? partialTranscript : finalTranscript
        task = nil
        request = nil
        let cont = continuation
        continuation = nil
        cont?.resume(returning: text)
    }
}
