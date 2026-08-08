// ============================================================
// Morning Brief Template — app.js
// Renders all sections from JSON data in #brief-data by cloning
// HTML <template> elements. No manual DOM construction needed —
// designers can edit the templates directly in index.html.
// ============================================================

function getSourceFromUrl(url) {
    try {
        const host = new URL(url).hostname;
        if (host === "slack.com" || host.endsWith(".slack.com")) return { iconId: "slack-icon", name: "Slack" };
        if (host === "notion.com" || host.endsWith(".notion.com") || host === "notion.so" || host.endsWith(".notion.so")) return { iconId: "notion-icon", name: "Notion" };
        if (host === "confluence.com" || host.endsWith(".confluence.com") || host === "confluence.io" || host.endsWith(".confluence.io")) return { iconId: "confluence-icon", name: "Confluence" };
        if (host === "jira.com" || host.endsWith(".jira.com")) return { iconId: "jira-icon", name: "Jira" };
        if (host === "loom.com" || host.endsWith(".loom.com")) return { iconId: "loom-icon", name: "Loom" };
        if (host === "mail.google.com") return { iconId: "gmail-icon", name: "Gmail" };
        if (host === "calendar.google.com") return { iconId: "gcal-icon", name: "Google Calendar" };
        if (host === "drive.google.com" || host === "docs.google.com" || host === "sheets.google.com" || host === "slides.google.com" || host === "forms.google.com") return { iconId: "gdrive-icon", name: "Google Drive" };
        if (host === "linkedin.com" || host.endsWith(".linkedin.com")) return { iconId: "linkedin-icon", name: "LinkedIn" };
        if (host === "github.com" || host.endsWith(".github.com")) return { iconId: "github-icon", name: "GitHub" };
        if (host === "linear.app" || host.endsWith(".linear.app")) return { iconId: "linear-icon", name: "Linear" };
        if (host === "amplitude.com" || host.endsWith(".amplitude.com")) return { iconId: "amplitude-icon", name: "Amplitude" };
        const path = new URL(url).pathname;
        if ((host === "atlassian.net" || host.endsWith(".atlassian.net")) && path.startsWith("/wiki")) return { iconId: "confluence-icon", name: "Confluence" };
        if (host === "atlassian.net" || host.endsWith(".atlassian.net")) return { iconId: "jira-icon", name: "Jira" };
    } catch {}
    return null;
}

// ── Load data and render ────────────────────────────────

const data = JSON.parse(document.getElementById("brief-data").textContent);
const briefDate = new Date(
    (data.header && data.header.date_time) || Date.now(),
);
const dateKey = briefDate.toDateString().replace(/\W+/g, "-").toLowerCase();

document.addEventListener("DOMContentLoaded", init);

// Painting filename is fixed at the destination by the harness, so the page
// statically references this URL — the agent's JSON cannot influence which
// file is loaded.
const PAINTING_URL = "paintings/painting.jpg";

function init() {
    feedbackEnabled = typeof window.renderBriefFeedback === "function";
    renderBrief();
    setDateTime();
    if (data.painting) {
        applyPainting(data.painting.caption);
    }
    initCaptionScrollFade();
    initStarBadgeTooltips();
    initTodoStickyHover();
    initTodoCompletionClose();
    renderFooterSources(data.footer && data.footer.sources);
    initFooterReveal();
    if (isAllTodosDone()) {
        syncTodoCompletionState({ celebrate: false });
    }
    // Feedback layer — only registered when feedback.js was shipped into the
    // artifact (gated by contextBuilderMorningBriefFeedbackEnabled). Runs last so it can
    // walk every rendered section/item.
    if (typeof window.renderBriefFeedback === "function") {
        window.renderBriefFeedback(data);
    }
}

// ── Template Cloning ────────────────────────────────────

function clone(id) {
    return document
        .getElementById(id)
        .content.firstElementChild.cloneNode(true);
}

// ── Brief Renderer ──────────────────────────────────────

function renderBrief() {
    const content = document.getElementById("briefContent");

    // Blurb below painting
    if (data.header && data.header.greeting) {
        const blurb = document.getElementById("briefBlurb");
        if (blurb) setText(blurb, data.header.greeting);
    }

    // 0. What-this-is intro — the brief's purpose + a privacy note.
    // Framing scaffolding, not agent data; kept scannable and quiet so daily readers glance past it.
    renderIntro(content);

    // 1a. Proactive Work (Hive already started this for you)
    if (data.proactive_work) {
        const proSection = clone("section-template");
        proSection.classList.add("brief-section--boxed", "proactive-section");
        setText(proSection.querySelector(".section-title"), "Started for you in a new tab");

        const proFragment = document.createDocumentFragment();
        const proCard = clone("proactive-work-template");
        if (data.proactive_work.title) {
            setText(proCard.querySelector(".proactive-title"), data.proactive_work.title);
        } else {
            proCard.querySelector(".proactive-title").remove();
        }
        setText(proCard.querySelector(".proactive-reasoning"), data.proactive_work.reasoning);

        while (proCard.firstChild) {
            proFragment.appendChild(proCard.firstChild);
        }
        proSection.querySelector(".section-body").appendChild(proFragment);
        content.appendChild(proSection);
    }

    // 1b. UCB to-dos
    const todos = Array.isArray(data.top_todos) ? data.top_todos.slice(0, 10) : [];
    // Stamp each to-do's position in the combined list before splitting into
    // sections — a stable per-item identity for saved checkbox state, unique across
    // both sections (the list is already in the order the ranker chose).
    todos.forEach((todo, i) => { if (todo && typeof todo === "object") todo._briefIndex = i; });
    const nowItems = todos.filter((todo) => todoTier(todo) !== "later");
    const laterItems = todos.filter((todo) => todoTier(todo) === "later");
    renderSection(content, "Top to-dos", nowItems, buildTodoItem, {
        inline: true,
        sectionId: "todos",
        // The training-data ask references rating + text boxes, which only exist when feedback.js
        // shipped (contextBuilderMorningBriefFeedbackEnabled). With feedback off there's nothing to
        // rate or type into, so drop the ask rather than point at controls that aren't there.
        note: feedbackEnabled
            ? {
                eyebrow: "How to rate this",
                body: "Rate each item below — or edit the phrasing and timing to your **ideal**. Your adjustments teach Hive how to brief you better.",
            }
            : null,
    });
    renderSection(content, "For later", laterItems, buildTodoItem, {
        inline: true,
        sectionId: "todos",
    });

    // 2. High-value work Hive can help move forward
    renderSection(content, "Suggested tasks", data.tasks, buildTaskItem, { sectionId: "task_suggestions" });
}

