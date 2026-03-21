---
name: research-ingest
description: "Use when ingesting arxiv papers for research analysis. Handles paper fetching, structured extraction, and credibility scoring. Triggered by /research-ingest or as part of the /research pipeline."
---

# Research Ingest Skill

You are performing paper ingestion for the Oathe research pipeline. Your job is to fetch arxiv papers, extract structured information, score their credibility, and produce summary.json files that downstream skills (debate, synthesis) will consume.

## Input Modes

Determine which input mode applies based on what the user provides:

### 1. Explicit IDs
The user provides arxiv IDs directly, e.g. `2502.18864, 2301.12345`.
- Parse comma-separated, space-separated, or newline-separated IDs.
- Strip any leading/trailing whitespace, `arxiv:` prefixes, or URL prefixes (`https://arxiv.org/abs/`).
- Accept IDs with or without version suffixes (e.g. `2502.18864v1` or `2502.18864`).

### 2. Topic Search
The user provides a quoted topic like `"causal reasoning in LLMs"`.
- Use `mcp__semantic-scholar__search_papers` with the topic string as query.
- Request at least 10 results to allow for filtering.
- Select 3-6 papers (unless user specifies a count) using the auto-pick strategy below.

### 3. Auto-Pick Strategy (for Topic Search)
When selecting papers from search results, maximize diversity and analytical value:
- **Temporal mix**: Include both recent papers (last 1-2 years) and established works (3+ years with citations).
- **Research group diversity**: Avoid selecting multiple papers from the same author group or institution.
- **Methodological contrast**: Prefer papers using different approaches (e.g., one empirical, one theoretical, one survey).
- **Viewpoint diversity**: Actively seek papers with contrasting or complementary conclusions.
- **Minimum quality bar**: Skip papers with no abstract, no identifiable authors, or clearly out-of-scope results.

## Extraction Pipeline

Execute the following steps for each paper. Use the RUN_ID provided by the caller (or generate one as `run_YYYYMMDD_HHMMSS` if not provided).

### Step 1: Fetch Paper Structure

```
mcp__arxiv-latex__list_paper_sections(arxiv_id) -> sections list
mcp__arxiv-latex__get_paper_abstract(arxiv_id) -> abstract text
```

Record the sections list. This tells you what section names the paper actually uses.

### Step 2: Extract Key Sections

Fetch content from the most relevant sections. Section names vary across papers, so use the sections list from Step 1 to find the closest matches:

```
mcp__arxiv-latex__get_paper_section(arxiv_id, "introduction")
mcp__arxiv-latex__get_paper_section(arxiv_id, "methods")        # or "methodology", "approach", "model"
mcp__arxiv-latex__get_paper_section(arxiv_id, "results")        # or "experiments", "evaluation"
mcp__arxiv-latex__get_paper_section(arxiv_id, "conclusion")     # or "discussion", "conclusions"
```

Common alternative section names:
- Methods: "methodology", "approach", "proposed method", "model", "framework", "system design"
- Results: "experiments", "evaluation", "experimental results", "empirical results", "analysis"
- Conclusion: "discussion", "conclusions", "concluding remarks", "summary and future work"

Fetch sections in parallel where possible to improve throughput.

### Step 3: Fetch Credibility Data

```
mcp__semantic-scholar__get_paper_details(arxiv_id) -> citations, venue, open access status
mcp__semantic-scholar__get_author_details(author_id) -> h-index, affiliations
```

For author details: fetch for all authors if 3 or fewer, otherwise fetch for the top 3 (first author, last author, and the author with the highest h-index if identifiable).

### Step 4: Build summary.json

Use the **paper-summary.md** template (in `skills/ingest/templates/`) to extract all required fields into a structured JSON object.

Use the **credibility-profile.md** template (in `skills/ingest/templates/`) to compute all credibility scores and assemble the credibility profile.

Combine both into a single `summary.json` file per paper.

### Step 5: Save Outputs

Write the following files:

```
docs/oathe/runs/{RUN_ID}/papers/{arxiv_id}/summary.json
docs/oathe/runs/{RUN_ID}/papers/manifest.json
```

The **manifest.json** tracks all papers in the run:
```json
{
  "run_id": "{RUN_ID}",
  "timestamp": "ISO-8601",
  "paper_count": N,
  "papers": [
    { "arxiv_id": "...", "title": "...", "status": "ingested" | "failed" },
    ...
  ]
}
```

Create directories as needed using `mkdir -p`.

## Error Handling

- **Paper not found in arxiv-latex**: Try both with and without version suffix (e.g. `2502.18864v1` vs `2502.18864`). If both fail, mark the paper as `"failed"` in manifest.json and log the error.
- **Semantic Scholar returns no results**: Still create summary.json, but set `credibility.status` to `"insufficient_data"` and leave score fields as `null`.
- **Section not found**: Skip the section. In the `sections_index` array, set `"available": false` for that section. Do not treat a missing optional section as a fatal error.
- **Rate limiting**: If you hit API rate limits, wait briefly and retry once. If it fails again, proceed with partial data and note the limitation.
- **Malformed LaTeX**: If section content is heavily garbled by LaTeX artifacts, extract what you can and note `"extraction_quality": "partial"` in the summary.

## Output

When ingestion is complete, report to the caller:
1. Number of papers successfully ingested.
2. Number of papers that failed (if any) and why.
3. The path to the manifest.json file.
4. Any notable issues encountered during extraction (missing sections, API failures, etc.).
