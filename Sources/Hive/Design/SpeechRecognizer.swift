import SwiftUI
import Speech
import AVFoundation

// MARK: - SpeechRecognizer
//
// macOS speech-to-text using SFSpeechRecognizer. Provides real dictation
// for the browser's voice mode — matching Comet's voice mode feature.
// Requires microphone permission in the app's entitlements.
// On macOS, uses AVAudioEngine directly (AVAudioSession is iOS-only).

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    /// Invalidates callbacks from an older recording session. Speech
    /// recognition callbacks can arrive after `stopRecording()` returns.
    private var recordingGeneration: UInt64 = 0

    static let shared = SpeechRecognizer()

    private init() {
        checkAuthorization()
    }

    /// Requests permission only after the user explicitly starts voice mode.
    /// The result is awaitable so the first tap can continue into recording
    /// without requiring a confusing second tap.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.authorizationStatus = status
                    self?.isAuthorized = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = authorizationStatus == .authorized
    }

    func startRecording() throws {
        // A repeated click must not install a second tap on AVAudioEngine's
        // input node. Stop the existing capture first; AVAudioEngine can throw
        // or crash when a tap is installed twice on the same bus.
        if isRecording {
            stopRecording()
        } else {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        transcribedText = ""

        recordingGeneration &+= 1
        let sessionGeneration = recordingGeneration
        let request = SFSpeechAudioBufferRecognitionRequest()
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognizer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }
        recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            // The audio callback captures only the request, not this
            // @MainActor object. No UI/state mutation occurs on the realtime
            // audio thread.
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            recordingGeneration &+= 1
            throw error
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorMessage = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.recordingGeneration == sessionGeneration else { return }
                if let text { self.transcribedText = text }
                self.silenceTimer?.invalidate()
                if isFinal {
                    self.stopRecording()
                } else if text != nil {
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            guard let self, self.recordingGeneration == sessionGeneration else { return }
                            self.stopRecording()
                        }
                    }
                }
                if let errorMessage {
                    print("[SpeechRecognizer] Recognition error: \(errorMessage)")
                    self.stopRecording()
                }
            }
        }

        isRecording = true
    }

    func stopRecording() {
        // Invalidate first: callbacks released by finish/endAudio below must
        // not be allowed to mutate a subsequent session.
        recordingGeneration &+= 1
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false
    }
}
