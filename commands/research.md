---
name: research
description: Run the full AI Co-Scientist research pipeline — ingest papers, generate hypotheses, debate, evolve, and synthesize results.
argument-hint: "causal reasoning in LLMs" --papers 5 --rounds 3
---

# /research — Full AI Co-Scientist Pipeline

Dispatch to the `research/SKILL.md` state machine. This command runs the complete pipeline: paper ingestion, hypothesis generation, multi-agent debate, hypothesis evolution, and final synthesis.

## Input Parsing

Parse the `query` argument to determine the input mode:

- **Quoted topic string** (e.g., `"causal reasoning in LLMs"`) — triggers paper discovery via Semantic Scholar, then ingestion
- **Comma-separated arxiv IDs** (e.g., `2502.18864, 2301.12345`) — ingests specific papers directly
- **Mix of both** (e.g., `"attention mechanisms" 2502.18864`) — search for topic papers AND include the explicit IDs

Parse option flags with these defaults:

| Flag | Default | Description |
|------|---------|-------------|
| `--papers N` | 5 | Number of papers to select from topic search results |
| `--rounds N` | 3 | Maximum number of debate rounds |
| `--format` | auto | Debate format: `ffa`, `bracket`, or `1v1` (auto selects based on paper count) |
| `--judges N` | 2 | Number of judge agents |

## Pipeline Execution

### Step 1: Create Run

Generate a run ID as `run_YYYYMMDD_HHMMSS` using the current timestamp.

Create the run directory structure:
```
docs/oathe/runs/{RUN_ID}/
  papers/
  debates/
  evolution/
  _meta/
  synthesis/
```

Save run configuration to `docs/oathe/runs/{RUN_ID}/_meta/run-config.json`:
```json
{
  "run_id": "{RUN_ID}",
  "topic": "user's query",
  "papers_requested": N,
  "max_rounds": N,
  "debate_format": "auto|ffa|bracket|1v1",
  "judges": N,
  "timestamp_start": "ISO-8601"
}
```

### Step 2: Ingest Papers

Invoke the `research-ingest` skill (from `skills/ingest/SKILL.md`) with:
- The parsed query (topic string and/or arxiv IDs)
- The RUN_ID
- The `--papers` count (for topic search mode)

Wait for ingestion to complete. Report the number of papers ingested and any failures. Minimum 2 successfully ingested papers required to proceed to debate.

### Step 3: Run Debate

Invoke the `research-debate` skill (from `skills/debate/SKILL.md`) with:
- The RUN_ID
- `--format`, `--rounds`, `--judges` settings

The debate skill handles:
- Spawning paper agents (one per paper) and judge agents
- Hypothesis generation with mandatory claim verification
- Debate rounds with argumentation, scoring, and hypothesis advancement
- Between-round hypothesis evolution (via `skills/evolve/SKILL.md`)
- Convergence detection and user checkpoints every 2 rounds

### Step 4: Synthesize Results

After debate convergence (or max rounds reached), invoke the `research-synthesize` skill (from `skills/synthesize/SKILL.md`) with:
- The RUN_ID

This dispatches the `research-consolidator` agent to produce:
- `synthesis/ranked-hypotheses.md` — all hypotheses ranked by final adjusted score
- `synthesis/synthesis-report.md` — executive summary, consensus, disputes, novel connections
- `synthesis/evolution-log.md` — round-by-round chronicle with hypothesis lineage

### Step 5: Present Results

Show the user:
1. The top 3-5 ranked hypotheses with confidence levels
2. A brief summary of consensus points and key disputes
3. The path to the full synthesis directory for detailed review
4. Total papers analyzed, debate rounds completed, and hypotheses evaluated

## Error Recovery

- **All papers fail ingestion**: Abort and report the issue. Suggest checking arxiv IDs or broadening the topic.
- **Partial ingestion failure**: Continue with successfully ingested papers (minimum 2 required).
- **Debate fails mid-round**: Save state and inform the user they can resume with `/research-debate --run {RUN_ID}`.
- **Synthesis fails**: Retry once. If it fails again, offer partial results from the debate scores.
