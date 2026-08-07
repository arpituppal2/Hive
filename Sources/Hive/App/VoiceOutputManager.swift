import AVFoundation
import os.log

// MARK: - VoiceOutputManager
//
// Wraps AVSpeechSynthesizer with Apple's highest-quality neural voices
// for on-device TTS — the "Jarvis speaks back" layer. Complements the
// VoiceDictationManager (STT) to complete the voice loop:
//
//   speak (VoiceDictationManager) → classify (IntentOrchestrator) →
//   think (Swarm Cells) → speak back (VoiceOutputManager)
//
// Design: on-demand, not auto-read-aloud. Research shows users prefer
// clicking a speaker button rather than having every response auto-played.
// Each assistant message has a speaker button; only the clicked one plays.
//
// Uses AVSpeechSynthesizer with neural voices. Apple's Compact Neural TTS
// achieves ~15ms latency on Apple Silicon — zero network, zero cost,
// zero privacy leakage. No cloud dependency.

@MainActor
@Observable
public final class VoiceOutputManager: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()
    private let log = Logger(subsystem: "com.hive.browser", category: "VoiceOutput")

    /// Whether the synthesizer is currently speaking.
    public private(set) var isSpeaking: Bool = false

    /// The currently selected voice identifier (e.g. "com.apple.ttsbundle.siri_Aaron_en-US_compact").
    public private(set) var currentVoiceID: String = ""

    /// Human-readable name of the current voice for UI display.
    public private(set) var currentVoiceName: String = ""

    public override init() {
        super.init()
        synthesizer.delegate = self
        selectBestVoice()
    }

    // MARK: - Public API

    /// Speaks the given text using the best available neural voice.
    /// If already speaking, stops the current utterance first.
    public func speak(_ text: String) {
        guard !text.isEmpty else { return }

        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: currentVoiceID)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05  // slightly faster
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    /// Stops any in-progress speech immediately.
    public func stop() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Returns true if a usable neural voice is available.
    public var isAvailable: Bool {
        !currentVoiceID.isEmpty
    }

    /// A list of available voices for the user to choose from in Settings.
    /// Returns name and identifier pairs, sorted by quality (neural first).
    public func availableVoices() -> [(name: String, identifier: String)] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { a, b in
                let aScore = (a.quality == .enhanced ? 3 : a.quality == .premium ? 2 : 1)
                let bScore = (b.quality == .enhanced ? 3 : b.quality == .premium ? 2 : 1)
                if aScore != bScore { return aScore > bScore }
                return a.name < b.name
            }
            .map { (name: "\($0.name) (\($0.language))", identifier: $0.identifier) }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    // MARK: - Private

    /// Selects the best available neural English voice, falling back to
    /// the default system voice if no neural voice is installed.
    private func selectBestVoice() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        let enhanced = allVoices.first { $0.quality == .enhanced }
        let premium = allVoices.first { $0.quality == .premium }

        if let voice = enhanced ?? premium {
            currentVoiceID = voice.identifier
            currentVoiceName = voice.name
            log.info("Selected neural voice: \(voice.name) (quality: \(voice.quality == .enhanced ? "enhanced" : "premium"))")
        } else if let systemVoice = allVoices.first {
            currentVoiceID = systemVoice.identifier
            currentVoiceName = systemVoice.name
            log.info("Falling back to system voice: \(systemVoice.name)")
        } else {
            log.warning("No English voices available — TTS disabled")
        }
    }
}