function renderSection(container, title, items, buildFn, opts = {}) {
    if (!Array.isArray(items) || items.length === 0) return;
    const { inline = false, sectionId = null, feedbackMeta = null, contentSelector = null, note = null } = opts;
    const section = clone("section-template");
    if (inline) section.classList.add("brief-section--inline");
    setText(section.querySelector(".section-title"), title);
    const body = section.querySelector(".section-body");
    // Optional boxed instruction callout (eyebrow + rich body) telling the reader how to rate this
    // section. Styled by .section-note.
    if (note) {
        const noteEl = document.createElement("div");
        noteEl.className = "section-note";
        const noteEyebrow = document.createElement("div");
        noteEyebrow.className = "section-note-eyebrow";
        noteEyebrow.textContent = note.eyebrow;
        noteEl.appendChild(noteEyebrow);
        const noteBody = document.createElement("p");
        noteBody.className = "section-note-body";
        setRichText(noteBody, note.body);
        noteEl.appendChild(noteBody);
        section.querySelector(".section-title").insertAdjacentElement("afterend", noteEl);
    }
    if (sectionId && feedbackEnabled) section.dataset.fbSectionId = sectionId;
    items.forEach((item, i) => {
        const el = buildFn(item, i);
        // Simple item sections tag generically here. `contentSelector` keeps the feedback slot in
        // the content column.
        if (feedbackEnabled && feedbackMeta && contentSelector && el) {
            const target = el.querySelector(contentSelector);
            if (target) target.appendChild(makeFeedbackSlot(el, feedbackMeta(item, i)));
        }
        body.appendChild(el);
    });
    container.appendChild(section);
}

// ── Intro banner (purpose + privacy) ────────────────────
// Static (not agent-generated) framing for the daily brief; the full privacy note sits
// behind a <details> disclosure so returning readers can glance past it.
function renderIntro(container) {
    const section = document.createElement("section");
    section.className = "brief-intro";

    const eyebrow = document.createElement("div");
    eyebrow.className = "brief-intro-eyebrow";
    eyebrow.textContent = "Your daily Hive brief";
    section.appendChild(eyebrow);

    const mission = document.createElement("p");
    mission.className = "brief-intro-mission";
    setRichText(mission, "Hive assembles this brief from **your** browsing — the tabs, history, and sources you actually spend time with — so every morning starts with what matters to you, not a feed.");
    section.appendChild(mission);

    // The "especially need" line asks for input (ratings + free-text ideals), which only render
    // when feedback.js shipped. Omit it when feedback is off so we don't ask for unavailable input.
    if (feedbackEnabled) {
        const need = document.createElement("p");
        need.className = "brief-intro-need";
        setRichText(need, "**This week we especially need:** your ideal to-dos, in your own words.");
        section.appendChild(need);
    }

    const privacy = document.createElement("details");
    privacy.className = "brief-intro-privacy";
    const summary = document.createElement("summary");
    setRichText(summary, "Your brief is assembled locally from your Hive history and tabs.");
    privacy.appendChild(summary);
    const detail = document.createElement("p");
    detail.className = "brief-intro-privacy-detail";
    detail.textContent = "Nothing is uploaded: the brief is generated on your Mac from local browsing data and never leaves the device. Clear your Hive history and the brief resets with it.";
    privacy.appendChild(detail);
    section.appendChild(privacy);

    container.appendChild(section);
}

// ── Feedback tagging ────────────────────────────────────
//
// The in-brief feedback layer (feedback.js, when shipped) is generic: it walks
// `[data-fb-section-id]` sections and every `[data-fb-uid]` (rate-able item) within them.
// Each rate-able item drops a `.fb-controls-slot` inside its content column (via
// `makeFeedbackSlot`); feedback.js fills each slot by uid, so placement lives with the item
// that knows its own layout. New surfaces get covered just by doing the same.
//
// `blockKey` is the authoritative UCB op key the eval-intake join anchors to — the key the agent
// copied from each block's `[blockKey=…]` marker. Many rendered rows can share one (a project's
// next steps all carry the project's key); a keyless row stays rate-able but is dropped at export.
// We never re-derive a key from the title, since a recomputed slug can't join back to the op log.
//
// Set once at init() from whether feedback.js shipped; gates all tagging so the
// brief is byte-for-byte unchanged when the flag is off.
let feedbackEnabled = false;

// Monotonic per-render id pairing each rendered row with its own slot. This, not `blockKey`, is the
// pairing key: rows can share a blockKey (a project's next steps), and pairing by it would collapse
// their controls onto one slot.
let feedbackUid = 0;

// Stamp the feedback attributes on `itemEl` and return a slot to drop wherever
// the item's controls should render (its content column). feedback.js pairs the
// slot to the item by the unique `data-fb-uid`.
function makeFeedbackSlot(itemEl, meta) {
    tagFeedbackItem(itemEl, meta);
    const uid = String(feedbackUid++);
    itemEl.dataset.fbUid = uid;
    const slot = document.createElement("span");
    slot.className = "fb-controls-slot";
    slot.dataset.fbSlot = uid;
    return slot;
}

function displayRank(item, index) {
    const parsed = Number(item.rank);
    return Number.isFinite(parsed) ? parsed : index + 1;
}

function todoTier(item) {
    const tier = String((item && item.tier) || "").trim().toLowerCase();
    // Focus lane emits now/later; the default ranker emits primary/secondary/watch.
    // "later" and "watch" sink to the For-later section; everything else stays in Top to-dos.
    return tier === "later" || tier === "watch" ? "later" : "now";
}

