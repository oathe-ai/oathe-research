---
name: research-ingest
description: Fetch and profile arxiv papers without running a debate. Produces structured summaries with credibility scores.
argument-hint: "transformer scaling laws" or 2502.18864,2301.12345
---

# /research-ingest — Paper Ingestion Only

Dispatch to `skills/ingest/SKILL.md`. This command fetches and profiles arxiv papers without starting a debate. Useful for:
- Pre-loading papers before a debate session
- Reviewing paper summaries and credibility profiles before committing to a full pipeline run
- Building up a paper collection incrementally

## Input Parsing

Parse the `query` argument to determine the input mode:

- **Quoted topic string** (e.g., `"causal reasoning in LLMs"`) — triggers paper discovery via Semantic Scholar
- **Comma-separated arxiv IDs** (e.g., `2502.18864, 2301.12345`) — ingests specific papers directly
- **Mix of both** — search for topic papers AND include the explicit IDs

Parse the optional `--papers N` flag (default: 5) to control how many papers are selected from topic search results. This flag is ignored when only explicit arxiv IDs are provided.

## Execution

### Step 1: Create Run

Generate a run ID as `run_YYYYMMDD_HHMMSS` using the current timestamp.

Create the initial directory structure:
```
docs/oathe/runs/{RUN_ID}/
  papers/
  _meta/
```

Save run configuration to `docs/oathe/runs/{RUN_ID}/_meta/run-config.json`:
```json
{
  "run_id": "{RUN_ID}",
  "topic": "user's query",
  "papers_requested": N,
  "status": "ingestion_only",
  "timestamp_start": "ISO-8601"
}
```

### Step 2: Invoke Ingest Skill

Dispatch the `research-ingest` skill (from `skills/ingest/SKILL.md`) with:
- The parsed query (topic string and/or arxiv IDs)
- The RUN_ID
- The `--papers` count

The ingest skill handles:
- Paper discovery via Semantic Scholar (for topic searches)
- Fetching paper structure and key sections via arxiv-latex MCP
- Credibility profiling (citation count, h-index, methodology rigor, recency)
- Writing summary.json per paper and manifest.json for the run

### Step 3: Report Results

When ingestion completes, show the user:
1. Number of papers successfully ingested (and any failures with reasons)
2. For each paper: title, authors, credibility composite score, and a one-line summary of key findings
3. The path to `docs/oathe/runs/{RUN_ID}/papers/manifest.json`
4. A note that they can run `/research-debate --run {RUN_ID}` to start debating these papers

## Resumability

The output is a fully-formed run directory with ingested papers. The user can later run `/research-debate` pointing to this RUN_ID to start the debate phase without re-ingesting.
