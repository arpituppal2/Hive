// ============================================================
// Morning Brief — Looking Ahead section.
// Loaded only when `cliaMorningBriefLookingAheadEnabled` is on
// (the file isn't copied into the artifact otherwise). Registers
// a renderer that `app.js` calls at the end of `renderBrief()`.
//
// Two-column card: an LLM-generated intro blurb from
// `looking_ahead_blurb` in the brief JSON (with a static fallback
// when the field is missing) on the left, and a "What do you want
// to see in tomorrow's brief?" textarea on the right. The textarea contents
// persist to localStorage on every input event so the next morning's
// brief can read them back and inject them as feedback. A brief
// "Saved." toast confirms after the user pauses typing.
// ============================================================

(function () {
    const STORAGE_KEY = "brief-looking-ahead";
    /// Milliseconds of input quiescence before the "Saved." toast appears.
    const TOAST_DEBOUNCE_MS = 700;
    /// How long the toast stays visible before fading out.
    const TOAST_VISIBLE_MS = 2200;
    /// Matches the CSS opacity/visibility transition on `.looking-ahead-toast`.
    const TOAST_FADE_MS = 280;

    /// Plain-text fallback blurb used when the agent didn't emit
    /// `looking_ahead_blurb` (older briefs, parse failures, etc.).
    /// Deliberately generic — no day name, no calendar specifics — so the
    /// fallback never asserts anything that turns out to be wrong about
    /// tomorrow. The spec.yaml example is what teaches the LLM the content
    /// shape; this is just a safe seat-filler.
    const FALLBACK_BLURB = "Looking ahead to your next brief.";

    function persistChoice(value) {
        if (value && value.length > 0) {
            localStorage.setItem(STORAGE_KEY, value);
        } else {
            localStorage.removeItem(STORAGE_KEY);
        }
    }

    function buildIntro(blurb) {
        const intro = document.createElement("div");
        intro.className = "looking-ahead-intro section-title-group";

        const title = document.createElement("h2");
        title.id = "lookingAheadTitle";
        title.className = "section-title looking-ahead-title";
        title.textContent = "Looking ahead";
        intro.appendChild(title);

        const lead = document.createElement("p");
        lead.className = "looking-ahead-lead";
        // Plain text — the agent emits `looking_ahead_blurb` as a single
        // string per the spec.yaml prompt. `textContent` keeps it safe even
        // if the model slips in markup; the previous in-prose meeting
        // tooltip is gone since the schema is now plain text.
        lead.textContent = blurb;
        intro.appendChild(lead);

        const toast = document.createElement("p");
        toast.id = "lookingAheadToast";
        toast.className = "looking-ahead-toast";
        toast.setAttribute("aria-live", "polite");
        toast.hidden = true;

        const check = document.createElement("span");
        check.className = "looking-ahead-toast__check";
        check.setAttribute("aria-hidden", "true");
        toast.appendChild(check);
        toast.append(" Saved. Dia will remember this tomorrow.");
        intro.appendChild(toast);

        return { intro, toast };
    }

    function buildStack(initialValue) {
        const stack = document.createElement("div");
        stack.className = "looking-ahead-stack";

        const prompt = document.createElement("p");
        prompt.id = "lookingAheadPrompt";
        prompt.className = "looking-ahead-prompt";
        prompt.textContent = "What do you want to see in tomorrow's brief?";
        stack.appendChild(prompt);

        const intent = document.createElement("div");
        intent.className = "looking-ahead-intent";

        const wrap = document.createElement("div");
        wrap.className = "looking-ahead-custom-wrap looking-ahead-intent-wrap";

        const textarea = document.createElement("textarea");
        textarea.id = "lookingAheadIntent";
        textarea.className = "looking-ahead-custom-input looking-ahead-intent-input";
        textarea.rows = 5;
        textarea.placeholder =
            "E.g. a recap of open PRs, prep for your 2pm, or what you missed in Slack…";
        textarea.autocomplete = "off";
        textarea.setAttribute("aria-labelledby", "lookingAheadPrompt");
        textarea.value = initialValue;

        wrap.appendChild(textarea);
        intent.appendChild(wrap);
        stack.appendChild(intent);

        return { stack, wrap, textarea };
    }

    function makeToastController(toast) {
        let fadeTimer = null;
        let hideTimer = null;

        function clearTimers() {
            if (fadeTimer) clearTimeout(fadeTimer);
            if (hideTimer) clearTimeout(hideTimer);
            fadeTimer = null;
            hideTimer = null;
        }

        return function show() {
            clearTimers();
            toast.hidden = false;
            // Force a reflow so the browser registers the `hidden -> visible`
            // transition starting state before we add the visible class.
            void toast.offsetWidth;
            toast.classList.add("looking-ahead-toast--visible");
            fadeTimer = setTimeout(() => {
                toast.classList.remove("looking-ahead-toast--visible");
                hideTimer = setTimeout(() => {
                    toast.hidden = true;
                }, TOAST_FADE_MS);
            }, TOAST_VISIBLE_MS);
        };
    }

    function syncMultilineState(wrap, textarea) {
        const isMultiline =
            textarea.value.includes("\n") ||
            textarea.scrollHeight > textarea.clientHeight + 1;
        wrap.classList.toggle("is-multiline", isMultiline);
    }

    window.renderLookingAhead = function renderLookingAhead(container, data) {
        if (!container) return;

        const stored = localStorage.getItem(STORAGE_KEY) || "";
        // `looking_ahead_blurb` is gated by `cliaMorningBriefLookingAheadEnabled`
        // on the prompt side, so older briefs (or any flag-off render path
        // that still loaded this script somehow) won't have the field. Fall
        // back to a static line rather than rendering an empty paragraph.
        const blurb =
            typeof data?.looking_ahead_blurb === "string" && data.looking_ahead_blurb.trim().length > 0
                ? data.looking_ahead_blurb
                : FALLBACK_BLURB;

        const section = document.createElement("section");
        section.className =
            "brief-section looking-ahead-section looking-ahead-section--simple";
        section.setAttribute("aria-labelledby", "lookingAheadTitle");

        const card = document.createElement("div");
        card.className = "looking-ahead-card";

        const { intro, toast } = buildIntro(blurb);
        const { stack, wrap, textarea } = buildStack(stored);

        card.appendChild(intro);
        card.appendChild(stack);
        section.appendChild(card);
        container.appendChild(section);

        const showToast = makeToastController(toast);
        let toastTimer = null;

        textarea.addEventListener("input", () => {
            persistChoice(textarea.value.trim());
            syncMultilineState(wrap, textarea);
            if (toastTimer) clearTimeout(toastTimer);
            toastTimer = setTimeout(() => {
                if (textarea.value.trim().length > 0) showToast();
            }, TOAST_DEBOUNCE_MS);
        });

        syncMultilineState(wrap, textarea);
    };
})();