function tagFeedbackItem(el, meta) {
    if (!el || !meta) return;
    // Authoritative UCB op key the eval-intake join anchors to; unset for a keyless item, which
    // export drops rather than join on a non-key. The slot's `data-fb-uid` is the rate-able marker.
    if (meta.blockKey != null) el.dataset.fbBlockKey = meta.blockKey;
    el.dataset.fbType = meta.type;
    if (meta.rank != null) el.dataset.fbRank = String(meta.rank);
    // Snapshot of what the brief said for this item (the anchor a confirmation carries so a verifier
    // row needn't resolve the op). Source-derived from `meta.text`, not the DOM, so template
    // scaffolding — e.g. a project's static "Next steps" label — stays out of it. One line.
    if (meta.text != null) {
        const snapshot = String(meta.text).replace(/\s+/g, " ").trim();
        if (snapshot) el.dataset.fbText = snapshot;
    }
}

// The brief-rendered text for a rate-able item, composed from the source fields its builder paints
// (title/body/description) and joined with an em dash; empty parts dropped.
function feedbackSnapshotText(parts) {
    return parts.filter((part) => typeof part === "string" && part.trim()).join(" — ");
}

function todoFeedbackMeta(item, index) {
    return {
        type: "todo",
        blockKey: item.block_key,
        rank: displayRank(item, index),
        text: feedbackSnapshotText([item.title]),
    };
}

// ── Safety Helpers ───────────────────────────────────────

function isSafeUrl(url) {
    try {
        const parsed = new URL(url);
        if (parsed.protocol === "https:" || parsed.protocol === "http:") return true;
        // dia-report: is a first-party deep-link scheme; only the `chat` host is safe for
        // LLM-provided URLs. Privileged hosts — notably `connect`, which starts app-connection
        // OAuth — must originate only from first-party UI (the Connect Apps pills, which build the
        // URL in connect-apps.js and bypass this check), never from brief content the model emits.
        if (parsed.protocol === "dia-report:") return parsed.host === "chat";
        return false;
    } catch {
        return false;
    }
}

function buildChatDeepLink(prompt) {
    if (!prompt) return "#";
    const params = new URLSearchParams({ q: prompt });
    return "dia-report://chat?" + params.toString();
}

/** Always set text content, never innerHTML. */
function setText(el, value) {
    el.textContent = value ?? "";
}

/**
 * Render limited inline emphasis — `**bold**` and `*italic*` — as real <strong>/<em>
 * nodes (never innerHTML). Used for scannable to-do/next-step text. Unmatched markers
 * render as literal characters.
 */
function setRichText(el, value) {
    if (!el) return;
    el.textContent = "";
    const parts = String(value ?? "").split(/(\*\*[^*]+\*\*|\*[^*]+\*)/g);
    parts.forEach((part) => {
        if (!part) return;
        if (part.length > 4 && part.startsWith("**") && part.endsWith("**")) {
            const strong = document.createElement("strong");
            strong.textContent = part.slice(2, -2);
            el.appendChild(strong);
        } else if (part.length > 2 && part.startsWith("*") && part.endsWith("*")) {
            const em = document.createElement("em");
            em.textContent = part.slice(1, -1);
            el.appendChild(em);
        } else {
            el.appendChild(document.createTextNode(part));
        }
    });
}

// ── Build an item (New Updates / On Your Radar) ─────────

function buildItem(item, index) {
    const el = clone("item-template");

    setText(el.querySelector(".item-num"), String(index + 1).padStart(2, "0"));

    const title = el.querySelector(".item-title");
    const tag = el.querySelector(".item-tag");

    // Insert title text/link before the inline tag span
    if (item.source_url && isSafeUrl(item.source_url)) {
        const a = document.createElement("a");
        a.href = item.source_url;
        a.target = "_blank";
        a.rel = "noopener";
        setText(a, item.title);
        title.insertBefore(a, tag);
    } else {
        title.insertBefore(document.createTextNode(item.title), tag);
    }

    if (item.label) {
        setText(tag, item.label);
        if (item.label_style === "active") {
            tag.className = "item-tag tag-active";
        }
    } else {
        tag.remove();
    }

    const bodyP = el.querySelector(".item-text p");
    setText(bodyP, item.body);
    if (item.source_url && isSafeUrl(item.source_url)) {
        const icon = buildSourceIcon(item.source_url);
        if (icon) {
            bodyP.appendChild(document.createTextNode(" "));
            bodyP.appendChild(icon);
        }
    }
    appendAvatars(bodyP, item.avatar_urls);

    // Bullets (optional)
    const bullets = el.querySelector(".item-bullets");
    if (item.bullets && item.bullets.length) {
        item.bullets.forEach((b) => {
            const li = document.createElement("li");
            setText(li, b);
            bullets.appendChild(li);
        });
    } else {
        bullets.remove();
    }

    return el;
}

// ── Build a to-do item ──────────────────────────────────

function buildTodoItem(item, index) {
    const el = clone("todo-item-template");
    // Rank from the UCB ranker (coerce numeric strings); fall back to document order.
    const rank = displayRank(item, index);
    // Key saved state by the item's stable position in the combined list, not its
    // rank — an identity, not a priority, and unique across both to-do sections.
    const position = item && item._briefIndex != null ? item._briefIndex : index;
    const key = "brief-" + dateKey + "-todo-" + position;
    setText(el.querySelector(".todo-rank"), String(rank).padStart(2, "0"));

    if (item.time_sensitive) {
        el.classList.add("todo-item--time-sensitive");
        const flag = el.querySelector(".todo-flag");
        if (flag) {
            setText(flag, item.due_label ? item.due_label : "Time-sensitive");
            flag.hidden = false;
        }
    }

    const input = el.querySelector('input[type="checkbox"]');
    input.checked = localStorage.getItem(key) === "1";
    input.addEventListener("change", () => {
        localStorage.setItem(key, input.checked ? "1" : "0");
        playPop(input.checked);
        if (!input.checked) {
            // Re-opening a to-do dismisses any sticky completion state.
            todoCompletionDismissed = false;
        }
        syncTodoCompletionState({ celebrate: input.checked && isAllTodosDone() });
    });

    const label = el.querySelector(".todo-label");
    if (item.source_url && isSafeUrl(item.source_url)) {
        const a = document.createElement("a");
        a.href = item.source_url;
        a.target = "_blank";
        a.rel = "noopener";
        setText(a, item.title);
        label.appendChild(a);
    } else {
        setText(label, item.title);
    }
    if (item.source_url && isSafeUrl(item.source_url)) {
        const icon = buildSourceIcon(item.source_url);
        if (icon) {
            label.appendChild(document.createTextNode(" "));
            label.appendChild(icon);
        }
    }
    appendAvatars(label, item.avatar_urls);

    setRichText(el.querySelector(".todo-context"), item.body);

    // CTA pill. The agent only emits `cta_label` + `cta_prompt` when the
    // `clia-morning-brief-todos-ctas` flag is on (see spec.yaml). If absent,
    // we leave the pill `hidden` so the layout stays untouched.
    const cta = el.querySelector(".todo-dia-btn");
    if (typeof item.cta_prompt === "string" && typeof item.cta_label === "string" && item.cta_prompt && item.cta_label) {
        wireTodoCta(cta, item);
    } else if (cta) {
        cta.remove();
    }

    if (feedbackEnabled) {
        el.querySelector(".todo-content").appendChild(makeFeedbackSlot(el, todoFeedbackMeta(item, index)));
    }

    return el;
}

