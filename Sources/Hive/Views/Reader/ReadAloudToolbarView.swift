import SwiftUI
import AVFoundation

// MARK: - ReadAloudToolbarView
//
/// Floating toolbar for Reader Mode Read Aloud (SPEC §25.3).
/// Shows Play/Pause/Stop buttons, a speed slider (0.5x–2.0x), and sentence progress (3/47).
///
/// Takes a ReadAloudManager as parameter, enabling use directly within ReaderModeView
/// without needing @Environment injection on older SwiftUI versions.

struct ReadAloudToolbarView: View {

    let manager: ReadAloudManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: HiveSpacing.s12) {
            // Play / Pause / Stop controls
            playbackControls

            Divider()
                .frame(height: 20)
                .overlay(Color.hiveBorderSubtle)

            // Speed slider
            speedControl

            Divider()
                .frame(height: 20)
                .overlay(Color.hiveBorderSubtle)

            // Progress indicator
            progressLabel
        }
        .padding(.horizontal, HiveSpacing.s16)
        .padding(.vertical, HiveSpacing.s8)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: HiveRadius.r8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        .padding(.horizontal, HiveSpacing.s16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: HiveSpacing.s8) {
            // Skip backward (5 sentences)
            Button {
                manager.skip(-5)
            } label: {
                Image(systemName: "gobackward.5")
                    .font(HiveTypography.font(.panelTitle))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(ReadAloudControlButtonStyle(reduceMotion: reduceMotion))
            .help("Skip back 5 sentences")
            .disabled(!manager.isPlaying && !manager.isPaused)

            // Play / Pause
            Button {
                if manager.isPlaying {
                    manager.pause()
                } else if manager.isPaused {
                    manager.resume()
                } else {
                    manager.play()
                }
            } label: {
                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                    .font(HiveTypography.font(.sectionTitle))
                    .foregroundStyle(Color.hiveAccent)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ReadAloudControlButtonStyle(reduceMotion: reduceMotion))
            .help(manager.isPlaying ? "Pause" : "Play")

            // Stop
            Button {
                manager.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(HiveTypography.font(.panelTitle))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(ReadAloudControlButtonStyle(reduceMotion: reduceMotion))
            .help("Stop")
            .disabled(!manager.isPlaying && !manager.isPaused)

            // Skip forward (5 sentences)
            Button {
                manager.skip(5)
            } label: {
                Image(systemName: "goforward.5")
                    .font(HiveTypography.font(.panelTitle))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(ReadAloudControlButtonStyle(reduceMotion: reduceMotion))
            .help("Skip forward 5 sentences")
            .disabled(!manager.isPlaying && !manager.isPaused)
        }
    }

    // MARK: - Speed Control

    private var speedControl: some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "tortoise")
                .font(HiveTypography.font(.caption3))
                .foregroundStyle(.hiveGraphite)

            Slider(
                value: Binding(
                    get: { speedFactor(for: manager.speechRate) },
                    set: { manager.setRate(utteranceRate(for: $0)) }
                ),
                in: 0.5...2.0,
                step: 0.25
            )
            .controlSize(.small)
            .frame(width: 80)

            Image(systemName: "hare")
                .font(HiveTypography.font(.caption3))
                .foregroundStyle(.hiveGraphite)

            Text(speedLabel)
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)
                .frame(width: 32, alignment: .leading)
        }
    }

    /// Convert 0.5-2.0 speed factor to AVSpeechUtterance rate (0.1-1.0).
    private func utteranceRate(for speedFactor: Double) -> Float {
        // AVSpeechUtteranceDefaultSpeechRate ≈ 0.5 (maps to 1.0x)
        let normalized = (speedFactor - 0.5) / 1.5 // 0.5→0.0, 2.0→1.0
        return max(0.1, min(1.0, AVSpeechUtteranceDefaultSpeechRate + Float(normalized) * 0.4))
    }

    /// Convert AVSpeechUtterance rate back to 0.5-2.0 display factor.
    private func speedFactor(for rate: Float) -> Double {
        let normalized = (rate - AVSpeechUtteranceDefaultSpeechRate) / 0.4
        return Double(max(0.5, min(2.0, 1.0 + normalized)))
    }

    private var speedLabel: String {
        let factor = speedFactor(for: manager.speechRate)
        return String(format: "%.1fx", factor)
    }

    // MARK: - Progress

    private var progressLabel: some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: "text.badge.checkmark")
                .font(HiveTypography.font(.caption2))
                .foregroundStyle(.hiveGraphite)

            Text("\(manager.activeSegmentIndex + 1)/\(manager.segments.count)")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveGraphite)
                .monospacedDigit()
        }
    }
}

// MARK: - Control button style

/// Dense native control feedback for the reader toolbar. Pressed-state scale is
/// deliberately tiny; the toolbar should feel responsive without becoming playful.
private struct ReadAloudControlButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.62 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                reduceMotion ? .linear(duration: 0.08) : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#Preview {
    let manager = ReadAloudManager()
    manager.load(article: "This is a test article. It has multiple sentences. Read Aloud will highlight each one as it speaks.")
    return ReadAloudToolbarView(manager: manager)
        .padding()
        .frame(width: 500)
        .background(Color.hiveBackground)
}
