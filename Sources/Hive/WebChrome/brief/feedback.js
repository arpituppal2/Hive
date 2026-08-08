// ============================================================
// Morning Brief — in-brief quality feedback layer.
// Loaded only when `contextBuilderMorningBriefFeedbackEnabled` is on (the file isn't
// copied into the artifact otherwise). Registers a renderer that `app.js`
// calls at the end of `init()`, after every section is in the DOM.
//
// The form is generic: it walks `[data-fb-section-id]` sections and every
// `[data-fb-uid]` (rate-able item) within them (stamped by app.js), injects two quick taps
// per item — "is everything fully correct?" and "did you care?" — plus a "what's wrong?" note
// revealed on an incorrect mark, a per-section "did we miss anything?" question,
// and one Submit action.
//
// Submit groups the three quality signals — utility (per item), correctness
// (per item), coverage (per section) — into positive+rated count pairs per section, where the
// rated count is the denominator so Segment can report each as a percentage
// without losing sample size. It hands them to Swift in a
// `dia-artifact-interaction://ucb-mb-feedback?…` navigation (intercepted by
// ArtifactWebContentController), which fires one `ucb_morning_brief_feedback_submitted`
// Segment event per section — all sharing the brief id, so they roll back up to a brief-level
// total. The note rides the URL rather than a shared `window` queue because page scripts and
// the native-injected drain run in separate JS worlds. The full per-item payload
// (`assemblePayload`) remains the stable contract for a future depot sink; the
// justified corrections/omissions plus note-free confirmations (positive marks) also ride
// this navigation as a base64 `detail` param (`assembleEvalIntake`), which Swift routes into
// the Context Builder eval queue.
// ============================================================