function wireTodoCta(cta, item) {
    const label = (item.cta_label || "").trim();
    const prompt = (item.cta_prompt || "").trim();
    if (!label || !prompt) { cta.remove(); return; }

    const deepLink = buildChatDeepLink(prompt);
    cta.href = isSafeUrl(deepLink) ? deepLink : "#";
    cta.hidden = false;
    cta.dataset.chatMessage = prompt;
    setText(cta.querySelector(".todo-dia-btn-label"), label);
    cta.setAttribute("aria-label", `${label} with Hive in Chat`);

    // Feeds the shared #star-tooltip-popover (initStarBadgeTooltips reads these
    // data-* attrs) so the to-do CTA tooltip reads consistently across the brief.
    cta.dataset.tooltipHeadline = "Start a chat about this";
    cta.dataset.tooltipBody = prompt;
    cta.dataset.tooltipBodyPresentation = "prompt";
}

// ── Build a task item ──────────────────────────────────

function buildTaskItem(item) {
    const el = clone("task-item-template");
    const taskKey = item.block_key;

    const title = el.querySelector(".task-title");
    if (item.source_url && isSafeUrl(item.source_url)) {
        const link = document.createElement("a");
        link.href = item.source_url;
        link.target = "_blank";
        link.rel = "noopener";
        setText(link, item.title || "");
        title.appendChild(link);
        const icon = buildSourceIcon(item.source_url);
        if (icon) {
            title.appendChild(document.createTextNode(" "));
            title.appendChild(icon);
        }
    } else {
        setText(title, item.title || "");
    }

    const desc = el.querySelector(".task-desc");
    if (item.description) {
        setText(desc, item.description);
    } else {
        desc.remove();
    }

    if (feedbackEnabled) {
        const slot = makeFeedbackSlot(el, {
            type: "task",
            blockKey: taskKey,
            rank: null,
            text: feedbackSnapshotText([item.title, item.description]),
        });
        el.querySelector(".item-text").insertAdjacentElement("afterend", slot);
    }

    return el;
}

// ── Avatars ──────────────────────────────────────────────

function appendAvatars(parentEl, urls) {
    if (!Array.isArray(urls) || urls.length === 0) return;
    const safe = urls.filter(isSafeUrl).slice(0, 3);
    if (safe.length === 0) return;

    safe.forEach((url) => {
        const img = document.createElement("img");
        img.className = "avatar-img";
        img.alt = "";
        img.loading = "lazy";
        img.onerror = () => { img.style.display = "none"; };
        img.src = url;
        parentEl.appendChild(img);
    });
}

// ── Source Icons ─────────────────────────────────────────

function buildSourceIcon(sourceUrl) {
    const source = getSourceFromUrl(sourceUrl);
    if (!source) return null;

    const iconTemplate = document.getElementById(source.iconId);
    if (!iconTemplate) return null;

    const el = clone("source-icon-template");
    el.href = isSafeUrl(sourceUrl) ? sourceUrl : "#";
    el.prepend(iconTemplate.content.firstElementChild.cloneNode(true));
    setText(el.querySelector(".source-tip"), "Open in " + source.name);

    // Random tilt for visual variety
    const tilt = (Math.random() * 3 - 1.5).toFixed(1);
    const hoverTilt = (Math.random() * 20 - 10).toFixed(0);
    el.style.setProperty("--tilt", tilt + "deg");
    el.style.setProperty("--hover-tilt", hoverTilt + "deg");

    return el;
}

// ── Helpers ──────────────────────────────────────────────


// ── DateTime (derived from header.date_time, set once) ──

function setDateTime() {
    const days = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
    ];
    const months = [
        "JAN",
        "FEB",
        "MAR",
        "APR",
        "MAY",
        "JUN",
        "JUL",
        "AUG",
        "SEP",
        "OCT",
        "NOV",
        "DEC",
    ];

    const dayEl = document.getElementById("heroDay");
    if (dayEl) setText(dayEl, days[briefDate.getDay()] + " Brief");

    const dateEl = document.getElementById("heroDate");
    if (dateEl) {
        const dd = String(briefDate.getDate()).padStart(2, "0");
        setText(dateEl, dd + " " + months[briefDate.getMonth()] + " " + briefDate.getFullYear());
    }

    const timeEl = document.getElementById("heroTime");
    if (timeEl) {
        const h = briefDate.getHours();
        const m = String(briefDate.getMinutes()).padStart(2, "0");
        const ampm = h >= 12 ? "PM" : "AM";
        const h12 = String(h % 12 || 12).padStart(2, "0");
        setText(timeEl, h12 + ":" + m + " " + ampm);
    }
}

// ── Painting ────────────────────────────────────────────

function applyPainting(captionText) {
    const img = document.getElementById("paintingImg");
    const caption = document.getElementById("paintingCaption");
    if (!img || !caption) return;

    img.classList.remove("loaded");
    caption.classList.remove("visible");

    const loader = new Image();
    loader.onload = () => {
        img.src = PAINTING_URL;
        requestAnimationFrame(() => img.classList.add("loaded"));
        setText(caption, captionText);
        caption.classList.add("visible");
    };
    loader.onerror = () => {
        console.warn("Image failed to load:", PAINTING_URL);
    };
    loader.src = PAINTING_URL;
}

