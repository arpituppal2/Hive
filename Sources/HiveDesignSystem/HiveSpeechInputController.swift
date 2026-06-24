import Foundation
import SwiftUI

#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
#endif

#if canImport(Speech) && !os(watchOS)
import Speech
#endif

public struct SwarmVoiceOption: Identifiable, Hashable, Sendable {
    public var id: String { identifier }
    public var identifier: String
    public var displayName: String
    public var language: String
    public var qualityLabel: String
    public var isPersonalVoice: Bool

    public init(
        identifier: String,
        displayName: String,
        language: String,
        qualityLabel: String,
        isPersonalVoice: Bool
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.language = language
        self.qualityLabel = qualityLabel
        self.isPersonalVoice = isPersonalVoice
    }
}

public enum SwarmVoiceSettingsStore {
    public static let selectedVoiceIdentifierKey = "hive.swarm.live.selectedVoiceIdentifier"

    public static func selectedVoiceIdentifier(defaults: UserDefaults = .standard) -> String? {
        let value = defaults.string(forKey: selectedVoiceIdentifierKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    public static func saveSelectedVoiceIdentifier(_ identifier: String?, defaults: UserDefaults = .standard) {
        defaults.set(identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", forKey: selectedVoiceIdentifierKey)
    }
}

public final class SwarmVoiceManager {
    public init() {}

    #if canImport(AVFoundation) && !os(watchOS)
    /// Fetches available high-quality English voices, including user Personal Voices.
    public func getHighQualityVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        return allVoices
            .filter { voice in
                voice.language.hasPrefix("en-")
                    && (
                        voice.quality == .enhanced
                        || voice.quality == .premium
                        || voice.identifier.localizedCaseInsensitiveContains("personal")
                    )
            }
            .sorted { lhs, rhs in
                let leftRank = qualityRank(lhs)
                let rightRank = qualityRank(rhs)
                if leftRank != rightRank { return leftRank < rightRank }
                if lhs.language != rhs.language { return lhs.language < rhs.language }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    public func highQualityVoiceOptions() -> [SwarmVoiceOption] {
        getHighQualityVoices().map { voice in
            let quality = qualityLabel(voice)
            return SwarmVoiceOption(
                identifier: voice.identifier,
                displayName: "\(voice.name) (\(quality))",
                language: voice.language,
                qualityLabel: quality,
                isPersonalVoice: isPersonalVoice(voice)
            )
        }
    }

    public func voice(for identifier: String?) -> AVSpeechSynthesisVoice? {
        guard let identifier,
              !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }

    private func qualityRank(_ voice: AVSpeechSynthesisVoice) -> Int {
        if isPersonalVoice(voice) { return 0 }
        if voice.quality == .premium { return 1 }
        if voice.quality == .enhanced { return 2 }
        return 3
    }

    private func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        if isPersonalVoice(voice) { return "Personal Voice" }
        if voice.quality == .premium { return "Premium" }
        if voice.quality == .enhanced { return "Enhanced" }
        return "Standard"
    }

    private func isPersonalVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        voice.identifier.localizedCaseInsensitiveContains("personal")
            || voice.name.localizedCaseInsensitiveContains("personal")
    }
    #else
    public func highQualityVoiceOptions() -> [SwarmVoiceOption] {
        []
    }
    #endif
}

@MainActor
public final class HiveSpeechInputController: NSObject, ObservableObject {
    public static let readyStatus = "Dictation ready"

    @Published public private(set) var isRecording = false
    @Published public private(set) var statusText = HiveSpeechInputController.readyStatus

    private var baseText = ""
    private var onTranscriptChange: (@MainActor (String) -> Void)?

    #if canImport(AVFoundation) && canImport(Speech) && !os(watchOS)
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    public var isSupported: Bool {
        #if canImport(AVFoundation) && canImport(Speech) && !os(watchOS)
        return SFSpeechRecognizer(locale: Locale.current) != nil
        #else
        return false
        #endif
    }

    public var shouldShowStatus: Bool {
        isRecording || statusText != Self.readyStatus
    }

    public func toggle(appendingTo currentText: String, update: @escaping @MainActor (String) -> Void) {
        if isRecording {
            stop()
        } else {
            start(appendingTo: currentText, update: update)
        }
    }

    public func start(appendingTo currentText: String, update: @escaping @MainActor (String) -> Void) {
        #if canImport(AVFoundation) && canImport(Speech) && !os(watchOS)
        guard !isRecording else { return }
        baseText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        onTranscriptChange = update
        requestMicrophoneAccess { [weak self] microphoneGranted in
            guard let self else { return }
            guard microphoneGranted else {
                self.statusText = "Turn on microphone access to dictate."
                return
            }
            self.requestSpeechAuthorization { [weak self] speechGranted in
                guard let self else { return }
                guard speechGranted else {
                    self.statusText = "Turn on speech recognition to dictate."
                    return
                }
                self.startRecognition()
            }
        }
        #else
        statusText = "Use keyboard dictation for this field."
        #endif
    }

    public func stop() {
        #if canImport(AVFoundation) && canImport(Speech) && !os(watchOS)
        guard isRecording || recognitionTask != nil else { return }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        statusText = Self.readyStatus
        #else
        isRecording = false
        statusText = Self.readyStatus
        #endif
    }

    #if canImport(AVFoundation) && canImport(Speech) && !os(watchOS)
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

    private func requestSpeechAuthorization(_ completion: @escaping @MainActor (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func startRecognition() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            statusText = "Dictation is not available right now."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            statusText = "Listening"
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            statusText = "Could not start dictation."
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.applyTranscript(result.bestTranscription.formattedString)
                    if result.isFinal {
                        self.finishRecognition()
                    }
                }
                if error != nil {
                    self.finishRecognition(status: "Dictation stopped.")
                }
            }
        }
    }

