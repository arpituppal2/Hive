//
//  GeminiSidePanel+Input.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Input Area | - Heads Up (related memory) | - Context Before Send | - Tab Reference Pills
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Input

@MainActor
extension GeminiSidePanel {




    // MARK: - Input Area

    var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            headsUpStrip

            preSendContextDisclosure

            // Tab reference pills — Comet-style @tab attachment badges
            if !referencedTabIDs.isEmpty {
                tabReferencePills
            }

            // @tab autocomplete dropdown
            if showTabAutocomplete && !matchingTabs.isEmpty {
                tabAutocompleteDropdown
            }

            // Voice turn disclosure — makes clarification and confirmation
            // explicit instead of leaving the user to infer state from a chat
            // bubble or microphone indicator. It is presentation-only; the
            // existing gateway/coordinator remains the authority.
            voiceTurnDisclosure

            // Voice status readout — compact and explicit rather than a
            // decorative orb. The transcript remains visible while recording;
            // route/clarification state is shown after submission.
            if state.voiceCoordinator.state != .idle,
               state.voiceCoordinator.state != .completed,
               state.voiceCoordinator.state != .cancelled {
                HStack(spacing: 6) {
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red : Color.hiveAccent)
                        .frame(width: 5, height: 5)
                    Text(voiceStatusLabel)
                        .font(HiveDesign.Typography.monoMicroEmph)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("LOCAL AUDIO")
                        .font(HiveDesign.Typography.monoTiny)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(HiveDesign.Surface.level1)
            }

