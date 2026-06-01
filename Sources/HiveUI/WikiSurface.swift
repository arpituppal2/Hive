import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer

public struct WikiSurface: View {
    public var pages: [WikiPageRecord]
    public var claims: [ClaimRecord]
    public var sources: [SourcePresentationModel]
    public var selectedPageID: String?
    public var selectedClaimID: String?
    public var onSelectPage: (String) -> Void
    public var onSelectClaim: (String) -> Void
    public var onCloseClaimInspector: () -> Void
    public var onClaimAction: (FeedbackAction, String) -> Void
    public var onSavePage: (String, String) -> Void
    public var onConsolidateArticles: ([String]) -> Void
    public var onDeleteArticles: ([String]) -> Void
    public var onOpenGraphNode: (_ pageID: String?, _ title: String?, _ claimID: String?) -> Void
    public var onAskWiki: (String) -> Void

    @State private var editDraft = ""
    @State private var originalEditDraft = ""
    @State private var editingPageID: String?
    @State private var selectedArticleIDs: Set<String> = []
    @State private var articleSearchText = ""
    @State private var pendingDeleteArticleIDs: Set<String> = []
    @State private var deleteConfirmationVisible = false
    @State private var answerDrafts: [String: String] = [:]
    @State private var autosaveWorkItem: DispatchWorkItem?
    @State private var autosaveStatus = "Correction draft"
    @AppStorage("hive.tip.wiki.dismissed") private var wikiTipDismissed = false

    public init(
        pages: [WikiPageRecord],
        claims: [ClaimRecord],
        sources: [SourcePresentationModel] = [],
        selectedPageID: String?,
        selectedClaimID: String?,
        onSelectPage: @escaping (String) -> Void,
        onSelectClaim: @escaping (String) -> Void,
        onCloseClaimInspector: @escaping () -> Void,
        onClaimAction: @escaping (FeedbackAction, String) -> Void,
        onSavePage: @escaping (String, String) -> Void,
        onConsolidateArticles: @escaping ([String]) -> Void = { _ in },
        onDeleteArticles: @escaping ([String]) -> Void = { _ in },
        onOpenGraphNode: @escaping (_ pageID: String?, _ title: String?, _ claimID: String?) -> Void = { _, _, _ in },
        onAskWiki: @escaping (String) -> Void = { _ in }
    ) {
        self.pages = pages
        self.claims = claims
        self.sources = sources
        self.selectedPageID = selectedPageID
        self.selectedClaimID = selectedClaimID
        self.onSelectPage = onSelectPage
        self.onSelectClaim = onSelectClaim
        self.onCloseClaimInspector = onCloseClaimInspector
        self.onClaimAction = onClaimAction
        self.onSavePage = onSavePage
        self.onConsolidateArticles = onConsolidateArticles
        self.onDeleteArticles = onDeleteArticles
        self.onOpenGraphNode = onOpenGraphNode
        self.onAskWiki = onAskWiki
    }