function initCaptionScrollFade() {
    const caption = document.getElementById("paintingCaption");
    if (!caption) return;
    const fadeStart = 40;
    const fadeEnd = 200;

    window.addEventListener(
        "scroll",
        () => {
            const y = window.scrollY;
            if (y <= fadeStart) caption.style.opacity = "";
            else if (y >= fadeEnd) caption.style.opacity = "0";
            else
                caption.style.opacity = String(
                    1 - (y - fadeStart) / (fadeEnd - fadeStart),
                );
        },
        { passive: true },
    );
}

// ── Schedule Hover ──────────────────────────────────────

// ── Star badge tooltips ─────────────────────────────────
// One #star-tooltip-popover for all .push-badge / .prep-badge (replaces per-badge
// .star-tip + title=). Copy comes from data-tooltip-* on the anchor; badges must
// not use title= or the browser tooltip would duplicate this UI.

const STAR_TOOLTIP_CHAT_PATH_D =
    "M0.823639 6.625H0.198639H0.823639ZM14.8236 6.625H15.4486V6.625H14.8236ZM5.31583 12.292L5.48822 11.6912C5.39879 11.6656 5.30476 11.6602 5.21299 11.6755L5.31583 12.292ZM0.919342 13.0254L1.02209 13.6419L1.02218 13.6419L0.919342 13.0254ZM0.674225 12.6338L0.165564 12.2706L0.165373 12.2709L0.674225 12.6338ZM2.23184 10.4521L2.7405 10.8153C2.9114 10.576 2.89229 10.2498 2.69462 10.0321L2.23184 10.4521ZM0.823639 6.625H1.44864C1.44864 4.79108 2.22642 3.46361 3.38879 2.58212C4.56963 1.68664 6.17648 1.23328 7.81709 1.25047C9.45743 1.26766 11.0696 1.75475 12.2563 2.66295C13.4267 3.55874 14.1986 4.87161 14.1986 6.625H14.8236H15.4486C15.4486 4.45206 14.4705 2.78352 13.016 1.67031C11.5777 0.569508 9.68984 0.0200216 7.83019 0.000538468C5.9708 -0.0189418 4.07764 0.490951 2.63348 1.58613C1.17085 2.69531 0.198639 4.38592 0.198639 6.625H0.823639ZM14.8236 6.625H14.1986C14.1986 8.79258 13.0143 10.3083 11.3207 11.1738C9.60408 12.0511 7.39119 12.2373 5.48822 11.6912L5.31583 12.292L5.14344 12.8927C7.33493 13.5216 9.87594 13.316 11.8896 12.2869C13.9263 11.246 15.4486 9.3407 15.4486 6.625H14.8236ZM5.31583 12.292L5.21299 11.6755L0.816504 12.4089L0.919342 13.0254L1.02218 13.6419L5.41866 12.9085L5.31583 12.292ZM0.919342 13.0254L0.816592 12.4089C1.14339 12.3544 1.37854 12.7226 1.18308 12.9967L0.674225 12.6338L0.165373 12.2709C-0.288578 12.9074 0.25604 13.7696 1.02209 13.6419L0.919342 13.0254ZM0.674225 12.6338L1.18289 12.997L2.7405 10.8153L2.23184 10.4521L1.72318 10.089L0.165565 12.2706L0.674225 12.6338ZM2.23184 10.4521L2.69462 10.0321C1.9339 9.19403 1.44864 8.07188 1.44864 6.625H0.823639H0.198639C0.198639 8.37631 0.795428 9.79962 1.76907 10.8722L2.23184 10.4521Z";

function createStarTooltipChatIconSvg() {
    const svgNS = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("width", "16");
    svg.setAttribute("height", "14");
    svg.setAttribute("viewBox", "0 0 16 14");
    svg.setAttribute("fill", "none");
    const path = document.createElementNS(svgNS, "path");
    path.setAttribute("opacity", "0.88");
    path.setAttribute("d", STAR_TOOLTIP_CHAT_PATH_D);
    path.setAttribute("fill", "#1a1a1a");
    svg.appendChild(path);
    return svg;
}

function positionStarTooltip(anchor, popover) {
    const rect = anchor.getBoundingClientRect();
    const margin = 10;
    const gap = 0;
    const pw = popover.offsetWidth;
    const ph = popover.offsetHeight;
    let left = rect.left + rect.width / 2 - pw / 2;
    left = Math.max(margin, Math.min(left, window.innerWidth - pw - margin));
    let top = rect.top - gap - ph;
    popover.classList.remove("star-tooltip-popover--below");
    if (top < margin) {
        top = rect.bottom + gap;
        popover.classList.add("star-tooltip-popover--below");
    }
    popover.style.left = `${Math.round(left)}px`;
    popover.style.top = `${Math.round(top)}px`;
}

