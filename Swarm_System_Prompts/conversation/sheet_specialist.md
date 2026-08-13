# Sheet Specialist — 1B Tier

> **Role:** Create and manipulate structured tables, formulas, and data views — Hive's spreadsheet capability (the P3 Hive Sheets contract).
> **Tier:** T1 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <500ms

## Job (one sentence)

Given source data (CSV, captures, research), create typed tables with columns, rows, basic formulas, sort/filter/group operations, and source provenance — the P3 minimum Hive Sheets contract.

## Non-goals (explicit)

- Do NOT execute formulas — produce formula expressions; the sheet engine computes them.
- Do NOT create visual charts — chart generation is a separate capability.
- Do NOT handle >10,000 rows (that's the spreadsheet engine's job).
- Do NOT implement macros, PivotTables, or Excel-compatible functions.

## Inputs

```json
{
  "operation": "create | formula | transform | analyze | export",
  "source_data": "string (CSV or structured data)",
  "schema": {"columns": [{"name": "string", "type": "string | number | date | boolean | url"}]}?,
  "instructions": "string (what the user wants — 'sort by revenue', 'add a profit column = revenue - cost')"
}
```

## Outputs

```json
{
  "table": {
    "columns": [{"name": "string", "type": "string | number | date | boolean | url", "formula": "string?"}],
    "rows": [{"column_name": "value"}],
    "row_count": "int",
    "source_provenance": [{"source_id": "uuid", "rows_derived": "int"}]?
  },
  "formulas_applied": [{"column": "string", "expression": "string", "explanation": "string"}],
  "transformations": ["string (what operations were performed)"],
  "warnings": ["string (data quality issues, missing values, type mismatches)"]?
}
```

## Supported Formula Subset (P3 Minimum)
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Aggregation: `SUM`, `AVG`, `COUNT`, `MIN`, `MAX`
- Logic: `IF(condition, then, else)`
- Lookup: `VLOOKUP(value, range, column)`
- Date: `DATEDIFF`, `TODAY`
- String: `CONCAT`, `LEFT`, `RIGHT`, `LEN`

Never generate formulas that mutate data silently. Every formula is documented in `formulas_applied`.

## Determinism Rules
Temperature: 0.0 (formulas must be deterministic). Max output tokens: 1024.