    private func applyTranscript(_ spokenText: String) {
        let transcript = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }
        let combined = baseText.isEmpty ? transcript : "\(baseText) \(transcript)"
        onTranscriptChange?(combined)
    }

    private func finishRecognition(status: String = HiveSpeechInputController.readyStatus) {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        statusText = status
    }
    #endif
}

public struct HiveSpeechInputButton: View {
    @ObservedObject private var speechInput: HiveSpeechInputController
    @Binding private var text: String
    public var compact: Bool
    public var onStartRecording: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    public init(
        speechInput: HiveSpeechInputController,
        text: Binding<String>,
        compact: Bool = true,
        onStartRecording: (() -> Void)? = nil
    ) {
        self.speechInput = speechInput
        self._text = text
        self.compact = compact
        self.onStartRecording = onStartRecording
    }

    public var body: some View {
        Button {
            if !speechInput.isRecording {
                onStartRecording?()
            }
            speechInput.toggle(appendingTo: text) { updated in
                text = updated
            }
        } label: {
            HiveLiquidGlassSurface(placement: .button) {
                ZStack {
                    RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous)
                        .fill(micFill)
                    HiveSymbol(
                        .voiceNote,
                        size: compact ? 16 : 18,
                        active: speechInput.isRecording || isHovered,
                        rendering: speechInput.isRecording ? .primaryAction : .hierarchical,
                        motion: speechInput.isRecording || isHovered ? .pulse : .none,
                        motionValue: speechInput.isRecording ? 1 : 0,
                        accessibilityLabel: accessibilityLabel
                    )
                }
                .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
                .padding(compact ? 6 : 8)
                .frame(
                    minWidth: HiveHIGPolicy.targetSize(compact: compact),
                    minHeight: HiveHIGPolicy.targetSize(compact: compact)
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: HiveGlassPlacement.button.cornerRadius, style: .continuous)
                    .stroke(
                        micBorder,
                        lineWidth: 1
                    )
            )
            .shadow(color: micShadow, radius: isHovered || speechInput.isRecording ? 10 : 2, x: 0, y: isHovered ? 4 : 1)
        }
        .buttonStyle(HiveControlPressStyle())
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.045 : 1))
        .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
        .help(speechInput.isSupported ? accessibilityLabel : "Use keyboard dictation")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(speechInput.statusText)
        .accessibilityHint("Uses Apple speech recognition to fill this text field.")
        .modifier(HiveSpeechInputHoverModifier(isHovered: $isHovered, reduceMotion: reduceMotion))
    }

    private var accessibilityLabel: String {
        speechInput.isRecording ? "Stop dictation" : "Dictate"
    }

    private var micFill: Color {
        if speechInput.isRecording {
            return HiveColorToken.waxAmber.color.opacity(isHovered ? 0.36 : 0.28)
        }
        return isHovered ? HiveColorToken.waxAmber.color.opacity(0.14) : HiveColorToken.backgroundMid.color.opacity(0.64)
    }

    private var micBorder: Color {
        if speechInput.isRecording {
            return HiveColorToken.waxAmber.color.opacity(0.7)
        }
        return isHovered ? HiveColorToken.waxAmber.color.opacity(0.5) : HiveColorToken.scaffoldFaint.color.opacity(0.22)
    }

    private var micShadow: Color {
        if speechInput.isRecording {
            return HiveColorToken.waxAmber.color.opacity(0.22)
        }
        return HiveColorToken.waxAmber.color.opacity(isHovered ? 0.14 : 0.02)
    }
}

private struct HiveSpeechInputHoverModifier: ViewModifier {
    @Binding var isHovered: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        #if os(watchOS)
        content
        #else
        content.onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.hoverLift) { isHovered = hovering }
        }
        #endif
    }
}

@MainActor
public final class HiveSpeechOutputController: NSObject, ObservableObject {
    @Published public private(set) var isSpeaking = false