function initStarBadgeTooltips() {
    let popover = document.getElementById("star-tooltip-popover");
    if (!popover) {
        popover = document.createElement("div");
        popover.id = "star-tooltip-popover";
        popover.className = "star-tooltip-popover";
        popover.setAttribute("role", "tooltip");
        popover.setAttribute("aria-hidden", "true");
        const head = document.createElement("div");
        head.className = "star-tooltip-popover__head";
        const iconWrap = document.createElement("span");
        iconWrap.className = "star-tooltip-popover__icon";
        iconWrap.setAttribute("aria-hidden", "true");
        iconWrap.appendChild(createStarTooltipChatIconSvg());
        const headText = document.createElement("span");
        headText.className = "star-tooltip-popover__head-text";
        head.appendChild(iconWrap);
        head.appendChild(headText);
        const body = document.createElement("div");
        body.className = "star-tooltip-popover__body";
        const bodyMsg = document.createElement("div");
        bodyMsg.className = "star-tooltip-popover__body-msg";
        body.appendChild(bodyMsg);
        popover.appendChild(head);
        popover.appendChild(body);
        document.body.appendChild(popover);
    }

    const headTextEl = popover.querySelector(".star-tooltip-popover__head-text");
    const bodyWrap = popover.querySelector(".star-tooltip-popover__body");
    const bodyMsgEl = popover.querySelector(".star-tooltip-popover__body-msg");

    let showTimer = null;
    let activeAnchor = null;

    function hide() {
        clearTimeout(showTimer);
        showTimer = null;
        if (activeAnchor) {
            activeAnchor.removeAttribute("aria-describedby");
        }
        popover.setAttribute("aria-hidden", "true");
        popover.classList.remove("star-tooltip-popover--visible");
        activeAnchor = null;
    }

    function show(anchor) {
        if (anchor.classList.contains("hidden")) return;
        const headline = anchor.dataset.tooltipHeadline || "";
        const body = anchor.dataset.tooltipBody || "";
        if (!headline && !body) return;

        if (activeAnchor && activeAnchor !== anchor) {
            activeAnchor.removeAttribute("aria-describedby");
        }

        if (headTextEl) setText(headTextEl, headline);

        if (!bodyWrap) return;

        if (bodyMsgEl) {
            const asPrompt =
                anchor.dataset.tooltipBodyPresentation === "prompt";
            if (!body) {
                bodyWrap.setAttribute("hidden", "");
            } else {
                bodyWrap.removeAttribute("hidden");
                if (asPrompt) {
                    bodyWrap.classList.add("star-tooltip-popover__body--prompt");
                } else {
                    bodyWrap.classList.remove(
                        "star-tooltip-popover__body--prompt",
                    );
                }
                setText(bodyMsgEl, body);
            }
        } else {
            setText(bodyWrap, body);
            if (body) bodyWrap.removeAttribute("hidden");
            else bodyWrap.setAttribute("hidden", "");
        }

        popover.classList.add("star-tooltip-popover--visible");
        anchor.setAttribute("aria-describedby", "star-tooltip-popover");
        popover.setAttribute("aria-hidden", "false");
        activeAnchor = anchor;

        // Popover size is wrong until after first paint; second pass fixes placement.
        requestAnimationFrame(() => {
            positionStarTooltip(anchor, popover);
            requestAnimationFrame(() => positionStarTooltip(anchor, popover));
        });
    }

    function scheduleShow(anchor) {
        clearTimeout(showTimer);
        showTimer = setTimeout(() => show(anchor), 450);
    }

    function bind(anchor) {
        if (!anchor || anchor.dataset.starTooltipBound === "1") return;
        anchor.dataset.starTooltipBound = "1";

        anchor.addEventListener("mouseenter", () => scheduleShow(anchor));
        anchor.addEventListener("mouseleave", hide);

        anchor.addEventListener("focusin", () => scheduleShow(anchor));
        anchor.addEventListener("focusout", (e) => {
            if (!e.relatedTarget || !anchor.contains(e.relatedTarget)) {
                hide();
            }
        });
    }

    document.querySelectorAll(".push-badge, .prep-badge, .todo-dia-btn.todo-chat-prompt").forEach(bind);

    function reflowIfActive() {
        if (activeAnchor) positionStarTooltip(activeAnchor, popover);
    }
    window.addEventListener("scroll", reflowIfActive, true);
    window.addEventListener("resize", reflowIfActive);
}

// ── To-Do Check Sound + Completion Fanfare (WebAudio, self-contained) ──
//
// Ported from christine-sandbox/morningbrief/daily-brief-alt-app.js
// (commit ce33f21). Two synthesized sounds — playPop for individual checkbox
// toggles (rising blip on check, falling blip on uncheck), and a 4-note
// arpeggio fanfare + shimmer sweep for the all-done celebration. No audio
// assets shipped: the artifact stays self-contained.

function playPop(checked) {
    try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const t = ctx.currentTime;
        const gain = ctx.createGain();
        gain.connect(ctx.destination);

        const osc = ctx.createOscillator();
        osc.type = "sine";
        if (checked) {
            osc.frequency.setValueAtTime(400, t);
            osc.frequency.exponentialRampToValueAtTime(800, t + 0.025);
            osc.frequency.exponentialRampToValueAtTime(600, t + 0.05);
            gain.gain.setValueAtTime(0.12, t);
            gain.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
            osc.connect(gain);
            osc.start(t);
            osc.stop(t + 0.06);
        } else {
            osc.frequency.setValueAtTime(600, t);
            osc.frequency.exponentialRampToValueAtTime(350, t + 0.04);
            gain.gain.setValueAtTime(0.07, t);
            gain.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
            osc.connect(gain);
            osc.start(t);
            osc.stop(t + 0.05);
        }
        setTimeout(() => ctx.close(), 200);
    } catch (e) { /* Web Audio unavailable */ }
}

function playCompletionFanfare() {
    try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const t = ctx.currentTime;
        const master = ctx.createGain();
        master.gain.setValueAtTime(0.18, t);
        master.gain.exponentialRampToValueAtTime(0.001, t + 0.85);
        master.connect(ctx.destination);

        const notes = [
            { freq: 523.25, type: "sine",     at: 0,    dur: 0.28 },
            { freq: 659.25, type: "sine",     at: 0.09, dur: 0.28 },
            { freq: 783.99, type: "sine",     at: 0.18, dur: 0.28 },
            { freq: 1046.5, type: "triangle", at: 0.28, dur: 0.42 },
        ];

        notes.forEach(({ freq, type, at, dur }) => {
            const osc = ctx.createOscillator();
            const g = ctx.createGain();
            osc.type = type;
            osc.frequency.value = freq;
            const start = t + at;
            g.gain.setValueAtTime(0, start);
            g.gain.linearRampToValueAtTime(type === "triangle" ? 0.55 : 0.4, start + 0.02);
            g.gain.exponentialRampToValueAtTime(0.001, start + dur);
            osc.connect(g);
            g.connect(master);
            osc.start(start);
            osc.stop(start + dur + 0.02);
        });

        const shimmer = ctx.createOscillator();
        const sg = ctx.createGain();
        shimmer.type = "sine";
        shimmer.frequency.setValueAtTime(1318, t + 0.32);
        shimmer.frequency.exponentialRampToValueAtTime(2093, t + 0.58);
        sg.gain.setValueAtTime(0.12, t + 0.32);
        sg.gain.exponentialRampToValueAtTime(0.001, t + 0.62);
        shimmer.connect(sg);
        sg.connect(master);
        shimmer.start(t + 0.32);
        shimmer.stop(t + 0.64);

        setTimeout(() => ctx.close(), 900);
    } catch (e) { /* Web Audio unavailable */ }
}

// ── To-Do Active State (hover-only) ─────────────────────
//
// One to-do at a time has `.is-active` — and only while the mouse (or
// keyboard focus) is actually on it. Leaving the list clears the active
// state; there is no default-active item on page load.

