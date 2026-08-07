import SwiftUI
import HiveCore

// MARK: - Skills
//
// Dia/Polar-style slash-commands. Each skill dispatches through the model
// runtime; on macOS 26+ with Apple FMF available, skills produce real AI
// output. When no real model is available, output is labelled honestly.

struct Skill: Identifiable, Hashable, Sendable {
    let id = UUID()
    let command: String
    let title: String
    let description: String
    let icon: String
    let colorHex: String

    var swiftUIColor: Color {
        Color(hex: colorHex) ?? Color.hiveAccent
    }
}

@MainActor
final class SkillRunner {

    static let allSkills: [Skill] = [
        Skill(command: "/outline", title: "Outline", description: "Structure the page into a hierarchical outline", icon: "list.bullet", colorHex: "#F5A623"),
        Skill(command: "/summarize", title: "Summarize", description: "Distill the page into key bullet points", icon: "text.alignleft", colorHex: "#22C55E"),
        Skill(command: "/cite", title: "Cite", description: "Generate APA / MLA / Chicago citations", icon: "quote.bubble", colorHex: "#0EA5E9"),
        Skill(command: "/flashcards", title: "Flashcards", description: "Turn page content into study cards", icon: "rectangle.stack", colorHex: "#EC4899"),
        Skill(command: "/job-fit", title: "Job Fit", description: "Compare a resume to a job description", icon: "briefcase.fill", colorHex: "#8B5CF6"),
        Skill(command: "/fact-check", title: "Fact Check", description: "Cross-reference claims with known sources", icon: "checkmark.shield.fill", colorHex: "#14B8A6"),
    ]

    static func skill(for input: String) -> Skill? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        guard !normalized.hasPrefix("//") else { return nil }