(function () {
    "use strict";

    const SCHEMA_VERSION = 2;
    const PRIMARY_FEEDBACK_SECTION_ID = "todos";

    // Utility ("did you care?") is deliberately the lowest-friction input we can
    // get away with: one binary tap, distinct from correctness. Centralized here
    // so swapping to a small numeric scale later only touches this object and
    // `buildUtilityControl` — never payload assembly, which always reads
    // `entry.useful`.
    const UTILITY_INPUT = {
        mode: "binary",
        options: [
            { value: true, label: "Worth showing", glyph: "👍", aria: "Worth showing" },
            { value: false, label: "Not worth showing", glyph: "👎", aria: "Not worth showing" },
        ],
    };

    const CORRECTNESS_OPTIONS = [
        { value: true, label: "Fully correct", glyph: "✓", aria: "Mark fully correct" },
        { value: false, label: "Not fully correct", glyph: "✗", aria: "Mark not fully correct" },
    ];

    const COMPLETENESS_OPTIONS = [
        { value: true, label: "Looks complete", aria: "This section looks complete" },
        { value: false, label: "Something's missing", aria: "Something is missing from this section" },
    ];

    // Lanes whose completeness prompts render adjacently name themselves; others fall
    // back to the generic ask in buildCompletenessControl.
    const COMPLETENESS_QUESTIONS = {
        task_suggestions: "Did we miss any tasks?",
    };

    // ── DOM helpers ─────────────────────────────────────────

    function el(tag, className) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        return node;
    }

    function numOr0(value) {
        return typeof value === "number" && Number.isFinite(value) ? value : 0;
    }

    function clearRequiredNoteError(note) {
        note.classList.remove("is-invalid");
        note.removeAttribute("aria-invalid");
    }

    // ── Toggle group ────────────────────────────────────────
    //
    // A small set of mutually exclusive buttons. Clicking the pressed button
    // again clears the selection back to `null` (unrated), so the payload can
    // distinguish "not rated" from "rated false". `aria-pressed` carries the
    // selected state for assistive tech and for the visible styling.

    function buildToggleGroup({ className, ariaLabel, options, showText, onChange }) {
        const group = el("span", "fb-toggle-group" + (className ? " " + className : ""));
        group.setAttribute("role", "group");
        group.setAttribute("aria-label", ariaLabel);

        const buttons = [];
        options.forEach((opt) => {
            const btn = el("button", "fb-toggle");
            btn.type = "button";
            btn.dataset.value = String(opt.value);
            btn.setAttribute("aria-pressed", "false");
            btn.setAttribute("aria-label", opt.aria || opt.label);
            if (!showText) btn.title = opt.label;

            if (opt.glyph) {
                const glyph = el("span", "fb-toggle-glyph");
                glyph.setAttribute("aria-hidden", "true");
                glyph.textContent = opt.glyph;
                btn.appendChild(glyph);
            }
            if (showText) {
                const text = el("span", "fb-toggle-text");
                text.textContent = opt.label;
                btn.appendChild(text);
            }

            btn.addEventListener("click", () => {
                const wasPressed = btn.getAttribute("aria-pressed") === "true";
                const next = wasPressed ? null : opt.value;
                buttons.forEach((b) => b.setAttribute("aria-pressed", "false"));
                if (!wasPressed) btn.setAttribute("aria-pressed", "true");
                onChange(next);
            });

            buttons.push(btn);
            group.appendChild(btn);
        });

        return group;
    }

    function labelledControl(text, controlEl) {
        const wrap = el("span", "fb-control");
        const label = el("span", "fb-control-label");
        label.textContent = text;
        wrap.appendChild(label);
        wrap.appendChild(controlEl);
        return wrap;
    }

    function buildUtilityControl(entry, onActivity) {
        // Only the binary mode is live; the config drives both render and read.
        return buildToggleGroup({
            className: "fb-useful",
            ariaLabel: "Did you care that we showed you this?",
            options: UTILITY_INPUT.options,
            onChange: (value) => {
                entry.useful = value;
                onActivity();
            },
        });
    }

    // ── Per-item controls ───────────────────────────────────

    function buildItemControls(entry, onActivity) {
        const controls = el("span", "fb-item-controls");
        controls.setAttribute("aria-label", "Rate this item");

        // Justification for an incorrect mark, revealed only on ✗ (mirrors the per-section
        // "what's missing?" note).
        const note = el("textarea", "fb-correct-note");
        note.rows = 2;
        note.placeholder = "What's wrong?";
        note.autocomplete = "off";
        note.required = true;
        note.setAttribute("aria-label", "What's wrong?");
        note.setAttribute("aria-required", "true");
        note.hidden = true;
        entry.correctnessNoteField = note;
        note.addEventListener("input", () => {
            entry.correctnessNote = note.value.trim() || null;
            if (entry.correctnessNote) clearRequiredNoteError(note);
            onActivity();
        });

        controls.appendChild(
            labelledControl(
                "Fully correct?",
                buildToggleGroup({
                    className: "fb-correct",
                    ariaLabel: "Is everything in this item fully correct?",
                    options: CORRECTNESS_OPTIONS,
                    onChange: (value) => {
                        entry.correct = value;
                        // The note only makes sense for an incorrect mark; cleared if flipped back.
                        note.hidden = value !== false;
                        if (value !== false) {
                            note.value = "";
                            entry.correctnessNote = null;
                            clearRequiredNoteError(note);
                        }
                        onActivity();
                    },
                }),
            ),
        );

        controls.appendChild(labelledControl("Useful?", buildUtilityControl(entry, onActivity)));

        controls.appendChild(note);
        return controls;
    }

    // ── Per-section completeness ────────────────────────────

    function buildCompletenessControl(completeness, onActivity, questionText) {
        const wrap = el("div", "fb-completeness");

        const question = el("p", "fb-completeness-q");
        question.textContent = questionText || "Did we miss anything?";
        wrap.appendChild(question);

        const note = el("textarea", "fb-missing-note");
        note.rows = 2;
        note.placeholder = "What's missing?";
        note.autocomplete = "off";
        note.required = true;
        note.setAttribute("aria-label", "What's missing?");
        note.setAttribute("aria-required", "true");
        note.hidden = true;
        completeness.missingNoteField = note;
        note.addEventListener("input", () => {
            completeness.missingNote = note.value.trim() || null;
            if (completeness.missingNote) clearRequiredNoteError(note);
            onActivity();
        });

        const group = buildToggleGroup({
            className: "fb-complete",
            ariaLabel: "Section completeness",
            options: COMPLETENESS_OPTIONS,
            showText: true,
            onChange: (value) => {
                completeness.complete = value;
                // The note only makes sense when something is missing and is cleared if the user flips back.
                note.hidden = value !== false;
                if (value !== false) {
                    note.value = "";
                    completeness.missingNote = null;
                    clearRequiredNoteError(note);
                }
                onActivity();
            },
        });

        wrap.appendChild(group);
        wrap.appendChild(note);
        return wrap;
    }

    // ── Submit (fixed pill, revealed once anything is rated) ────

    // Counts the signals the user has given, so the pill only appears after a
    // real interaction and can show how much is queued.
    function countFeedback(model) {
        let n = 0;
        model.sections.forEach((section) => {
            if (section.completeness.complete !== null || section.completeness.missingNote) n += 1;
            section.items.forEach((item) => {
                if (item.correct !== null || item.useful !== null) n += 1;
            });
        });
        return n;
    }

    function missingRequiredNoteFields(model) {
        const fields = [];
        model.sections.forEach((section) => {
            section.items.forEach((item) => {
                if (item.correct === false && !item.correctnessNote) fields.push(item.correctnessNoteField);
            });
            if (section.completeness.complete === false && !section.completeness.missingNote) {
                fields.push(section.completeness.missingNoteField);
            }
        });
        return fields;
    }

    function validateRequiredNotes(model) {
        const fields = missingRequiredNoteFields(model);
        fields.forEach((field) => {
            field.classList.add("is-invalid");
            field.setAttribute("aria-invalid", "true");
        });
        const first = fields[0];
        if (!first) return true;
        first.focus({ preventScroll: true });
        first.scrollIntoView({ behavior: "smooth", block: "center" });
        return false;
    }

    function showGradingCelebration() {
        const celebration = el("div", "fb-celebration");
        celebration.setAttribute("role", "status");
        celebration.setAttribute("aria-live", "polite");

        const confettiField = el("div", "fb-celebration__confetti-field");
        confettiField.setAttribute("aria-hidden", "true");
        const colors = ["#ffe500", "#ff5c5c", "#4f7cff", "#2fb66d", "#ffffff"];
        for (let index = 0; index < 28; index += 1) {
            const confetti = el("span", "fb-celebration__confetti" + (index % 4 === 0 ? " is-round" : ""));
            const angle = (index / 28) * Math.PI * 2;
            const distance = 150 + (index % 5) * 24;
            confetti.style.setProperty("--fb-x", Math.cos(angle) * distance + "px");
            confetti.style.setProperty("--fb-y", Math.sin(angle) * distance + "px");
            confetti.style.setProperty("--fb-r", 180 + (index % 7) * 55 + "deg");
            confetti.style.setProperty("--fb-delay", (index % 6) * 0.035 + "s");
            confetti.style.setProperty("--fb-color", colors[index % colors.length]);
            confettiField.appendChild(confetti);
        }

        const card = el("div", "fb-celebration__card");
        const mark = el("span", "fb-celebration__mark");
        mark.setAttribute("aria-hidden", "true");
        mark.textContent = "✦";
        const eyebrow = el("p", "fb-celebration__eyebrow");
        eyebrow.textContent = "Grade received";
        const title = el("p", "fb-celebration__title");
        title.textContent = "Thank you for grading!";
        const message = el("p", "fb-celebration__message");
        message.textContent = "You just made tomorrow's brief a little sharper.";
        card.append(mark, eyebrow, title, message);
        celebration.append(confettiField, card);
        document.body.appendChild(celebration);
        setTimeout(() => celebration.remove(), 3200);
    }

    function createFixedSubmit(model, data) {
        const button = el("button", "fb-submit-fixed");
        button.type = "button";
        button.setAttribute("aria-hidden", "true");

        const label = el("span", "fb-submit-fixed__label");
        label.textContent = "Submit feedback";
        const count = el("span", "fb-submit-fixed__count");
        count.setAttribute("aria-hidden", "true");
        button.append(label, count);

        let done = false;
        button.addEventListener("click", () => {
            if (done) return;
            if (!validateRequiredNotes(model)) return;
            done = true;
            submitToSegment(model, data);
            showGradingCelebration();
            button.classList.add("is-done");
            label.textContent = "Thank you! ✦";
            count.textContent = "";
            setTimeout(() => button.classList.remove("is-visible"), 2400);
        });

        return {
            el: button,
            sync() {
                if (done) return;
                const n = countFeedback(model);
                button.classList.toggle("is-visible", n > 0);
                button.setAttribute("aria-hidden", n > 0 ? "false" : "true");
                count.textContent = n > 0 ? String(n) : "";
            },
        };
    }

    // ── Payload assembly ────────────────────────────────────

    function mergeTokens(target, byModel) {
        if (!byModel || typeof byModel !== "object") return;
        Object.keys(byModel).forEach((family) => {
            const usage = byModel[family] || {};
            const totals = target[family] || {
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
            };
            totals.inputTokens += numOr0(usage.input_tokens);
            totals.outputTokens += numOr0(usage.output_tokens);
            totals.cacheCreationTokens += numOr0(usage.cache_create);
            totals.cacheReadTokens += numOr0(usage.cache_read);
            target[family] = totals;
        });
    }

    // Maps the brief JSON's snake_case `production` block to the camelCase payload
    // contract. `tokensByModel` is the whole-pipeline total: the brief run plus the
    // upstream UCB sessions (folded in once the client passes them through).
    function buildProductionBlock(production) {
        const out = { latencyMs: null, tokensByModel: {} };
        if (!production || typeof production !== "object") return out;
        if (typeof production.latency_ms === "number") out.latencyMs = production.latency_ms;
        mergeTokens(out.tokensByModel, production.tokens_by_model);
        mergeTokens(out.tokensByModel, production.upstream_tokens_by_model);
        return out;
    }

    // One positive+rated count-pair row per rated section. `rated` is the denominator
    // (items/sections the user actually rated), so a 1/1 stays distinguishable from a 50/60
    // once expressed as a percentage. A section with nothing rated emits no row; summing a
    // submission's rows (joined on briefId) recovers the brief-level total.
    function aggregateMetricsBySection(model) {
        return model.sections
            .map((section) => {
                const agg = {
                    sectionId: section.sectionId,
                    utilityPositive: 0,
                    utilityRated: 0,
                    correctnessCorrect: 0,
                    correctnessRated: 0,
                    coverageComplete: 0,
                    coverageRated: 0,
                };
                if (section.completeness.complete !== null) {
                    agg.coverageRated += 1;
                    if (section.completeness.complete === true) agg.coverageComplete += 1;
                }
                section.items.forEach((item) => {
                    if (item.useful !== null) {
                        agg.utilityRated += 1;
                        if (item.useful === true) agg.utilityPositive += 1;
                    }
                    if (item.correct !== null) {
                        agg.correctnessRated += 1;
                        if (item.correct === true) agg.correctnessCorrect += 1;
                    }
                });
                return agg;
            })
            .filter((agg) => agg.utilityRated > 0 || agg.correctnessRated > 0 || agg.coverageRated > 0);
    }

    // Hand the per-section signals to Swift in the navigation URL itself. A shared `window` queue
    // can't be used: page scripts and the native-injected drain run in separate JS worlds and
    // don't share globals, so a queued event never round-trips. The sections ride as one JSON
    // param in a single navigation (repeated `window.location` assignments would clobber each
    // other); Swift fires one `ucb_morning_brief_feedback_submitted` event per section, all
    // sharing the same briefId so they roll back up.
    function submitToSegment(model, data) {
        const sections = aggregateMetricsBySection(model);
        if (sections.length === 0) return;
        const params = new URLSearchParams({ sections: JSON.stringify(sections) });
        if (data.feedback_artifact_sha) params.set("briefId", data.feedback_artifact_sha);
        // The eval signals ride the same navigation as the metrics — a second `window.location`
        // assignment would clobber the first. Swift decodes `detail` into the Context Builder
        // eval-intake queue, consumed only when a runner exists.
        const intake = assembleEvalIntake(model, data);
        if (intake.corrections.length > 0 || intake.omissions.length > 0 || intake.confirmations.length > 0) {
            params.set("detail", utf8ToBase64(JSON.stringify(intake)));
        }
        window.location.href = "dia-artifact-interaction://ucb-mb-feedback?" + params.toString();
    }

    // Encode a JS string as base64 of its UTF-8 bytes; `btoa` alone mangles non-ASCII notes.
    function utf8ToBase64(str) {
        const bytes = new TextEncoder().encode(str);
        let binary = "";
        for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
        return btoa(binary);
    }

    // The eval-intake payload: the signals worth turning into Context Builder synthesis eval
    // cases. A per-item ✗ with a "what's wrong?" note is a correction (keyed by the item's UCB
    // block key); a per-section "something's missing" with a note is an omission (keyed by
    // section/lane). A per-item positive mark (✓ correct or 👍 worth showing) is a confirmation —
    // note-free and high-volume, the retention signal a cheaper distilled model must not regress.
    // Both quality bits ride along so triage can tell a hard retention target (correct + useful)
    // from a correct-but-unwanted op. An empty payload (no corrections, omissions, or
    // confirmations) means there is nothing to triage.
    function assembleEvalIntake(model, data) {
        const corrections = [];
        const omissions = [];
        const confirmations = [];
        model.sections.forEach((section) => {
            const missing = (section.completeness.missingNote || "").trim();
            if (section.completeness.complete === false && missing) {
                omissions.push({ sectionId: section.sectionId, note: missing });
            }
            section.items.forEach((item) => {
                // An incorrect item is a correction (note-gated) and never a confirmation, even
                // if also marked useful — wrong content can't be a retention target.
                if (item.correct === false) {
                    const note = (item.correctnessNote || "").trim();
                    // A keyless row has no op to anchor to — render it on the brief, but never export it.
                    if (note && item.blockKey) {
                        corrections.push({
                            blockKey: item.blockKey,
                            type: item.type,
                            displayedRank: item.displayedRank,
                            note: note,
                            text: item.text || null,
                        });
                    }
                    return;
                }
                // A positive mark (✓ correct or 👍 worth showing) is a confirmation. Carry both bits
                // raw — downstream weighs correct+useful (a must-generate target) against a
                // correct-but-unwanted op. `correct` is true|null here; `useful` is true|false|null.
                if ((item.correct === true || item.useful === true) && item.blockKey) {
                    confirmations.push({
                        blockKey: item.blockKey,
                        type: item.type,
                        displayedRank: item.displayedRank,
                        correct: item.correct,
                        useful: item.useful,
                        text: item.text || null,
                    });
                }
            });
        });
        return {
            schemaVersion: SCHEMA_VERSION,
            briefId: data.feedback_artifact_sha || null,
            generatedAt: (data.header && data.header.date_time) || null,
            corrections: corrections,
            omissions: omissions,
            confirmations: confirmations,
        };
    }

    function assemblePayload(model, data) {
        const header = data.header || {};
        return {
            schemaVersion: SCHEMA_VERSION,
            submittedAt: new Date().toISOString(),
            brief: {
                briefId: data.feedback_artifact_sha || null,
                userId: data.user_id || null,
                generatedAt: header.date_time || null,
            },
            production: buildProductionBlock(data.production),
            sections: model.sections.map((section) => ({
                sectionId: section.sectionId,
                completeness: {
                    complete: section.completeness.complete,
                    missingNote: section.completeness.missingNote,
                },
                // `correctnessNote` is intentionally absent: this depot block carries the
                // metric signals only; justified notes route solely through assembleEvalIntake.
                items: section.items.map((item) => ({
                    blockKey: item.blockKey,
                    type: item.type,
                    displayedRank: item.displayedRank,
                    correct: item.correct,
                    useful: item.useful,
                })),
            })),
        };
    }

    // ── Freeform feedback (Context Builder) ────
    //
    // A standalone bottom-left affordance, independent of the per-item quality
    // form: a freeform note is handed to Swift via a
    // `dia-artifact-interaction://ucb-feedback?text=…` navigation (intercepted by
    // ArtifactWebContentController), carrying the note as a query param. Swift routes
    // it into the Context Builder feedback lane, which always applies the change to the
    // live op log (the brief has no inspector to show a dry-run preview). The result
    // surfaces in the inspector's Feedback tab. No-ops unless the internal-tool flag is
    // on (no runner).

    function sendFeedback(text) {
        // Carry the note in the navigation URL itself rather than a shared `window` queue: page
        // scripts and the native-injected drain run in separate JS worlds, so a queued value never
        // round-trips. Swift reads the text straight off the intercepted navigation.
        window.location.href = "dia-artifact-interaction://ucb-feedback?text=" + encodeURIComponent(text);
    }

    function renderFeedbackPreviewButton() {
        if (document.querySelector(".fb-preview")) return;

        const root = el("div", "fb-preview");

        // Collapsed state: a single prompt button. Pressing it swaps the button out for the input
        // in place; sending (or pressing Enter) swaps back and leaves a confirmation line.
        const fab = el("button", "fb-preview-fab");
        fab.type = "button";
        fab.textContent = "Feedback?";

        const form = el("div", "fb-preview-form");
        form.hidden = true;

        const note = el("textarea", "fb-preview-note");
        note.rows = 3;
        note.placeholder = "Correct, update, or reframe the understanding of your context…";
        note.setAttribute("aria-label", "Feedback for the Context Builder");

        const send = el("button", "fb-preview-send");
        send.type = "button";
        send.textContent = "Send";

        const status = el("p", "fb-preview-status");
        status.setAttribute("aria-live", "polite");

        form.append(note, send);
        root.append(fab, form, status);

        // Collapse back to the FAB without sending. Listeners that only matter while the form
        // is open are bound on show and torn down here so a collapsed widget is inert.
        function collapseForm() {
            form.hidden = true;
            fab.hidden = false;
            document.removeEventListener("keydown", onDocKeydown, true);
            document.removeEventListener("pointerdown", onDocPointerDown, true);
        }

        function onDocKeydown(event) {
            if (event.key === "Escape") {
                event.preventDefault();
                collapseForm();
            }
        }

        function onDocPointerDown(event) {
            if (!root.contains(event.target)) collapseForm();
        }

        function showForm() {
            status.textContent = "";
            fab.hidden = true;
            form.hidden = false;
            note.focus();
            document.addEventListener("keydown", onDocKeydown, true);
            document.addEventListener("pointerdown", onDocPointerDown, true);
        }

        function submit() {
            const text = note.value.trim();
            if (!text) {
                note.focus();
                return;
            }
            sendFeedback(text);
            note.value = "";
            collapseForm();
            status.textContent = "Sent — open the Context Builder dashboard to see the changes.";
        }

        fab.addEventListener("click", showForm);
        send.addEventListener("click", submit);
        // Enter submits; Shift+Enter keeps the newline for multi-line notes.
        note.addEventListener("keydown", (event) => {
            if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                submit();
            }
        });

        document.body.appendChild(root);
    }

    // ── Render ──────────────────────────────────────────────

    function slotForUid(uid) {
        return uid ? document.querySelector('[data-fb-slot="' + uid + '"]') : null;
    }

    function markOptionalFeedbackSections(sectionEls) {
        const sections = Array.from(sectionEls);
        if (!sections.some(
            (sectionEl) => sectionEl.dataset.fbSectionId === PRIMARY_FEEDBACK_SECTION_ID,
        )) return;

        const optionalSections = sections.filter(
            (sectionEl) => sectionEl.dataset.fbSectionId !== PRIMARY_FEEDBACK_SECTION_ID,
        );
        if (!optionalSections.length) return;

        optionalSections.forEach((sectionEl) => {
            sectionEl.classList.add("fb-section--optional");
            const title = sectionEl.querySelector(".section-title");
            if (!title || title.querySelector(".fb-optional-badge")) return;
            const badge = el("span", "fb-optional-badge");
            badge.textContent = "Optional to grade";
            title.appendChild(badge);
        });

        const boundary = el("aside", "fb-optional-boundary");
        boundary.setAttribute("role", "note");
        const card = el("div", "fb-optional-boundary__card");
        const eyebrow = el("p", "fb-optional-boundary__eyebrow");
        eyebrow.textContent = "Optional from here on";
        const message = el("p", "fb-optional-boundary__message");
        message.textContent =
            "Top to-dos and For later are the focus. Everything below is optional to grade.";
        card.append(eyebrow, message);
        boundary.appendChild(card);
        optionalSections[0].insertAdjacentElement("beforebegin", boundary);
    }

    function renderBriefFeedback(data) {
        const sectionEls = document.querySelectorAll("[data-fb-section-id]");
        if (!sectionEls.length) return;

        markOptionalFeedbackSections(sectionEls);
        const model = { sections: [] };
        const submit = createFixedSubmit(model, data);
        const onActivity = () => submit.sync();
        // One section id can span multiple DOM blocks (to-dos render as "Top to-dos"
        // + "For later", both tagged "todos"). Merge them into a single model entry
        // per id, so the payload has one section per topic (no orphan entry with a
        // null completeness) and the "did we miss anything?" control renders once.
        const modelsById = new Map();
        // The completeness control anchors to each id's LAST DOM block, so for the
        // split to-dos it sits under "For later" — after the full list. Document
        // order means the last write per id wins.
        const lastElById = new Map();
        sectionEls.forEach((el) => lastElById.set(el.dataset.fbSectionId, el));

        sectionEls.forEach((sectionEl) => {
            const sectionId = sectionEl.dataset.fbSectionId;
            let sectionModel = modelsById.get(sectionId);
            const isNewModel = !sectionModel;
            if (isNewModel) {
                sectionModel = { sectionId, completeness: { complete: null, missingNote: null }, items: [] };
                modelsById.set(sectionId, sectionModel);
                model.sections.push(sectionModel);
            }

            sectionEl.querySelectorAll("[data-fb-uid]").forEach((itemEl) => {
                // The nearest tagged ancestor owns the item when a renderer nests sections.
                if (itemEl.closest("[data-fb-section-id]") !== sectionEl) return;
                const rank = Number(itemEl.dataset.fbRank);
                const entry = {
                    // Authoritative UCB op key; null for a keyless item, which assembleEvalIntake drops.
                    blockKey: itemEl.dataset.fbBlockKey || null,
                    type: itemEl.dataset.fbType,
                    displayedRank: Number.isFinite(rank) ? rank : null,
                    correct: null,
                    useful: null,
                    correctnessNote: null,
                    // Brief-rendered snapshot app.js stamps on `data-fb-text`: the anchor a
                    // confirmation carries so a verifier row needn't resolve the op from its key.
                    text: itemEl.dataset.fbText || null,
                };
                sectionModel.items.push(entry);
                const controls = buildItemControls(entry, onActivity);
                // app.js dropped a slot in the item's content column, paired by a
                // unique uid; fall back to a sibling if a brief predates slots.
                const slot = slotForUid(itemEl.dataset.fbUid);
                if (slot) slot.appendChild(controls);
                else itemEl.insertAdjacentElement("afterend", controls);
            });

            // Render the completeness control once per id, in its last DOM block.
            if (sectionEl === lastElById.get(sectionId)) {
                const body = sectionEl.querySelector(".section-body") || sectionEl;
                // Named sections can provide a more specific coverage question.
                body.appendChild(
                    buildCompletenessControl(
                        sectionModel.completeness,
                        onActivity,
                        COMPLETENESS_QUESTIONS[sectionId],
                    ),
                );
            }
        });

        document.body.appendChild(submit.el);
    }

    // Register on window in the browser; guarded so the module can also be
    // imported in Node/Bun (no `window`) to unit-test the pure functions below.
    if (typeof window !== "undefined") {
        window.renderBriefFeedback = renderBriefFeedback;
        // The freeform feedback button stands alone — it doesn't wait for app.js's
        // per-item render pass, so init it directly once the DOM is ready.
        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", renderFeedbackPreviewButton);
        } else {
            renderFeedbackPreviewButton();
        }
    }

    // Exposed so tests exercise the *shipped* payload logic, not a copy.
    if (typeof module !== "undefined" && module.exports) {
        module.exports = {
            buildProductionBlock,
            assemblePayload,
            aggregateMetricsBySection,
            assembleEvalIntake,
            missingRequiredNoteFields,
            SCHEMA_VERSION,
        };
    }
})();