let _activeTodoItem = null;

function initTodoStickyHover() {
    // To-dos can render across more than one section ("Top to-dos" + "For later"),
    // so wire each. `setActiveTodoItem` is global, so hovering an item in either
    // section highlights it and clears the other.
    findTodosSections().forEach((section) => {
        const items = section.querySelectorAll(".todo-item");
        if (!items.length) return;

        items.forEach((item) => {
            item.addEventListener("mouseenter", () => setActiveTodoItem(item));
            item.addEventListener("focusin",    () => setActiveTodoItem(item));
        });

        // Clear on `mouseleave` of the section so transitions between two items
        // don't flicker (mouseleave doesn't fire on item-to-item transitions
        // within the section). Same idea for focus: only clear when focus
        // genuinely leaves the section, not when it moves between items.
        section.addEventListener("mouseleave", () => setActiveTodoItem(null));
        section.addEventListener("focusout", (e) => {
            if (!e.relatedTarget || !section.contains(e.relatedTarget)) {
                setActiveTodoItem(null);
            }
        });
    });
}

function setActiveTodoItem(item) {
    if (item === _activeTodoItem) return;
    _activeTodoItem?.classList.remove("is-active");
    _activeTodoItem = item;
    _activeTodoItem?.classList.add("is-active");
}

// ── To-Do Completion Popover (multi-stage sequence) ─────
//
// When every checkbox in the to-dos section is checked:
//   1. The list collapses (section gets `.is-all-done`)
//   2. After popoverRevealDelay, the completion card appears with
//      `.is-popover-visible`
//   3. With `.is-sequence-active`: badge pops in, fanfare plays, confetti
//      bursts, then content fades up in cascade
//   4. State settles to `.is-sequence-done` (final visible state)
//
// On uncheck or close-button click, everything reverses to the list view.

const COMPLETION_SEQUENCE = {
    popoverRevealDelay: 280,
    fanfareDelay:       220,
    confettiDelay:      520,
    sequenceEnd:       1900,
};

let completionSequenceTimers = [];
let todoCompletionWasAllDone = false;
let todoCompletionDismissed = false;
let _allDoneEl = null;

function clearCompletionSequenceTimers() {
    completionSequenceTimers.forEach(clearTimeout);
    completionSequenceTimers = [];
}

function findTodosSection() {
    const sections = document.querySelectorAll(".brief-section--inline");
    for (const s of sections) {
        if (s.querySelector(".todo-item")) return s;
    }
    return null;
}

// Every inline section that holds to-dos, in render order. To-dos can span two
// sections ("Top to-dos" + "For later"); completion + hover treat them as one set.
function findTodosSections() {
    return [...document.querySelectorAll(".brief-section--inline")].filter((s) => s.querySelector(".todo-item"));
}

// When the whole to-do set is done, the celebration overlays the first section;
// any later sections collapse away so the all-done state reads as one celebration,
// like the single-list standard brief.
function setSecondaryTodoSectionsCollapsed(collapsed) {
    findTodosSections().slice(1).forEach((s) => s.classList.toggle("is-todos-done-collapsed", collapsed));
}

function getTodoCheckboxes() {
    return [...document.querySelectorAll('.brief-section--inline .todo-item input[type="checkbox"]')];
}

function isAllTodosDone() {
    const boxes = getTodoCheckboxes();
    return boxes.length > 0 && boxes.every((cb) => cb.checked);
}

function ensureAllDoneEl(section) {
    if (_allDoneEl && _allDoneEl.isConnected) return _allDoneEl;
    _allDoneEl = clone("todo-all-done-template");
    section.querySelector(".section-body").appendChild(_allDoneEl);

    // Close button: dismiss the completion popover (sticky until uncheck or
    // refresh — same as Christine's prototype).
    _allDoneEl.querySelector(".todo-all-done__close")?.addEventListener("click", dismissTodoCompletion);

    return _allDoneEl;
}

function syncTodoCompletionState({ celebrate = false } = {}) {
    const section = findTodosSection();
    if (!section) return;

    const allDone = isAllTodosDone();
    const showCompletion = allDone && !todoCompletionDismissed;
    const wasShowingCompletion = todoCompletionWasAllDone;
    const isFirstCelebrate = showCompletion && celebrate && !wasShowingCompletion;

    // Collapse any secondary to-do sections so the celebration reads as one.
    setSecondaryTodoSectionsCollapsed(showCompletion);

    if (!showCompletion) {
        stopCompletion(section);
        return;
    }

    const doneEl = ensureAllDoneEl(section);
    const confettiEl = doneEl.querySelector(".todo-confetti");

    if (isFirstCelebrate) {
        clearCompletionSequenceTimers();
        doneEl.hidden = true;
        doneEl.classList.remove("is-sequence-active", "is-sequence-done", "is-popover-visible");
        section.classList.add("is-all-done");

        const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        if (reduced) {
            revealCompletionPopover(doneEl, confettiEl);
        } else {
            completionSequenceTimers.push(
                setTimeout(
                    () => revealCompletionPopover(doneEl, confettiEl),
                    COMPLETION_SEQUENCE.popoverRevealDelay
                )
            );
        }
    } else {
        // Restoring the popover state on page load when all-done was already
        // true — no animation, no sound. Skip straight to is-sequence-done.
        section.classList.add("is-all-done");
        doneEl.hidden = false;
        doneEl.classList.add("is-popover-visible");
        if (!doneEl.classList.contains("is-sequence-active")) {
            doneEl.classList.add("is-sequence-done");
        }
    }

    todoCompletionWasAllDone = true;
}

function stopCompletion(section) {
    clearCompletionSequenceTimers();
    if (_allDoneEl) {
        _allDoneEl.querySelector(".todo-confetti")?.replaceChildren();
        _allDoneEl.hidden = true;
        _allDoneEl.classList.remove("is-sequence-active", "is-sequence-done", "is-popover-visible");
    }
    section.classList.remove("is-all-done");
    todoCompletionWasAllDone = false;
}

function revealCompletionPopover(doneEl, confettiEl) {
    if (!doneEl) return;
    doneEl.hidden = false;
    void doneEl.offsetWidth;
    doneEl.classList.add("is-popover-visible");
    runCompletionSequence(doneEl, confettiEl);
}