    #if canImport(AVFoundation) && !os(watchOS)
    private static let sharedSynthesizer = AVSpeechSynthesizer()
    private let voiceManager = SwarmVoiceManager()
    private var streamingBuffer = ""
    private var queuedUtteranceCount = 0
    private var activeVoiceIdentifier: String?

    private var synthesizer: AVSpeechSynthesizer {
        Self.sharedSynthesizer
    }
    #endif

    public override init() {
        super.init()
        #if canImport(AVFoundation) && !os(watchOS)
        synthesizer.delegate = self
        #endif
    }

    public var isSupported: Bool {
        #if canImport(AVFoundation) && !os(watchOS)
        return true
        #else
        return false
        #endif
    }

    public func speak(_ text: String) {
        speakSwarmResponse(text: text, selectedVoiceIdentifier: SwarmVoiceSettingsStore.selectedVoiceIdentifier())
    }

    public func speakSwarmResponse(text: String, selectedVoiceIdentifier: String?) {
        #if canImport(AVFoundation) && !os(watchOS)
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        beginStreamingResponse(selectedVoiceIdentifier: selectedVoiceIdentifier)
        appendStreamingToken(cleaned)
        finishStreamingResponse()
        #endif
    }

    public func beginStreamingResponse(selectedVoiceIdentifier: String? = SwarmVoiceSettingsStore.selectedVoiceIdentifier()) {
        #if canImport(AVFoundation) && !os(watchOS)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        queuedUtteranceCount = 0
        streamingBuffer = ""
        activeVoiceIdentifier = selectedVoiceIdentifier
        #endif
    }

    public func appendStreamingToken(_ token: String) {
        #if canImport(AVFoundation) && !os(watchOS)
        streamingBuffer += token
        drainCompleteClauses()
        #endif
    }

    public func speakStreamingResponse<Tokens: AsyncSequence & Sendable>(
        selectedVoiceIdentifier: String? = SwarmVoiceSettingsStore.selectedVoiceIdentifier(),
        tokens: Tokens
    ) async where Tokens.Element == String, Tokens.AsyncIterator: Sendable {
        beginStreamingResponse(selectedVoiceIdentifier: selectedVoiceIdentifier)
        do {
            for try await token in tokens {
                appendStreamingToken(token)
            }
        } catch {
            #if canImport(AVFoundation) && !os(watchOS)
            streamingBuffer = ""
            #endif
        }
        finishStreamingResponse()
    }

    public func finishStreamingResponse() {
        #if canImport(AVFoundation) && !os(watchOS)
        queueUtterance(streamingBuffer)
        streamingBuffer = ""
        #endif
    }

    public func interruptForUserSpeech() {
        #if canImport(AVFoundation) && !os(watchOS)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        streamingBuffer = ""
        queuedUtteranceCount = 0
        #endif
        isSpeaking = false
    }

    public func stop() {
        #if canImport(AVFoundation) && !os(watchOS)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        #endif
        isSpeaking = false
    }

    #if canImport(AVFoundation) && !os(watchOS)
    private func drainCompleteClauses() {
        while let endIndex = firstClauseEndIndex(in: streamingBuffer) {
            let clause = String(streamingBuffer[..<endIndex])
            streamingBuffer.removeSubrange(..<endIndex)
            queueUtterance(clause)
        }
    }

    private func firstClauseEndIndex(in text: String) -> String.Index? {
        let hardDelimiters: Set<Character> = [".", "?", "!", ";", "\n"]
        let softDelimiters: Set<Character> = [","]
        for index in text.indices {
            let character = text[index]
            guard hardDelimiters.contains(character) || softDelimiters.contains(character) else { continue }
            let end = text.index(after: index)
            let count = text.distance(from: text.startIndex, to: end)
            if hardDelimiters.contains(character) || count >= 32 {
                return end
            }
        }

        guard text.count > 220 else { return nil }
        let preferredEnd = text.index(text.startIndex, offsetBy: 180)
        let searchRange = text.startIndex..<preferredEnd
        return text.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards, range: searchRange)?.upperBound
    }

    private func queueUtterance(_ rawText: String) {
        let cleaned = rawText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        if let targetVoice = voiceManager.voice(for: activeVoiceIdentifier ?? SwarmVoiceSettingsStore.selectedVoiceIdentifier()) {
            utterance.voice = targetVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        queuedUtteranceCount += 1
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    private func completeUtterance() {
        queuedUtteranceCount = max(0, queuedUtteranceCount - 1)
        isSpeaking = queuedUtteranceCount > 0 || synthesizer.isSpeaking
    }
    #endif
}

#if canImport(AVFoundation) && !os(watchOS)
extension HiveSpeechOutputController: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.completeUtterance()
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.completeUtterance()
        }
    }
}
#endif