            // Transcribed speech preview — Comet-style voice dictation
            if speechRecognizer.isRecording && !speechRecognizer.transcribedText.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "waveform")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(Color.hiveAccent)
                        .symbolEffect(.variableColor, options: .repeating)
                    Text(speechRecognizer.transcribedText)
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level1)
            }

            HStack(spacing: 8) {
                // Voice input button — Comet's Shift+Alt+V voice mode
                if state.isVoiceModeActive {
                    Button(action: { toggleVoiceRecording() }) {
                        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(HiveDesign.Typography.sidebarItemBold)
                            .foregroundStyle(speechRecognizer.isRecording ? Color.red : .secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(speechRecognizer.isRecording ? Color.red.opacity(0.10) : Color.secondary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                            .help(speechRecognizer.isRecording ? "Stop recording and route voice command" : "Start local voice command")
                }

                TextField("Ask about this page...", text: $input)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.body)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
                    .onSubmit { send() }
                    .onChange(of: input) { _, _ in detectTabReferences() }

                if state.isGeminiGenerating {
                    Button(action: { state.stopGeminiGeneration() }) {
                        Image(systemName: "stop.fill")
                            .font(HiveDesign.Typography.sidebarItemBold)
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { send() }) {
                        Image(systemName: "arrow.up")
                            .font(HiveDesign.Typography.smallLabelBold)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(input.isEmpty ? Color.secondary.opacity(0.3) : Color.hiveAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(input.isEmpty && referencedTabIDs.isEmpty)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }


    // MARK: - Heads Up (related memory)

    /// A quiet strip above the composer showing what Hive already remembers
    /// about the current page: relevant user preferences and how many memory
    /// items are being tracked. It answers "what do you already know about
    /// this?" at the exact moment the user would ask — without sending any of
    /// it anywhere. Tapping opens the Knowledge panel.
    @ViewBuilder
    var headsUpStrip: some View {
        let hasPage = !state.isPrivateBrowsing && state.activePageContext?.url != nil
        if hasPage, !relatedPreferences.isEmpty || trackedMemoryCount > 0 {
            VStack(alignment: .leading, spacing: 6) {
                // The strip header is a real button: VoiceOver announces the
                // open-knowledge affordance, and the header never competes with
                // the preference chips below it.
                Button(action: { state.toggleKnowledgePanel() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(HiveDesign.Typography.microLabel)
                            .foregroundStyle(Color.hiveAccent.opacity(0.8))
                        Text("Related memory")
                            .font(HiveDesign.Typography.microLabelBold)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                        if trackedMemoryCount > 0 {
                            Text("\(trackedMemoryCount) related")
                                .font(HiveDesign.Typography.monoMicroMedium)
                                .foregroundStyle(.tertiary.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                            .foregroundStyle(.tertiary.opacity(0.4))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open knowledge panel")
                .accessibilityValue("\(trackedMemoryCount) related memory items")

                if !relatedPreferences.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(Array(relatedPreferences.prefix(3).enumerated()), id: \.offset) { _, pref in
                                Button(action: { state.toggleKnowledgePanel() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: HiveDesign.Typography.sizeXS))
                                        Text(pref.value)
                                            .font(HiveDesign.Typography.captionSemiBold)
                                        if let tail = pref.path.split(separator: ".").last {
                                            Text(String(tail))
                                                .font(HiveDesign.Typography.microLabelSecondary)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .foregroundStyle(Color.hiveAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(HiveDesign.Surface.level2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(pref.path)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(HiveDesign.Surface.level1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
            }
        }
    }


    /// Local read of Honeycomb + hot memory for the current page. Private
    /// browsing and non-web pages show nothing — the strip is never populated
    /// from private content. Each call supersedes the previous in-flight task,
    /// so rapid tab switches cannot produce a stale overwrite.
    func refreshHeadsUp() {
        headsUpGeneration &+= 1
        let generation = headsUpGeneration
        headsUpTask?.cancel()
        headsUpTask = Task { @MainActor in
            guard !state.isPrivateBrowsing,
                  let ctx = state.activePageContext,
                  let url = ctx.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                relatedPreferences = []
                trackedMemoryCount = 0
                return
            }
            let pageKey = url.absoluteString
            let title = ctx.title
            let query = [title, url.host].compactMap { $0 }.joined(separator: " ")
            let prefs = await PreferenceMemoryBridge.relevantPreferences(for: query, from: state.honeycomb)
            let scope = await state.hotMemory.currentContextScope()
            // Only publish if this task is still current AND the page has not
            // changed while the queries were in flight.
            guard generation == headsUpGeneration,
                  state.activePageContext?.url?.absoluteString == pageKey else { return }
            relatedPreferences = prefs
            // Honest count: memory entries that actually relate to this page
            // (its page node, or a stored label matching the page title) —
            // never the global hot set.
            let pageNodeID = "page-\(pageKey.hashValue)"
            trackedMemoryCount = scope.filter { entry in
                entry.id == pageNodeID ||
                entry.label.localizedCaseInsensitiveCompare(title) == .orderedSame
            }.count
        }
    }


    // MARK: - Context Before Send

    /// The final, compact scope disclosure before the user sends text or voice.
    /// It reads the browser's canonical scope rather than rebuilding permissions
    /// in the view. No page text, URLs, memory contents, or identifiers are
    /// rendered here.
    @ViewBuilder
    var preSendContextDisclosure: some View {
        let summary = ContextScopeSummary(
            scope: state.activeContextScope,
            explicitTabCount: referencedTabIDs.count,
            isPrivateBrowsing: state.isPrivateBrowsing
        )
        let attachmentSummary = state.tabAttachmentSummary(for: referencedTabIDs)

        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    isPreSendContextExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: summary.title == "Private browsing"
                          ? "lock.shield"
                          : "square.stack.3d.up")
                        .font(HiveDesign.Typography.captionSemiBold)
                        .foregroundStyle(summary.title == "Private browsing"
                                         ? HiveDesign.State.warning
                                         : Color.hiveAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("Before send")
                                .font(HiveDesign.Typography.microLabelBold)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                            Text(summary.title)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Text(summary.detail)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if summary.explicitTabCount > 0, !state.isPrivateBrowsing {
                        Text("\(summary.explicitTabCount) selected tab\(summary.explicitTabCount == 1 ? "" : "s")")
                            .font(HiveDesign.Typography.monoMicroMedium)
                            .foregroundStyle(Color.hiveAccent)
                    }

                    Image(systemName: isPreSendContextExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Context before send")
            .accessibilityValue("\(summary.title). \(summary.detail). \(summary.privacyDetail)")
            .accessibilityHint(isPreSendContextExpanded ? "Collapse context details" : "Expand context details")

            if isPreSendContextExpanded {
                Divider().opacity(0.45)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.rows) { row in
                        HStack(spacing: 7) {
                            Image(systemName: row.isIncluded ? "checkmark.circle.fill" : "minus.circle")
                                .font(HiveDesign.Typography.microLabel)
                                .foregroundStyle(row.isIncluded ? Color.hiveAccent : HiveDesign.Text.tertiary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.label)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(row.isIncluded ? .primary : .tertiary)
                                Text(row.detail)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: HiveDesign.Typography.sizeXS))
                            .foregroundStyle(.tertiary)
                        Text(summary.privacyDetail)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)

                    if !referencedTabIDs.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: state.isPrivateBrowsing
                                  ? "lock.shield"
                                  : attachmentSummary.warning == nil
                                    ? "checkmark.circle"
                                    : "exclamationmark.triangle")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(state.isPrivateBrowsing || attachmentSummary.warning != nil
                                                 ? HiveDesign.State.warning
                                                 : Color.hiveAccent)
                            Text(state.isPrivateBrowsing
                                 ? "Attachments unavailable"
                                 : attachmentSummary.detail)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }

                        if let warning = attachmentSummary.warning, !state.isPrivateBrowsing {
                            Text(warning)
                                .font(.system(size: 8, weight: .regular))
                                .foregroundStyle(HiveDesign.State.warning)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }


    // MARK: - Tab Reference Pills

    var tabReferencePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(referencedTabIDs), id: \.self) { tabID in
                    if let tab = state.tabs.first(where: { $0.id == tabID }) {
                        tabPill(tab)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }


    func tabPill(_ tab: BrowserState.Tab) -> some View {
        let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
        let displayTitle = title.count > 30 ? String(title.prefix(27)) + "..." : title
        return HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(HiveDesign.Typography.microLabelMedium)
            Text(displayTitle)
                .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                .lineLimit(1)
            Button(action: { removeTabReference(tab.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.hiveAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HiveDesign.Surface.level2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onTapGesture { state.selectTab(id: tab.id) }
    }
}