    public var body: some View {
        HiveMetalScene {
            HStack(alignment: .top, spacing: 16) {
                articleList
                    .frame(width: HiveLayoutMetrics.wikiListWidth)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                articleReadingPane
                if let claim = selectedClaim {
                    ClaimInspector(
                        claim: claim,
                        onClose: onCloseClaimInspector,
                        onAction: { onClaimAction($0, claim.id) },
                        onAsk: { question in
                            onAskWiki("For this Colony fact: \(question)")
                        }
                    )
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .alert(
            deleteConfirmationTitle,
            isPresented: deleteConfirmationBinding
        ) {
            Button(deleteConfirmationActionTitle, role: .destructive) {
                deletePendingArticles()
            }
            Button("Cancel", role: .cancel) {
                clearPendingDelete()
            }
        } message: {
            Text("This removes only the selected Colony article pages. Field sources stay untouched.")
        }
    }

    private var articleList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HiveSpacing.md) {
                VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                    Text("ARTICLES")
                        .font(HiveTypography.hiveCaption)
                        .tracking(0.3)
                        .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                    WikiArticleSearchField(text: $articleSearchText)
                }
                if !selectedArticleIDs.isEmpty {
                    colonySelectionToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                ForEach(visiblePages) { page in
                    WikiArticleListRow(
                        page: page,
                        selected: page.id == effectiveSelectedPageID,
                        markedForConsolidation: selectedArticleIDs.contains(page.id),
                        selectionEligible: page.isColonySelectionEligible,
                        selectionVisible: !selectedArticleIDs.isEmpty,
                        onOpen: {
                            commitCurrentEdit()
                            withAnimation(HiveMotion.panel) {
                                onSelectPage(page.id)
                            }
                        },
                        onToggle: {
                            toggleArticleSelection(page.id)
                        }
                    )
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(HiveColorToken.backgroundDeep.color.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius, style: .continuous))
        .onChange(of: visiblePages.map(\.id)) { _, ids in
            let eligibleIDs = Set(visiblePages.filter(\.isColonySelectionEligible).map(\.id))
            selectedArticleIDs = selectedArticleIDs.intersection(Set(ids)).intersection(eligibleIDs)
        }
    }

    private var articleListSubtitle: String {
        ""
    }

    private var colonySelectionToolbar: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(.select, size: 15, active: true)
            HiveText(selectionSummary, role: .scaffoldLabel)
                .lineLimit(1)
            Spacer(minLength: 0)
                Button {
                    commitCurrentEdit()
                    onConsolidateArticles(Array(selectedArticleIDs))
                    withAnimation(HiveMotion.standard) {
                        selectedArticleIDs.removeAll()
                    }
                } label: {
                    selectionButtonLabel("Merge", symbol: .merge)
                }
                .buttonStyle(HiveGlassButtonStyle(active: canConsolidateSelection, compact: true))
                .disabled(!canConsolidateSelection)
                .opacity(canConsolidateSelection ? 1 : 0.45)
                .accessibilityLabel("Consolidate articles")
                .help("Merges selected pages into the open selected article.")

                Button {
                    requestDeleteArticles(selectedArticleIDs)
                } label: {
                    selectionButtonLabel("Delete", symbol: .forget)
                }
                .buttonStyle(HiveGlassButtonStyle(destructive: true, compact: true))
                .disabled(selectedArticleIDs.isEmpty)
                .opacity(selectedArticleIDs.isEmpty ? 0.45 : 1)
                .help("Deletes selected Colony pages without deleting Field sources.")

                Button {
                    withAnimation(HiveMotion.standard) {
                        selectedArticleIDs.removeAll()
                    }
                } label: {
                    HiveSymbol(.close, size: 14)
                }
                .buttonStyle(HiveGlassButtonStyle(compact: true))
                .disabled(selectedArticleIDs.isEmpty)
                .opacity(selectedArticleIDs.isEmpty ? 0.45 : 1)
        }
        .padding(HiveSpacing.sm)
        .background(HiveColorToken.cellSurface.color.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .animation(HiveMotion.focus, value: selectedArticleIDs)
    }

    private func selectionButtonLabel(_ title: String, symbol: HiveSymbolName) -> some View {
        HStack(spacing: 6) {
            HiveSymbol(symbol, size: 13, active: true)
            Text(title)
        }
    }

    private var articleReadingPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let page = selectedPage {
                    VStack(alignment: .leading, spacing: 28) {
                        articleHeader(page)
                        editableArticle(page)
                        sourceFooter(page)
                    }
                    .padding(.horizontal, HiveReadableSurface.wikiArticle.horizontalPadding)
                    .padding(.vertical, HiveReadableSurface.wikiArticle.verticalPadding)
                    .frame(maxWidth: HiveReadableSurface.wikiArticle.maxWidth, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius, style: .continuous)
                            .fill(HiveColorToken.cellSurface.color.opacity(0.98))
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(UserWikiEditPolicy.isUserAuthored(page) ? HiveColorToken.waxAmber.color : HiveColorToken.scaffoldFaint.color)
                            .frame(width: 2)
                            .padding(.vertical, 18)
                    }
                    .id(page.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                if !openQuestionClaims.isEmpty {
                    openQuestions
                }
                if !conflictClaims.isEmpty {
                    contradictions
                }
                if !strongClaims.isEmpty {
                    claimSection("Strong Claims", claims: strongClaims, faint: false)
                }
                if !weakClaims.isEmpty {
                    claimSection("Weak Claims", claims: weakClaims, faint: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .animation(HiveMotion.panel, value: effectiveSelectedPageID)
        }
        .background(HiveColorToken.backgroundDeep.color.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func articleHeader(_ page: WikiPageRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HiveText(SourcePresentationModel.cleanTitle(page.title), role: .nectarTitle)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                HiveText(WikiPresentationModel(page: page, allPages: pages).updatedText, role: .scaffoldLabel)
                if UserWikiEditPolicy.isUserAuthored(page) {
                    HiveSymbolStatusMark(
                        .confirmed,
                        color: HiveColorToken.waxAmber.color.opacity(0.78),
                        size: 10,
                        label: "User correction"
                    )
                    HiveText("User correction", role: .scaffoldLabel)
                }
            }
            if !page.summary.isEmpty {
                HiveText(SourcePresentationModel.cleanTitle(page.summary), role: .nectarBody, lineSpacing: 7)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            HiveAskAboutBox(
                title: "Ask about this article",
                placeholder: "Ask for a simpler explanation or next step"
            ) { question in
                onAskWiki("For \(SourcePresentationModel.cleanTitle(page.title)): \(question)")
            }
            if editingPageID == page.id {
                HStack(spacing: HiveSpacing.sm) {
                    HiveActionButton("Save", symbol: .confirmed) {
                        saveCurrentEdit(closeAfterSave: true)
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    HiveActionButton("Cancel", symbol: .close) {
                        revertCurrentDraft()
                        withAnimation(HiveMotion.panel) {
                            editingPageID = nil
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack {
                Spacer()
                Menu {
                    if editingPageID == page.id {
                        Button {
                            saveCurrentEdit(closeAfterSave: false)
                        } label: {
                            WikiMenuLabel("Save correction", symbol: .confirmed)
                        }
                        Button {
                            revertCurrentDraft()
                            withAnimation(HiveMotion.panel) {
                                editingPageID = nil
                            }
                        } label: {
                            WikiMenuLabel("Cancel", symbol: .close)
                        }
                    } else {
                        Button {
                            withAnimation(HiveMotion.panel) {
                                beginEditing(page)
                            }
                        } label: {
                            WikiMenuLabel("Suggest correction", symbol: .edit)
                        }
                    }
                    Button {
                        onOpenGraphNode(page.id, page.title, nil)
                    } label: {
                        WikiMenuLabel("Show in The Hive", symbol: .showGraph)
                    }
                    Button {
                        toggleArticleSelection(page.id)
                    } label: {
                        WikiMenuLabel(selectedArticleIDs.contains(page.id) ? "Clear selection" : "Select page", symbol: .select)
                    }
                    Divider()
                    Button(role: .destructive) {
                        requestDeleteArticles([page.id])
                    } label: {
                        WikiMenuLabel("Delete article", symbol: .forget)
                    }
                } label: {
                    HiveSymbol(.ellipsis, size: 20, rendering: .monochrome(HiveColorToken.nectarMuted.color))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityLabel("Article actions")
            }
            if editingPageID == page.id {
                HStack(spacing: 8) {
                    HiveSymbolStatusMark(
                        .confirmed,
                        color: HiveColorToken.sealed.color,
                        size: 9,
                        label: autosaveStatus
                    )
                    HiveText(autosaveStatus, role: .scaffoldLabel)
                        .foregroundStyle(HiveColorToken.scaffoldGray.color)
                    if editDraft != originalEditDraft {
                        HiveText("Hive treats corrections as authoritative guidance.", role: .scaffoldBody)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func sourceFooter(_ page: WikiPageRecord) -> some View {
        let names = page.sourceRefs.compactMap { sourceName(for: $0) }
        if !names.isEmpty {
            HStack(spacing: HiveSpacing.xs) {
                HiveSymbol(.rawSourcesSheet, size: 12, rendering: .monochrome(HiveColorToken.scaffoldFaint.color))
                HiveText("Source: \(names.prefix(3).joined(separator: ", "))", role: .scaffoldLabel)
                    .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                    .lineLimit(1)
            }
            .padding(.top, HiveSpacing.sm)
        }
    }

    private func sourceName(for id: String) -> String? {
        sources.first { $0.sourceID == id }.map(\.title)
    }

    private func beginEditing(_ page: WikiPageRecord) {
        autosaveWorkItem?.cancel()
        editingPageID = page.id
        let editableBody = UserWikiEditPolicy
            .stripFrontmatter(page.markdown)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        editDraft = editableBody.isEmpty ? "# \(SourcePresentationModel.cleanTitle(page.title))\n\n" : editableBody
        originalEditDraft = editDraft
        autosaveStatus = "Correction draft"
    }

    private func saveCurrentEdit(closeAfterSave: Bool) {
        guard let editingPageID else { return }
        autosaveWorkItem?.cancel()
        onSavePage(editingPageID, editDraft)
        originalEditDraft = editDraft
        autosaveStatus = "Correction saved"
        if closeAfterSave {
            withAnimation(HiveMotion.panel) {
                self.editingPageID = nil
            }
        }
    }

    private func revertCurrentDraft() {
        autosaveWorkItem?.cancel()
        editDraft = originalEditDraft
        autosaveStatus = "Draft reverted"
    }

    private func commitCurrentEdit() {
        guard editingPageID != nil else { return }
        saveCurrentEdit(closeAfterSave: true)
    }

    private func toggleArticleSelection(_ pageID: String) {
        guard visiblePages.contains(where: { $0.id == pageID && $0.isColonySelectionEligible }) else { return }
        withAnimation(HiveMotion.focus) {
            if selectedArticleIDs.contains(pageID) {
                selectedArticleIDs.remove(pageID)
            } else {
                selectedArticleIDs.insert(pageID)
            }
        }
    }

    private func requestDeleteArticles(_ ids: Set<String>) {
        let visibleIDs = Set(visiblePages.filter(\.isColonySelectionEligible).map(\.id))
        let deletableIDs = ids.intersection(visibleIDs)
        guard !deletableIDs.isEmpty else { return }
        pendingDeleteArticleIDs = deletableIDs
        deleteConfirmationVisible = true
    }

    private func deletePendingArticles() {
        let ids = pendingDeleteArticleIDs
        guard !ids.isEmpty else {
            clearPendingDelete()
            return
        }
        commitCurrentEdit()
        onDeleteArticles(Array(ids))
        withAnimation(HiveMotion.panel) {
            selectedArticleIDs.subtract(ids)
            if let selectedPageID, ids.contains(selectedPageID) {
                selectedArticleIDs.remove(selectedPageID)
            }
            clearPendingDelete()
        }
    }

    private func clearPendingDelete() {
        pendingDeleteArticleIDs.removeAll()
        deleteConfirmationVisible = false
    }

    private var canConsolidateSelection: Bool {
        guard selectedArticleIDs.count >= 2, let effectiveSelectedPageID else { return false }
        return selectedArticleIDs.contains(effectiveSelectedPageID)
            && visiblePages.contains { $0.id == effectiveSelectedPageID && $0.isColonySelectionEligible }
    }

    private var selectedPagesForAction: [WikiPageRecord] {
        visiblePages.filter { selectedArticleIDs.contains($0.id) && $0.isColonySelectionEligible }
    }

    private var selectionSummary: String {
        if selectedArticleIDs.isEmpty {
            return ""
        }
        if canConsolidateSelection, let selectedPage {
            return "Merge into \(SourcePresentationModel.cleanTitle(selectedPage.title))"
        }
        return "\(selectedArticleIDs.count) selected"
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { deleteConfirmationVisible },
            set: { isPresented in
                deleteConfirmationVisible = isPresented
                if !isPresented {
                    pendingDeleteArticleIDs.removeAll()
                }
            }
        )
    }

    private var deleteConfirmationTitle: String {
        pendingDeleteArticleIDs.count == 1 ? "Delete this Colony article?" : "Delete \(pendingDeleteArticleIDs.count) Colony articles?"
    }

    private var deleteConfirmationActionTitle: String {
        pendingDeleteArticleIDs.count == 1 ? "Delete Article" : "Delete Articles"
    }

    @ViewBuilder
    private func editableArticle(_ page: WikiPageRecord) -> some View {
        if editingPageID == page.id {
            VStack(alignment: .leading, spacing: 12) {
                HiveText("Correction draft", role: .scaffoldLabel)
                TextEditor(text: $editDraft)
                    .font(HiveTypography.memoryEditor)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .scrollContentBackground(.hidden)
                    .padding(18)
                    .frame(minHeight: 420)
                    .background(HiveColorToken.cellSurface.color.opacity(0.98))
                    .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
                    .onChange(of: editDraft) { _, value in
                        scheduleAutosave(pageID: page.id, markdown: value)
                    }
                HiveText("Hive uses your correction to rewrite the maintained article and clean up contradictions.", role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
            }
            .transition(.scale(scale: 0.985).combined(with: .opacity))
        } else {
            HiveEtchingReveal(trigger: "\(page.id)-\(page.updatedAt.timeIntervalSinceReferenceDate)") {
                TypographicWikiArticle(
                    content: WikiPresentationModel(page: page, allPages: pages).body,
                    title: SourcePresentationModel.cleanTitle(page.title),
                    onOpenGraphNode: { onOpenGraphNode(nil, $0, nil) }
                )
            }
            .transition(.opacity)
        }
    }

    private func scheduleAutosave(pageID: String, markdown: String) {
        autosaveWorkItem?.cancel()
        autosaveStatus = "Saving correction"
        let item = DispatchWorkItem {
            onSavePage(pageID, markdown)
            originalEditDraft = markdown
            autosaveStatus = "Correction saved"
        }
        autosaveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: item)
    }

    @ViewBuilder
    private var openQuestions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HiveText("Open Questions", role: .scaffoldLabel)
            ForEach(openQuestionClaims) { claim in
                UnsealedCell(
                    claim: claim,
                    answer: Binding(
                        get: { answerDrafts[claim.id, default: ""] },
                        set: { answerDrafts[claim.id] = $0 }
                    ),
                    onSeal: {
                        answerDrafts[claim.id] = ""
                        onClaimAction(.approve, claim.id)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var contradictions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HiveText("Contradictions", role: .scaffoldLabel)
            ForEach(conflictClaims) { claim in
                ConflictCell(claim: claim) {
                    onClaimAction(.askLater, claim.id)
                }
                .onTapGesture {
                    onSelectClaim(claim.id)
                }
            }
        }
    }

    @ViewBuilder
    private func claimSection(_ title: String, claims: [ClaimRecord], faint: Bool) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text(title.uppercased())
                .font(HiveTypography.hiveCaption)
                .tracking(0.3)
                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
            ForEach(Array(claims.enumerated()), id: \.element.id) { index, claim in
                ClaimLine(
                    index: index + 1,
                    claim: claim,
                    faint: faint,
                    action: {
                        onSelectClaim(claim.id)
                    },
                    onOpenGraph: {
                        onOpenGraphNode(nil, nil, claim.id)
                    }
                )
            }
        }
    }

    private var visiblePages: [WikiPageRecord] {
        let visible = pages.filter(\.isVisibleInColony)
        let query = articleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return visible }
        return visible.filter { page in
            [
                SourcePresentationModel.cleanTitle(page.title),
                SourcePresentationModel.cleanTitle(page.summary),
                UserWikiEditPolicy.stripFrontmatter(page.markdown)
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    private var selectedPage: WikiPageRecord? {
        if let selectedPageID, let page = visiblePages.first(where: { $0.id == selectedPageID }) {
            return page
        }
        return visiblePages.first
    }

    private var effectiveSelectedPageID: String? {
        selectedPage?.id
    }

    private var selectedClaim: ClaimRecord? {
        selectedClaimID.flatMap { id in claims.first { $0.id == id } }
    }

    private var openQuestionClaims: [ClaimRecord] {
        visibleArticleClaims
            .filter { $0.status == .suspect || $0.confidence < 0.52 }
            .prefixArray(6)
    }

    private var conflictClaims: [ClaimRecord] {
        visibleArticleClaims
            .filter { $0.status == .contradicted || $0.contradictionGroupID != nil }
            .prefixArray(6)
    }

    private var strongClaims: [ClaimRecord] {
        visibleArticleClaims
            .filter { $0.status == .active && $0.confidence >= 0.72 }
            .prefixArray(14)
    }

    private var weakClaims: [ClaimRecord] {
        visibleArticleClaims
            .filter { $0.confidence < 0.72 && !$0.statement.isEmpty }
            .prefixArray(14)
    }

    private var visibleArticleClaims: [ClaimRecord] {
        guard let selectedPage else { return [] }
        let scopedIDs = Set(selectedPage.claimRefs)
        guard !scopedIDs.isEmpty else { return [] }
        return claims.filter { scopedIDs.contains($0.id) && $0.isUserVisibleWikiClaim }
    }
}

private struct WikiArticleSearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(.search, size: 14, active: focused, rendering: .monochrome(focused ? HiveColorToken.waxAmber.color : HiveColorToken.scaffoldFaint.color))
            TextField("Search articles", text: $text)
                .textFieldStyle(.plain)
                .font(HiveTypography.hiveBody)
                .foregroundStyle(HiveColorToken.nectarText.color)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    HiveSymbol(.close, size: 13, rendering: .monochrome(HiveColorToken.scaffoldFaint.color))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear article search")
            }
        }
        .padding(.horizontal, HiveSpacing.md)
        .frame(height: 36)
        .background(HiveColorToken.raisedSurface.color)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous))
    }
}

private struct WikiArticleListRow: View {
    var page: WikiPageRecord
    var selected: Bool
    var markedForConsolidation: Bool
    var selectionEligible: Bool
    var selectionVisible: Bool
    var onOpen: () -> Void
    var onToggle: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: HiveSpacing.sm) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HiveText(cleanTitle, role: selected ? .scaffoldAction : .scaffoldBody)
                            .lineLimit(1)
                            .help(cleanTitle)
                        if UserWikiEditPolicy.isUserAuthored(page) {
                            HiveSymbol(.edit, size: 12, rendering: .monochrome(HiveColorToken.waxAmber.color.opacity(0.66)))
                                .accessibilityLabel("User correction")
                        } else if !page.summary.isEmpty {
                            let cleanSummary = SourcePresentationModel.cleanTitle(page.summary)
                            HiveText(cleanSummary, role: .scaffoldBody)
                                .lineLimit(1)
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                                .help(cleanSummary)
                        } else {
                            HiveText("No summary yet", role: .scaffoldBody)
                                .lineLimit(1)
                                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, HiveSpacing.sm)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if selectionEligible && (selectionVisible || markedForConsolidation || hovering) {
                Button(action: onToggle) {
                    HiveSymbol(
                        markedForConsolidation ? .select : .unselected,
                        size: 16,
                        active: markedForConsolidation,
                        motion: markedForConsolidation ? .scale : .none,
                        motionValue: markedForConsolidation ? 1 : 0,
                        accessibilityLabel: markedForConsolidation ? "Selected for consolidation" : "Select for consolidation"
                    )
                    .padding(.horizontal, 8)
                    .frame(minHeight: HiveHIGPolicy.minimumMacControlTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(markedForConsolidation ? "Remove \(cleanTitle) from consolidation" : "Select \(cleanTitle) for consolidation")
            } else if !selectionEligible {
                HiveSymbol(.explain, size: 16, active: selected)
                    .frame(width: 38, height: HiveHIGPolicy.minimumMacControlTarget)
                    .accessibilityLabel("Open question")
            }
        }
        .padding(.horizontal, HiveSpacing.xs)
        .padding(.vertical, 2)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .onHover { hovering = $0 }
        .animation(HiveMotion.focus, value: hovering)
        .animation(HiveMotion.focus, value: selected)
        .animation(HiveMotion.focus, value: markedForConsolidation)
    }

    private var cleanTitle: String {
        SourcePresentationModel.cleanTitle(page.title)
    }

    private var rowBackground: Color {
        if selected {
            return HiveColorToken.waxAmber.color.opacity(0.12)
        }
        if markedForConsolidation {
            return HiveColorToken.waxAmber.color.opacity(0.12)
        }
        return hovering ? HiveColorToken.cellSurface.color.opacity(0.76) : Color.clear
    }
}

private struct TypographicWikiArticle: View {
    var content: String
    var title: String
    var onOpenGraphNode: (String) -> Void

    private var articleLines: [ArticleLine] {
        var seenContent = false
        return sanitizedContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                if !seenContent, line.caseInsensitiveCompare(title) == .orderedSame {
                    seenContent = true
                    return nil
                }
                seenContent = true
                return ArticleLine(text: line, kind: kind(for: line))
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xl) {
            ForEach(renderedBlocks) { block in
                switch block.kind {
                case .section:
                    Text(block.text)
                        .font(HiveTypography.hiveCaption)
                        .tracking(0.3)
                        .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                        .textSelection(.enabled)
                case .paragraph:
                    Text(block.text)
                        .font(HiveTypography.hiveBody)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .related:
                    EmptyView()
                }
            }
            let relatedLines = relatedPages
            if !relatedLines.isEmpty {
                VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                    Text("RELATED PAGES")
                        .font(HiveTypography.hiveCaption)
                        .tracking(0.3)
                        .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: HiveSpacing.sm) {
                            ForEach(relatedLines) { line in
                                Button {
                                    onOpenGraphNode(line.text)
                                } label: {
                                    Text(line.text)
                                        .font(HiveTypography.hiveCaption)
                                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                        .background(HiveColorToken.raisedSurface.color)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sanitizedContent: String {
        HiveDisplaySanitizer.sanitizedWikiContent(content, title: title)
    }

    private var renderedBlocks: [ArticleLine] {
        sanitizedContent
            .components(separatedBy: "\n\n")
            .flatMap { block -> [ArticleLine] in
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [] }
                let lines = trimmed.components(separatedBy: .newlines)
                if lines.count == 1 {
                    return [ArticleLine(text: trimmed, kind: kind(for: trimmed))]
                }
                return [ArticleLine(text: lines.joined(separator: "\n"), kind: .paragraph)]
            }
            .filter { $0.kind != .related }
    }

    private var relatedPages: [ArticleLine] {
        articleLines
            .filter { $0.kind == .related }
            .prefixArray(12)
    }

    private func kind(for line: String) -> ArticleLine.Kind {
        let sectionTitles = ["Claims", "Known Information", "Related Concepts", "Strong Claims", "Weak Claims", "Open Questions", "Contradictions"]
        if sectionTitles.contains(where: { $0.caseInsensitiveCompare(line) == .orderedSame }) {
            return .section
        }
        if line.count <= 44, !line.contains("."), !line.contains(","), !line.lowercased().hasPrefix("the user") {
            return .related
        }
        return .paragraph
    }
}

private struct ArticleLine: Identifiable {
    enum Kind {
        case section
        case paragraph
        case related
    }

    var text: String
    var kind: Kind
    var id: String { "\(kind)-\(text)" }
}

private struct UnsealedCell: View {
    var claim: ClaimRecord
    @Binding var answer: String
    var onSeal: () -> Void
    @State private var filled = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius)
                .fill(HiveColorToken.raisedSurface.color)
                .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.28), radius: 10, x: 0, y: 5)
            WaxPourFill(progress: filled ? 1 : 0)
                .opacity(filled ? 0.7 : 0)
            VStack(spacing: 10) {
                HiveText(SourcePresentationModel.cleanTitle(claim.statement), role: .nectarQuestion, lineSpacing: 8)
                    .multilineTextAlignment(.center)
                TextEditor(text: $answer)
                    .font(HiveTypography.memoryEditor)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .scrollContentBackground(.hidden)
                    .frame(height: 70)
                HiveActionButton("Seal", symbol: .confirmed) {
                    withAnimation(HiveMotion.waxFill) {
                        filled = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
                        onSeal()
                        filled = false
                    }
                }
            }
            .padding(34)
        }
        .frame(maxWidth: 580, minHeight: 240)
    }
}

private struct ConflictCell: View {
    var claim: ClaimRecord
    var onReconcile: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius)
                .fill(HiveColorToken.conflict.color.opacity(0.32))
                .offset(x: -10, y: 0)
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius)
                .fill(HiveColorToken.waxAmberDeep.color.opacity(0.42))
                .offset(x: 10, y: 0)
            VStack(spacing: 10) {
                HiveText(SourcePresentationModel.cleanTitle(claim.statement), role: .nectarBody, lineSpacing: 8)
                    .multilineTextAlignment(.center)
                HiveText("Why does this conflict? Hive has two pathways that do not settle into one cell.", role: .scaffoldBody)
                    .multilineTextAlignment(.center)
                HiveActionButton("Reconcile", symbol: .conflict, action: onReconcile)
            }
            .padding(28)
        }
        .frame(maxWidth: 560, minHeight: 210)
    }
}

private struct ClaimInspector: View {
    var claim: ClaimRecord
    var onClose: () -> Void
    var onAction: (FeedbackAction) -> Void
    var onAsk: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HiveText("Claim", role: .scaffoldLabel)
                Spacer()
                HiveSymbolButton(.close, title: nil, compact: true, action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            HiveText(SourcePresentationModel.cleanTitle(claim.statement), role: .nectarBody, lineSpacing: 8)
            HiveContextAskSurface(
                title: "Ask about this fact",
                placeholder: "Ask why this is here or what supports it"
            ) { question in
                onAsk(question)
            }
            HiveText(HiveStatusTranslator.confidencePhrase(claim.confidence, evidenceCount: claim.sourceRefs.count), role: .scaffoldBody)
            HiveText("Open the evidence trail to inspect the local excerpt behind this claim.", role: .nectarBody, lineSpacing: 6)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
            VStack(spacing: 10) {
                HiveActionButton("This is right", symbol: .confirmed) { onAction(.approve) }
                HiveActionButton("This is wrong", symbol: .conflict) { onAction(.deny) }
                HiveActionButton("Ask me later", symbol: .archive) { onAction(.askLater) }
                HiveActionButton("This was incidental", symbol: .markIncidental) { onAction(.incidental) }
                HoldWaxFillButton("Forget this") {
                    onAction(.delete)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(HiveColorToken.backgroundMid.color)
    }
}

private struct ClaimLine: View {
    var index: Int
    var claim: ClaimRecord
    var faint: Bool
    var action: () -> Void
    var onOpenGraph: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: HiveSpacing.md) {
                RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous)
                    .fill(HiveColorToken.waxAmber.color)
                    .frame(width: 2)
                Text("\(index).")
                    .font(HiveTypography.hiveBodyMed)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .frame(width: 24, alignment: .trailing)
                if let changeMarker {
                    Text(changeMarker.symbol)
                        .font(HiveTypography.hiveBodyMed)
                        .foregroundStyle(changeMarker.color)
                        .frame(width: 12, alignment: .center)
                        .accessibilityLabel(changeMarker.label)
                }
                Text(SourcePresentationModel.cleanTitle(claim.statement))
                    .font(HiveTypography.hiveBody)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .lineSpacing(4)
                    .opacity(faint ? 0.62 : 1)
                Spacer(minLength: 0)
                HiveSymbol(.inspect, size: 15, active: hovering, rendering: .monochrome(HiveColorToken.waxAmber.color.opacity(hovering ? 1 : 0.65)))
            }
            .padding(.vertical, HiveSpacing.sm)
            .padding(.horizontal, HiveSpacing.md)
            .background(hovering ? HiveColorToken.waxAmber.color.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(HiveMotion.focus, value: hovering)
        .contextMenu {
            Button {
                onOpenGraph()
            } label: {
                WikiMenuLabel("Show in The Hive", symbol: .showGraph)
            }
        }
    }

