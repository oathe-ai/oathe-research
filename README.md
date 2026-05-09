# Oathe Research -- AI Co-Scientist Debate Plugin

Oathe Research is a Claude Code plugin that orchestrates multi-agent debates on arxiv papers to generate, challenge, and evolve research hypotheses. Inspired by Google's AI Co-Scientist paper: ingest literature, generate hypotheses, run structured debates between agents, evolve the strongest ideas, and synthesize final outputs.

## Prerequisites

- **uv** -- Python package manager ([install](https://docs.astral.sh/uv/getting-started/installation/))
- **Python 3.11+**
- **arxiv-latex-mcp** -- MCP server for fetching and parsing arxiv papers (included under `mcp/`)
- **Semantic Scholar API key** -- Set `SEMANTIC_SCHOLAR_API_KEY` environment variable ([get one here](https://www.semanticscholar.org/product/api))
- **jq** (optional) -- used by run-state management scripts; falls back to Python if unavailable

## Quick Start

```
/research "transformer scaling laws"
```

This single command runs the full pipeline: ingesting relevant papers, generating hypotheses, debating them across agents, evolving the winners, and producing a synthesized research brief.

## Available Commands

| Command | Description |
|---------|-------------|
| `/research "<topic>"` | Run the full pipeline end-to-end |
| `/research-ingest "<topic>"` | Ingest and summarize papers only |
| `/research-debate "<topic>"` | Run debate rounds on existing hypotheses |

## Pipeline Stages

```
Ingest --> Generate --> Debate --> Evolve --> Synthesize
```

1. **Ingest** -- Fetches papers from arxiv and Semantic Scholar, extracts key claims, methods, and findings.
2. **Generate** -- Produces initial research hypotheses grounded in the ingested literature.
3. **Debate** -- Multiple agents argue for and against each hypothesis using structured debate protocols.
4. **Evolve** -- Winning hypotheses are refined, combined, or extended based on debate outcomes.
5. **Synthesize** -- Final research brief with ranked hypotheses, supporting evidence, and open questions.

## Output Artifacts

Each pipeline run produces artifacts under `docs/oathe/runs/<RUN_ID>/`:

```
docs/oathe/runs/<RUN_ID>/
  _meta/
    run.json                    # Run metadata, state, config
  papers/
    <arxiv_id>/summary.json    # Per-paper structured extraction
    manifest.json              # All papers in run
  generation/
    hypotheses-raw.json        # Before verification
    hypotheses-verified.json   # After claim verifier gate
  debates/
    round-1/
      exchanges/               # Debate message transcripts
      scores/                  # Judge scores + consensus
      advancing.json           # Which hypotheses advance
    round-2/ ...
  evolution/
    evolved-r1.json            # Evolved hypothesis pool
    evolution-reasoning-r1.md  # Evolution decision reasoning
  synthesis/
    ranked-hypotheses.md       # Final ranked hypotheses with evidence
    synthesis-report.md        # Consensus, disputes, novel connections
    evolution-log.md           # Round-by-round debate chronicle
```

## Project Structure

```
.claude-plugin/         # Plugin metadata
agents/                 # Agent definitions
skills/
  research/             # Main orchestration skill
  ingest/               # Paper ingestion skill
  debate/               # Structured debate skill
  evolve/               # Hypothesis evolution skill
  synthesize/           # Output synthesis skill
commands/               # Slash command definitions
hooks/                  # Lifecycle hooks
scripts/                # Utility scripts
docs/oathe/runs/        # Pipeline run outputs
```
