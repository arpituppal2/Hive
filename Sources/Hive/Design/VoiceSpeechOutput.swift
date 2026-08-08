@preconcurrency import AVFoundation

/// Small local speech-output seam for Hive Voice.
///
/// This intentionally uses the system voice first: it is private, available
/// without downloading weights, and honest about its capability. A future
/// bundled neural voice can implement the same surface without changing the
/// voice coordinator or browser UI.
@MainActor
final class VoiceSpeechOutput: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?

    /// Called on the main actor after the current utterance finishes or is
    /// cancelled. The identity check below prevents a late callback from an
    /// older utterance from completing a newer voice turn.
    var onFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func stop() {
        // Clear the identity before stopping. AVFoundation may deliver a
        // didCancel callback synchronously or shortly after stopSpeaking; it
        // must not transition a newly-started turn into completed.
        activeUtterance = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func speak(_ text: String) {
        stop()
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            onFinished?()
            return
        }

        // Spoken output is a concise status/result surface, not a second copy
        // of an entire research brief or source document.
        let bounded = String(clean.prefix(480))
        let utterance = AVSpeechUtterance(string: bounded)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        completeIfCurrent(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        completeIfCurrent(utterance)
    }

    private func completeIfCurrent(_ utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        activeUtterance = nil
        onFinished?()
    }
}
