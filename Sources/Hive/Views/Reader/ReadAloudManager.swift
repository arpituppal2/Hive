import SwiftUI
import AVFoundation
import NaturalLanguage

// MARK: - SpeechSegment
//
// A single sentence from the article, tracked with its global offset so highlighting
// can be rendered across the full text.

struct SpeechSegment: Identifiable {
    let id: Int
    let text: String
    let globalNSRange: NSRange
}

// MARK: - ReadAloudManager
//
/// Manages AVSpeechSynthesizer with sentence-level segmentation and synced highlighting.
/// Splits article text into sentences via NLTagger, queues them as AVSpeechUtterance objects,
/// and publishes the active highlight range via `highlightedNSRange`.
///
/// SPEC §25.3 — Read Aloud with sentence highlighting, speed controls, pause/resume/stop.

@MainActor
class ReadAloudManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: Published state

    @Published var fullText: String = ""
    @Published var segments: [SpeechSegment] = []
    @Published var highlightedNSRange: NSRange = .init(location: NSNotFound, length: 0)
    @Published var activeSegmentIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate // 0.0–1.0

    // MARK: Internal

    private var currentUtteranceIndex: Int = 0
    private var pendingStop = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Public API

    /// Load article text and segment into sentences. Doesn't start speaking.
    func load(article: String) {
        fullText = article
        segments = segmentArticleIntoSentences(article)
        highlightedNSRange = .init(location: NSNotFound, length: 0)
        activeSegmentIndex = 0
        currentUtteranceIndex = 0
    }

    /// Start speaking from the beginning.
    func play() {
        guard !segments.isEmpty else { return }
        if isPaused {
            resume()
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        currentUtteranceIndex = 0
        pendingStop = false
        speakCurrentSegment()
    }

    /// Pause at the current word boundary.
    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
    }

    /// Resume from where paused.
    func resume() {
        guard isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
        isPlaying = true
    }

    /// Stop entirely and reset to beginning.
    func stop() {
        pendingStop = true
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentUtteranceIndex = 0
        activeSegmentIndex = 0
        highlightedNSRange = .init(location: NSNotFound, length: 0)
    }

    /// Adjust speech rate. If currently playing, restart current segment at new speed.
    func setRate(_ rate: Float) {
        speechRate = max(0.1, min(1.0, rate))
        guard isPlaying || isPaused else { return }
        // Restart current utterance at new rate
        let tempIndex = currentUtteranceIndex
        synthesizer.stopSpeaking(at: .immediate)
        currentUtteranceIndex = tempIndex
        isPaused = false
        speakCurrentSegment()
    }

    /// Skip forward N sentences (positive) or backward N (negative).
    func skip(_ delta: Int) {
        let newIndex = max(0, min(currentUtteranceIndex + delta, segments.count - 1))
        guard newIndex != currentUtteranceIndex else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentUtteranceIndex = newIndex
        pendingStop = false
        if isPlaying || isPaused {
            isPaused = false
            speakCurrentSegment()
        } else {
            activeSegmentIndex = newIndex
        }
    }

    // MARK: Private

    private func speakCurrentSegment() {
        guard currentUtteranceIndex < segments.count else {
            // Finished all segments
            isPlaying = false
            isPaused = false
            highlightedNSRange = .init(location: NSNotFound, length: 0)
            activeSegmentIndex = 0
            return
        }

        let segment = segments[currentUtteranceIndex]
        let utterance = AVSpeechUtterance(string: segment.text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        isPlaying = true
        isPaused = false
        activeSegmentIndex = currentUtteranceIndex

        // Highlight the entire sentence at start
        highlightedNSRange = segment.globalNSRange

        synthesizer.speak(utterance)
    }

    private func segmentArticleIntoSentences(_ article: String) -> [SpeechSegment] {
        var segments: [SpeechSegment] = []
        var index = 0

        article.enumerateSubstrings(in: article.startIndex..<article.endIndex,
                                     options: [.bySentences, .localized])
        { substring, substringRange, _, _ in
            guard let text = substring else { return }
            let nsRange = NSRange(substringRange, in: article)
            segments.append(SpeechSegment(id: index, text: text, globalNSRange: nsRange))
            index += 1
        }

        return segments
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard currentUtteranceIndex < segments.count else { return }
            let segment = segments[currentUtteranceIndex]
            let globalLocation = segment.globalNSRange.location + characterRange.location
            let globalLength = characterRange.length
            highlightedNSRange = NSRange(location: globalLocation, length: globalLength)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !pendingStop else { return }
            currentUtteranceIndex += 1
            speakCurrentSegment()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPaused = true
            isPlaying = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPaused = false
            isPlaying = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPaused = false
            isPlaying = false
        }
    }
}