    private var changeMarker: (symbol: String, color: Color, label: String)? {
        let oneDay: TimeInterval = 24 * 60 * 60
        if Date().timeIntervalSince(claim.createdAt) <= oneDay {
            return ("+", HiveColorToken.waxAmber.color, "New claim")
        }
        switch claim.status {
        case .suspect, .userCorrected, .contradicted:
            return ("~", HiveColorToken.nectarMuted.color, "Updated claim")
        case .active, .retracted:
            return nil
        }
    }
}

private struct WikiMenuLabel: View {
    var title: String
    var symbol: HiveSymbolName

    init(_ title: String, symbol: HiveSymbolName) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(symbol, size: 14)
            Text(title)
        }
    }
}

public struct HiveActionButton: View {
    var title: String
    var symbol: HiveSymbolName
    var destructive: Bool
    var action: () -> Void
    @State private var hovering = false

    public init(_ title: String, symbol: HiveSymbolName, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.destructive = destructive
        self.action = action
    }

    public var body: some View {
        Group {
            if destructive {
                buttonCore
                    .buttonStyle(HiveGlassButtonStyle(active: hovering, destructive: true))
            } else {
                buttonCore
                    .buttonStyle(HiveGlassButtonStyle(active: hovering))
            }
        }
        .controlSize(.regular)
        .tint(destructive ? HiveColorToken.conflict.color : (hovering ? HiveColorToken.waxAmber.color : HiveColorToken.scaffoldGray.color))
        .accessibilityLabel(title)
        .accessibilityHint(HiveHIGPolicy.accessibilityHint(for: title))
        .onHover { hovering = $0 }
        .animation(HiveMotion.focus, value: hovering)
    }

    private var buttonCore: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(HiveTypography.chromeBodyEmphasized)
                    .lineLimit(1)
            } icon: {
                HiveSymbol(
                    symbol,
                    size: 17,
                    active: hovering,
                    motion: hovering ? .pulse : .none,
                    motionValue: hovering ? 1 : 0
                )
            }
            .frame(maxWidth: .infinity, minHeight: HiveHIGPolicy.minimumTouchControlTarget)
        }
    }
}

private extension Array {
    func prefixArray(_ count: Int) -> [Element] {
        Array(prefix(count))
    }
}
