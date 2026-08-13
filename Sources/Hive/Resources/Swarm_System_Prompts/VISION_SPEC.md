# VISION_SPEC — Multimodal & Vision Cell Canon

> **Canonical status:** active
> **Created:** 2026-08-11
> **Read this before:** wiring any screenshot, OCR, DOM-observation, or media-analysis capability
> **Companion to:** `ROUTING_SPEC.md` (tiers + latency), `MEMORY_ARCHITECTURE_SPEC.md` (what memory keeps), `00_INDEX.md`
> **Grounded in:** small-VLM landscape research (SmolVLM, Qwen2-VL, PaliGemma, Phi-3.5-vision, moondream, Florence-2, Apple FMF vision) + Rewisp's reduction-first capture model (`competitive-megadossier.md` §12/§32)

## 0. The Thesis

**Text is memory; pixels are evidence.** On the 8GB floor, vision exists to *convert pixels into structured text and coordinates* — it is never the product itself, and screenshots are never retained. The Rewisp lesson is absolute: **the image is discarded the instant its text/claims are extracted.** The browser advantage compounds: we observe at the DOM level (structured, CORS-safe) and use vision only where pixels beat DOM (screenshots, canvas, images, PDFs, video frames, non-DOM UI).

**The ground-truth rule:** VLMs are brittle at reading exact strings and coordinates. The **DOM/AXTree is the execution ground truth**; vision output is a *hint* about where to look, never the action contract. `click(text:"Next")` resolves via accessibility tree refs, not pixel coordinates.

## 1. Which Cells Need Vision (and at what tier)

| Cell / surface | Vision job | Model tier | Latency budget |
|---|---|---|---|
| `browser/100m_dom_scout` | Page screenshot classification (purpose, layout class) | Gatekeeper (Florence-2-Large / SmolVLM-500M) | <1s |
| `browser/8b_nav_reasoner` | Ambiguous-state resolution (unlabelled icon, error ring, disabled button) | Reasoner (Qwen2-VL-2B int4 / moondream2) | 1.5–3s, conditional only |
| `scribe/100m_capture_scribe` | OCR of non-DOM content (canvas, images, PDFs, screenshots the user saved) | Gatekeeper OCR (Florence-2 / SmolVLM-2B) | 0.8–2s |
| Media analysis (P3 Sheets/Photos) | Photo/video content tagging, document scans | Reasoner, batch, idle-time | async |
| Form understanding (autofill parity) | Field detection on complex/JS-rendered forms | DOM-first; vision only when DOM insufficient | <1s gatekeeper |
| Computer-use (PC-002, opt-in) | Per-window observation | Reasoner, screen-capture permissioned | 1.5–3s, user-approved |

Vision is **never** on the critical path of text routing. Text-only intents never load a VLM.

## 2. The Tiered VLM Strategy (8GB contract)

Do NOT load one big VLM. Three cooperating layers:

```
Layer 1  GATEKEEPER   Florence-2-Large (0.77B) or SmolVLM-500M  → <1s
         bounding boxes + raw OCR + coarse page purpose
Layer 2  REASONER     Qwen2-VL-2B (int4) or moondream2          → 1.5–3s
         ONLY when gatekeeper reports ambiguity/error state
Layer 3  DOM ANCHOR   accessibility tree + ref_id              → <5ms
         THE execution layer; vision coordinates are hints
```

Rules:
1. **Gatekeeper first, always.** It is fast, tiny (~0.8–1.5GB), and answers 80% of "what is on screen" questions.
2. **Reasoner is conditional.** Invoked only on ambiguity (unlabelled icon, error state, form state). Loading it is a router decision (ROUTING_SPEC §2 E4 — capability gap) and it unloads after use (ram_manager).
3. **DOM is truth.** Every click/fill/assert resolves through the accessibility tree. Vision never produces an executable action directly.
4. **FMF vision when available** (Apple FMF, ANE-accelerated, <0.5s) supersedes Layer 1 for supported hardware; the same gatekeeper contract applies.
5. **Never both VLMs resident.** Gatekeeper and reasoner are mutually exclusive resident loads on the 8GB floor.

## 3. Capture & Memory Integration (reduction-first)

1. **Screenshots never saved.** The wisp pipeline: capture frame → gatekeeper OCR/extract → **discard pixels** → store text/claims with provenance. The image exists only in memory during extraction (Rewisp's "screenshots never touch disk").
2. **Kill-list parity:** messages, password managers, banking, private windows — vision capture fully pauses (VISION inherits MEMORY_ARCHITECTURE_SPEC §5.2).
3. **PII strip:** credential-shaped text from OCR (cards, SSNs) is removed before storage or indexing — same pipeline as DOM text.
4. **What is stored:** extracted text → Capture node; detected claims → Claim nodes with the source URL + `capture_method: "vision"`; coordinates/boxes are never persisted (they're hints, not memory).
5. **User-saved screenshots** (deliberate capture, e.g., annotate-and-share) are the exception: they become media Artifacts with explicit retention (user-initiated = retained until user deletes).
6. **Private-mode guard:** private content is never vision-captured without explicit opt-in + label.

## 4. Latency & Resource Budget

| Operation | Model | TTFT | Total | RAM peak |
|---|---|---|---|---|
| Page screenshot classify (gatekeeper) | SmolVLM-500M/Florence-2 | <300ms | <1s | ~0.6–1.0 GB |
| OCR a saved image (gatekeeper) | Florence-2-Large | <400ms | 0.8–1.5s | ~1.0 GB |
| Ambiguous-state resolve (reasoner) | Qwen2-VL-2B int4 | <800ms | 1.5–3s | ~2.0–2.5 GB |
| FMF vision | Apple ANE | <200ms | <0.5s | native |
| DOM query (no VLM) | n/a | <5ms | <5ms | 0 |

- Batch OCR/analysis at idle (battery/thermal-aware) — never during active typing.
- Prefix-cache the gatekeeper prompt template (fixed instruction prefix).
- If RAM < floor at vision time, the router **defer**s vision work (queue with explicit notice) rather than evicting a text Cell (ram_manager priority).

## 5. Eval Hooks

- **Ground-truth integrity:** every vision-derived action in the eval suite resolves via DOM refs; zero tests assert pixel coordinates as the execution contract.
- **OCR fidelity:** fixture corpus (rendered pages, PDFs, screenshots) — string accuracy ≥ 98% on gatekeeper paths.
- **Reduction invariant:** after any vision capture, zero image files exist in storage (fixture-based assertion).
- **PII absence:** credential-shaped OCR output absent from stored nodes (fixture sweep).
- **Latency SLOs:** §4 table on M1 8GB, cold + warm.
- **Kill-list/privacy:** vision capture never fires on kill-list hosts or private windows; denial paths tested.
