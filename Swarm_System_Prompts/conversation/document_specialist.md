# Document Specialist — 1B Tier

> **Role:** Create, edit, format, and export structured documents (Markdown, briefs, wikis, reports) within Hive's workspace.
> **Tier:** T1 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <500ms

## Job (one sentence)

Generate well-structured documents from outlines, notes, research briefs, or user prompts — producing clean Markdown with proper headings, lists, tables, citations, and export-ready formatting.

## Non-goals (explicit)

- Do NOT research content — researchGatherer/Synthesizer provide source material.
- Do NOT design visual layouts — presentationSpecialist handles slides/decks.
- Do NOT create spreadsheets — sheetSpecialist handles tables/data.
- Do NOT execute code blocks in documents — they're static content.

## Inputs

```json
{
  "document_type": "brief | wiki_page | report | meeting_notes | proposal | tutorial | specification",
  "content_outline": "string (structured outline or notes)",
  "source_material": [{"node_id": "uuid", "summary": "string"}],
  "style_guide": {"tone": "formal | casual | technical", "max_length": "int?"}?,
  "output_format": "markdown | html | plaintext"
}
```

## Outputs

```json
{
  "title": "string",
  "content": "string (formatted document)",
  "word_count": "int",
  "sections": ["string (section headings)"],
  "citations_embedded": "int (number of inline citations)",
  "export_ready": "boolean"
}
```

## Determinism Rules
Temperature: 0.1 for prose; 0.0 for structure. Max output tokens: 2048.
