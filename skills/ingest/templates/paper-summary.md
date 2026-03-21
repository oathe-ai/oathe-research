# Paper Summary Extraction Template

Extract the following fields into `summary.json` for paper `{ARXIV_ID}`.

## Core Metadata

- `title`: Full paper title exactly as it appears.
- `authors`: Array of author name strings, in publication order. Example: `["Alice Smith", "Bob Jones"]`
- `date`: Publication or preprint date in `YYYY-MM-DD` format. Use the earliest available date (submission date for preprints).
- `arxiv_id`: The arxiv identifier without URL prefix. Example: `"2502.18864"`

## Content Extraction

- `abstract`: Full abstract text, cleaned of LaTeX formatting artifacts.

- `key_claims`: Array of 3-7 key claims extracted from the results and conclusion sections. Each claim must be:
  - A specific, falsifiable statement (not a vague generalization like "our method performs well")
  - Grounded in the paper's data, experiments, or formal analysis
  - Traceable to a specific section of the paper

  Format each claim as:
  ```json
  {
    "claim": "Specific falsifiable statement",
    "evidence_section": "Section name where evidence is found",
    "strength": "strong|moderate|weak"
  }
  ```

  Strength guidelines:
  - `"strong"`: Supported by quantitative results, statistical tests, or formal proofs
  - `"moderate"`: Supported by experimental results without statistical significance testing, or by strong qualitative analysis
  - `"weak"`: Supported by limited experiments, anecdotal evidence, or primarily by argumentation

- `methodology`: 2-4 sentence summary of the paper's approach and methods. Include the type of study (empirical, theoretical, survey, etc.), key techniques used, and datasets or domains involved.

- `results_summary`: 2-4 sentence summary of key results. Include specific quantitative data where available (accuracy percentages, improvement margins, statistical measures). Do not just say "results show improvement" -- include the numbers.

- `limitations`: Array of limitation strings. Include:
  1. Limitations explicitly stated by the authors
  2. Any obvious limitations you identify (e.g., small dataset, narrow domain, missing baselines, no ablation study)

## Section Index

- `sections_index`: Array recording paper structure, derived from `list_paper_sections` output.
  ```json
  { "name": "introduction", "available": true }
  ```
  Mark `"available": false` for standard sections (introduction, methods, results, conclusion) that the paper does not have. This index enables on-demand section retrieval during downstream debate stages.

## JSON Schema

The complete `summary.json` must conform to this schema:

```json
{
  "arxiv_id": "string",
  "title": "string",
  "authors": ["string"],
  "date": "string (YYYY-MM-DD)",
  "abstract": "string",
  "key_claims": [
    {
      "claim": "string",
      "evidence_section": "string",
      "strength": "strong | moderate | weak"
    }
  ],
  "methodology": "string",
  "results_summary": "string",
  "limitations": ["string"],
  "sections_index": [
    {
      "name": "string",
      "available": "boolean"
    }
  ],
  "credibility": {
    "status": "scored | insufficient_data",
    "recency_score": "number | null",
    "citation_count": "number | null",
    "citation_context": "string | null",
    "author_h_indices": ["number"] ,
    "avg_h_index": "number | null",
    "venue": "string | null",
    "venue_tier": "top_tier | respected | preprint | other | null",
    "reproducibility": {
      "has_code": "boolean",
      "has_data": "boolean",
      "peer_reviewed": "boolean"
    },
    "composite_score": "number | null",
    "flags": ["string"]
  }
}
```