function runCompletionSequence(doneEl, confettiEl) {
    if (!doneEl) return;
    doneEl.classList.remove("is-sequence-done");

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced) {
        playCompletionFanfare();
        launchTodoConfetti(confettiEl);
        doneEl.classList.add("is-sequence-done");
        return;
    }

    void doneEl.offsetWidth;
    doneEl.classList.add("is-sequence-active");

    completionSequenceTimers.push(
        setTimeout(() => playCompletionFanfare(), COMPLETION_SEQUENCE.fanfareDelay)
    );
    completionSequenceTimers.push(
        setTimeout(() => launchTodoConfetti(confettiEl), COMPLETION_SEQUENCE.confettiDelay)
    );
    completionSequenceTimers.push(
        setTimeout(() => {
            doneEl.classList.remove("is-sequence-active");
            doneEl.classList.add("is-sequence-done");
        }, COMPLETION_SEQUENCE.sequenceEnd)
    );
}

const TODO_CONFETTI_COLORS = ["#FFE500", "#FFF066", "#FFD000", "#FFEB3B", "#FFF4A3"];

function launchTodoConfetti(container) {
    if (!container || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    container.replaceChildren();
    const count = 48;
    for (let i = 0; i < count; i += 1) {
        const piece = document.createElement("span");
        const isDot = Math.random() > 0.45;
        piece.className = "todo-confetti-piece" + (isDot ? " todo-confetti-piece--dot" : " todo-confetti-piece--rect");
        const size = 5 + Math.random() * 6;
        const angle = Math.random() * Math.PI * 2;
        const distance = 70 + Math.random() * 150;
        piece.style.setProperty("--size", `${size}px`);
        piece.style.setProperty("--tx", `${Math.cos(angle) * distance}px`);
        piece.style.setProperty("--ty", `${Math.sin(angle) * distance - 20}px`);
        piece.style.setProperty("--rot", `${Math.random() * 540 - 270}deg`);
        piece.style.setProperty("--color", TODO_CONFETTI_COLORS[i % TODO_CONFETTI_COLORS.length]);
        piece.style.animationDelay = `${Math.random() * 0.12}s`;
        container.appendChild(piece);
    }
}

function dismissTodoCompletion() {
    todoCompletionDismissed = true;
    syncTodoCompletionState();
}

function initTodoCompletionClose() {
    // No-op: the close button is wired per-instance in `ensureAllDoneEl`.
    // Kept for symmetry with the other init* functions.
}

// ── Footer ──────────────────────────────────────────────
//
// The static footer (HIVE + "Made for you by Hive") is rendered in
// index.html. When the agent emits `data.footer.sources` (gated by
// `clia-morning-brief-footer-sources`), we splice an inline source list
// into the credit prose: "Made for you by Hive using your X, Y, and Z."
//
// Scroll-reveal: footer fades up the first time it enters the viewport.

function renderFooterSources(sources) {
    const credit  = document.getElementById("briefFooterCredit");
    const trailing = document.getElementById("briefFooterCreditTrailing");
    if (!credit || !trailing) return;
    if (!Array.isArray(sources) || sources.length === 0) return;

    const safe = sources.filter((s) => s && typeof s.url === "string" && isSafeUrl(s.url) && s.name).slice(0, 6);
    if (safe.length === 0) return;

    // Only reveal the "Made for you by Hive using your X, Y, Z." line when we
    // have real sources to credit. Without sources the line is meaningless,
    // so the footer collapses to just the Hive love badge.
    credit.hidden = false;

    // Build: "using your <chip1>, <chip2>, and <chipN>." — inline into the
    // credit paragraph just before the trailing period.
    const frag = document.createDocumentFragment();
    const usingYour = document.createElement("span");
    usingYour.className = "brief-footer__muted";
    usingYour.appendChild(document.createTextNode("using "));
    const em = document.createElement("em");
    em.className = "brief-footer__emph";
    setText(em, "your");
    usingYour.appendChild(em);
    frag.appendChild(usingYour);

    safe.forEach((s, i) => {
        if (i > 0) {
            const sep = document.createElement("span");
            sep.className = "brief-footer__muted";
            const isLast = i === safe.length - 1;
            setText(sep, isLast && safe.length > 2 ? ", and "
                       : isLast                      ? " and "
                       :                               ", ");
            frag.appendChild(sep);
        }
        frag.appendChild(buildFooterSourceChip(s));
    });

    // Insert before the trailing period.
    credit.insertBefore(frag, trailing);
}

function buildFooterSourceChip(source) {
    const a = document.createElement("a");
    a.className = "brief-footer__source source-ref";
    a.href = isSafeUrl(source.url) ? source.url : "#";
    a.target = "_blank";
    a.rel = "noopener";

    // Optional kind modifier so existing brand-specific tweaks pick up.
    const sourceInfo = getSourceFromUrl(source.url);
    if (sourceInfo) {
        a.classList.add("brief-footer__source--" + sourceInfo.iconId.replace("-icon", ""));
    }

    // Random tilt for visual variety, matching the source-icon pattern.
    const tilt      = (Math.random() * 3 - 1.5).toFixed(1);
    const hoverTilt = (Math.random() * 20 - 10).toFixed(0);
    a.style.setProperty("--tilt", tilt + "deg");
    a.style.setProperty("--hover-tilt", hoverTilt + "deg");

    // Source-icon SVG (cloned from the existing icon templates).
    const iconWrap = document.createElement("span");
    iconWrap.className = "source-icon";
    if (sourceInfo) {
        const tmpl = document.getElementById(sourceInfo.iconId);
        if (tmpl) iconWrap.appendChild(tmpl.content.firstElementChild.cloneNode(true));
    }
    a.appendChild(iconWrap);

    const name = document.createTextNode(" " + (source.name || ""));
    a.appendChild(name);
    return a;
}

function initFooterReveal() {
    const footer = document.querySelector(".brief-footer");
    if (!footer) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        footer.classList.add("is-visible");
        return;
    }
    const observer = new IntersectionObserver(
        ([entry]) => {
            if (!entry.isIntersecting) return;
            footer.classList.add("is-visible");
            observer.disconnect();
        },
        { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );
    observer.observe(footer);
}
