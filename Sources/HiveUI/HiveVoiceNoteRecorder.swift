import AVFoundation
import Foundation
import Speech
import SwiftUI

public struct HiveVoiceNoteResult: Sendable {
    public var audioURL: URL
    public var transcript: String?
    public var message: String

    public init(audioURL: URL, transcript: String?, message: String) {
        self.audioURL = audioURL
        self.transcript = transcript
        self.message = message
    }
}

@MainActor
public final class HiveVoiceNoteRecorder: NSObject, ObservableObject {
    @Published public private(set) var isRecording = false
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var statusText = "Ready for a voice note"

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    public func start() {
        requestMicrophoneAccess { [weak self] granted in
            guard let self else { return }
            if granted {
                self.startRecorder()
            } else {
                self.statusText = "Microphone access is off"
            }
        }
    }

    public func stop(completion: @escaping @MainActor (HiveVoiceNoteResult) -> Void) {
        guard isRecording, let url = currentURL else { return }
        recorder?.stop()
        recorder = nil
        isRecording = false
        statusText = "Turning speech into a note"
        transcribe(url: url, completion: completion)
    }

    private func requestMicrophoneAccess(_ completion: @escaping @MainActor (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func startRecorder() {
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Hive Voice Notes", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let url = directory.appendingPathComponent("voice-note-\(stamp).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            self.recorder = recorder
            currentURL = url
            isRecording = true
            statusText = "Recording"
        } catch {
            statusText = "Could not start recording"
        }
    }

    private func transcribe(url: URL, completion: @escaping @MainActor (HiveVoiceNoteResult) -> Void) {
        isTranscribing = true
        SFSpeechRecognizer.requestAuthorization { [weak self] authorization in
            DispatchQueue.main.async {
                guard let self else { return }
                guard authorization == .authorized,
                      let recognizer = SFSpeechRecognizer(locale: Locale.current),
                      recognizer.isAvailable
                else {
                    self.isTranscribing = false
                    self.statusText = "Voice saved"
                    completion(HiveVoiceNoteResult(
                        audioURL: url,
                        transcript: nil,
                        message: "Voice saved. Turn on speech recognition to transcribe it automatically."
                    ))
                    return
                }

                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = false
                if recognizer.supportsOnDeviceRecognition {
                    request.requiresOnDeviceRecognition = true
                }
                recognizer.recognitionTask(with: request) { result, error in
                    guard result?.isFinal == true || error != nil else { return }
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        let transcript = result?.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let transcript, !transcript.isEmpty {
                            self.statusText = "Voice note captured"
                            completion(HiveVoiceNoteResult(
                                audioURL: url,
                                transcript: transcript,
                                message: "Voice note added."
                            ))
                        } else {
                            self.statusText = "Voice saved"
                            completion(HiveVoiceNoteResult(
                                audioURL: url,
                                transcript: nil,
                                message: "Voice saved. Hive could not hear enough speech to make a note."
                            ))
                        }
                    }
                }
            }
        }
    }
}
