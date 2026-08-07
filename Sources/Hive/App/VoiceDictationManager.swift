import Speech
import AVFoundation
import Observation

/// Lightweight voice dictation manager for the WKWebView shell (Hive target).
/// Wraps SFSpeechRecognizer + AVAudioEngine for Comet-style speak-to-fill.
/// Separate from HiveChromium's SpeechRecognizer so the WKWebView shell has
/// no dependency on the CEF shell.
@MainActor
@Observable
final class VoiceDictationManager {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var recordingGeneration: UInt64 = 0

    private(set) var transcribedText: String = ""
    private(set) var isRecording: Bool = false
    private(set) var isAuthorized: Bool = false
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = authorizationStatus == .authorized
    }

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

    func startRecording() throws {
        if isRecording { stopRecording() }
        else { audioEngine.inputNode.removeTap(onBus: 0) }
        recognitionTask?.cancel()
        recognitionTask = nil
        transcribedText = ""

        recordingGeneration &+= 1
        let sessionGeneration = recordingGeneration

        let request = SFSpeechAudioBufferRecognitionRequest()
        guard let sr = speechRecognizer, sr.isAvailable else {
            throw NSError(domain: "VoiceDictation", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }
        recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
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

        recognitionTask = sr.recognitionTask(with: request) { [weak self] result, error in
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
                    print("[VoiceDictation] Recognition error: \(errorMessage)")
                    self.stopRecording()
                }
            }
        }

        isRecording = true
    }

    func stopRecording() {
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