        return allSkills.first { skill in
            matches(normalized, command: skill.command.lowercased())
        }
    }

    /// A skill executes only when the command is complete and the next
    /// character is absent or whitespace. This prevents `/summarizex` from
    /// silently dispatching `/summarize` while allowing tabs/newlines as
    /// argument separators.
    private static func matches(_ input: String, command: String) -> Bool {
        guard input.hasPrefix(command) else { return false }
        let remainder = input.dropFirst(command.count)
        return remainder.isEmpty || remainder.first?.isWhitespace == true
    }

    /// Skills shown while the user is still typing a slash command. Partial
    /// command prefixes remain discoverable, but a non-delimited extension
    /// such as `/summarizex` is not presented as a valid skill.
    static func skills(matching input: String) -> [Skill] {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.hasPrefix("//") else { return [] }
        guard !normalized.isEmpty else { return allSkills }

        return allSkills.filter { skill in
            let command = skill.command.lowercased()
            return command.hasPrefix(normalized)
                || matches(normalized, command: command)
        }
    }

    static func run(_ input: String, in state: ChromiumBrowserState) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let skill = skill(for: trimmed) else { return }

        let url = state.activeModel?.url
        let title = state.activeModel?.title ?? "Current Page"
        let host = url?.host ?? "example.com"

        // All roles use .summarizer or .librarian — both in Apple FMF's allowed list.
        // On macOS 26+ with Apple FMF, these produce real on-device AI output.
        let role: ModelRole = switch skill.command {
        case "/outline", "/cite":   .librarian
        case "/summarize", "/flashcards", "/job-fit", "/fact-check": .summarizer
        default:                    .summarizer
        }

        // Remove the command by its known prefix length rather than a
        // case-sensitive string replacement; `/SUMMARIZE extra` should leave
        // only `extra` as the prompt.
        let userPrompt = String(trimmed.dropFirst(skill.command.count))
            .trimmingCharacters(in: .whitespaces)
        let system = "You are a \(skill.title.lowercased()) tool. Current page: \"\(title)\" (\(host)). Respond with clear, structured output."
        let request = GenerateRequest(role: role, system: system, user: userPrompt.isEmpty ? "Process the page titled \"\(title)\"" : userPrompt, maxTokens: 512)

        Task { @MainActor in
            let body: String
            let isReal: Bool
            do {
                let result = try await Dispatcher.shared.generate(request)
                body = result.text
                isReal = result.isRealInference
            } catch {
                body = "Error running \(skill.title): \(error.localizedDescription)"
                isReal = false
            }
            openResult(state: state, skill: skill, body: body, isReal: isReal)
        }
    }

    private static func openResult(state: ChromiumBrowserState, skill: Skill, body: String, isReal: Bool) {
        // Post result inline in the Gemini sidebar so users see it immediately.
        // Strip HTML tags but preserve paragraph breaks and bullets for readability.
        let cleanBody = body
            .replacingOccurrences(of: "</p>", with: "\n\n")
            .replacingOccurrences(of: "<br/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</li>", with: "\n")
            .replacingOccurrences(of: "<li>", with: "• ")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let prefix = isReal ? "" : "(Preview mode — on-device AI unavailable)\n\n"
        state.geminiMessages.append(GeminiMessage(role: .assistant, text: "═══ \(skill.title) ═══\n\n\(prefix)\(cleanBody)"))
        withAnimation(state.isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            state.isGeminiPanelOpen = true
        }

        // Also open the formatted HTML result in a new tab
        let html = resultHTML(title: "\(skill.title) — Hive Skill", accentHex: skill.colorHex, body: body, isReal: isReal)
        guard let data = html.data(using: .utf8) else { return }
        let base64 = data.base64EncodedString()
        guard let url = URL(string: "data:text/html;base64,\(base64)") else { return }
        state.newTab(url: url, activate: false)
    }

    // MARK: - HTML shell

    private static func resultHTML(title: String, accentHex: String, body: String, isReal: Bool) -> String {
        let previewBanner = isReal ? "" : """
            <div class="preview-badge">◈ PREVIEW — on-device AI unavailable</div>
            """

        let footnote = isReal ? "" : """
            <div class="footnote">
                On-device AI is not available on this Mac.
                Skills will produce real output when an AI provider is connected or macOS is updated.
            </div>
            """

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(title)</title>
            <style>
                :root {
                    --accent: \(accentHex);
                    --bg: #0f0f11;
                    --card: #1a1a1f;
                    --border: #2a2a30;
                    --text: #e8e8ed;
                    --muted: #888;
                }
                @media (prefers-color-scheme: light) {
                    :root { --bg: #f5f5f7; --card: #ffffff; --border: #dddde3; --text: #1d1d20; --muted: #777; }
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
                    margin: 0; padding: 48px; background: var(--bg); color: var(--text); line-height: 1.7;
                    max-width: 720px;
                }
                .preview-badge {
                    display: inline-block; font-size: 11px; font-weight: 600; text-transform: uppercase;
                    letter-spacing: 0.05em; color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, transparent);
                    padding: 3px 10px; border-radius: 6px; margin-bottom: 16px;
                }
                h1 { font-size: 26px; font-weight: 700; margin: 0 0 4px; color: var(--accent); }
                .meta { color: var(--muted); font-size: 13px; margin-bottom: 20px; word-break: break-all; }
                .card { background: var(--card); border-radius: 14px; padding: 20px 24px; margin-bottom: 14px; border: 1px solid var(--border); }
                .card h2 { font-size: 15px; font-weight: 600; margin: 0 0 8px; }
                ul, ol { padding-left: 20px; margin: 0; }
                li { margin-bottom: 8px; font-size: 14px; }
                code { background: var(--border); padding: 2px 7px; border-radius: 4px; font-size: 13px; }
                .warn { color: #d97706; }
                .footnote { margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); font-size: 12px; color: var(--muted); }
            </style>
        </head>
        <body>
            \(previewBanner)
            \(body)
            \(footnote)
        </body>
        </html>
        """
    }
}
