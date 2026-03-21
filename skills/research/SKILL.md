---
name: research
description: "Main AI Co-Scientist pipeline dispatcher. State machine that orchestrates paper ingestion, hypothesis generation, multi-agent debate, hypothesis evolution, and final synthesis. Entry point for /research command."
---

# Research Dispatcher Skill

You are the top-level orchestrator for the Oathe research pipeline. You manage the full lifecycle of a research run: creating the run directory, transitioning through pipeline states, dispatching to sub-skills, handling errors, and supporting resume.

## State Machine

```
INIT --> INGEST --> GENERATE --> DEBATE --> EVOLVE --> SYNTHESIZE --> COMPLETE
  \                                \         \                        /
   `----> ERROR ------------------- `-------- `-----> ERROR ---------'
```

Valid states: `INIT`, `INGEST`, `GENERATE`, `DEBATE`, `EVOLVE`, `SYNTHESIZE`, `COMPLETE`, `ERROR`.

State transitions are recorded via `scripts/update-run-state.sh`. Every transition appends to the `state_history` array in `_meta/run.json` with a UTC timestamp.

## Input Parsing

Parse the user's input to determine:

1. **Query** — a quoted topic string triggers Semantic Scholar search; bare arxiv IDs trigger direct fetch; a mix does both.
2. **Options** — extract from flags or use defaults:

| Option | Flag | Default | Description |
|--------|------|---------|-------------|
| Papers | `--papers N` | 5 | Number of papers to select from topic search |
| Rounds | `--rounds N` | 3 | Maximum debate rounds |
| Format | `--format ffa\|bracket\|1v1` | auto | Debate format override |
| Judges | `--judges N` | 2 | Number of judge agents |

## Pipeline Execution

### Phase 1: INIT

1. Generate a RUN_ID using current UTC time in format `YYYYMMDD-HHMMSS` (e.g., `20260304-143022`).
2. Create the run directory structure:

```
docs/oathe/runs/{RUN_ID}/
  _meta/
  papers/
  generation/
  debates/
  evolution/
  synthesis/
  team/
```

```bash
mkdir -p docs/oathe/runs/{RUN_ID}/{_meta,papers,generation,debates,evolution,synthesis,team}
```

3. Initialize `docs/oathe/runs/{RUN_ID}/_meta/run.json`:

```json
{
  "run_id": "{RUN_ID}",
  "query": "{user query}",
  "state": "INIT",
  "config": {
    "papers": 5,
    "rounds": 3,
    "format": "auto",
    "judges": 2
  },
  "created_at": "{timestamp}",
  "state_history": [{"state": "INIT", "timestamp": "..."}]
}
```

4. Parse command options (`--papers`, `--rounds`, `--format`, `--judges`) and populate the `config` object.
5. Transition state: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} INIT`.

Report to the user: run ID created, configuration summary, and that ingestion is starting.

### Phase 2: INGEST

1. Transition state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} INGEST`.
2. Invoke the **research-ingest** skill (`skills/ingest/SKILL.md`) with:
   - The user's query (topic string or arxiv IDs).
   - The RUN_ID.
   - The `--papers` count (for topic search mode).
3. Wait for ingestion to complete.
4. Verify `docs/oathe/runs/{RUN_ID}/papers/manifest.json` exists and the `papers/` directory has `summary.json` files.
   - If fewer than 2 papers successfully ingested: transition to ERROR, report to user, and suggest adjusting the topic or providing explicit IDs.
   - If some papers failed but 2+ succeeded: continue with available papers and note the failures.
5. Report to the user: number of papers ingested, any failures, and that hypothesis generation is starting.
6. Transition to GENERATE.

### Phase 3: GENERATE

1. Transition state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} GENERATE`.
2. For each ingested paper (from `papers/manifest.json` where `status` is `"ingested"`):
   - Spawn a `research-paper-agent` (via the Agent tool with `subagent_type: research-paper-agent`).
   - Pass the paper's `summary.json` content.
   - Each agent generates 1-3 hypotheses with mandatory claim verification (using the `research-claim-verifier` subagent).
3. Collect all hypotheses from all paper agents.
4. Save raw hypotheses to `docs/oathe/runs/{RUN_ID}/generation/hypotheses-raw.json`.
5. Save verified hypotheses (those that passed claim verification) to `docs/oathe/runs/{RUN_ID}/generation/hypotheses-verified.json`.
6. Report to the user: number of hypotheses generated across all papers.
7. Transition to DEBATE.

### Phase 4: DEBATE

1. Transition state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} DEBATE`.
2. Invoke the **research-debate** skill (`skills/debate/SKILL.md`) with:
   - The RUN_ID.
   - Config: `format`, `judges`, `rounds` from `run.json`.
3. The debate skill handles:
   - Team creation and agent spawning (paper agents, judges, hypothesis evolver).
   - FFA or bracket debate rounds with argument exchanges.
   - Judge scoring and consensus reconciliation per round.
   - Between-round evolution dispatches (Phase 5 below, called by the debate orchestrator).
   - Convergence detection and mandatory user checkpoints every 2 rounds.
4. Wait for the debate to converge or reach max rounds.
5. Transition to SYNTHESIZE.

### Phase 5: EVOLVE (called by debate skill between rounds)

The EVOLVE state is managed by the debate orchestrator, not called directly by this dispatcher. It is documented here for completeness of the state machine.

1. The debate skill transitions state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} EVOLVE`.
2. The debate orchestrator invokes the **research-evolve** skill (`skills/evolve/SKILL.md`) between rounds with:
   - Winning and interesting-loser hypotheses from the completed round.
   - Debate transcripts and scores.
   - Paper summaries and prior evolution history.
3. The evolve skill performs: COMBINE, STRENGTHEN, IDENTIFY GAPS, optional NEW PAPER REQUEST (user-gated, capped at 3 total across all rounds), and PRUNE.
4. Evolved hypotheses are saved to `docs/oathe/runs/{RUN_ID}/evolution/evolved-r{N}.json`.
5. Evolution reasoning is saved to `docs/oathe/runs/{RUN_ID}/evolution/evolution-reasoning-r{N}.md`.
6. If the evolver recommends convergence (score deltas < 0.5 for all top-3 hypotheses), or max rounds reached, the debate skill proceeds to synthesis.
7. Otherwise, the debate skill transitions back to DEBATE state for the next round.

The DEBATE and EVOLVE states alternate. A 3-round run follows this path:
```
INIT -> INGEST -> GENERATE -> DEBATE -> EVOLVE -> DEBATE -> EVOLVE -> DEBATE -> EVOLVE -> SYNTHESIZE
```

### Phase 6: SYNTHESIZE

1. Transition state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} SYNTHESIZE`.
2. Invoke the **research-synthesize** skill (`skills/synthesize/SKILL.md`) with:
   - The RUN_ID.
3. The synthesize skill:
   - Gathers all debate artifacts, evolution records, and paper summaries.
   - Dispatches the `research-consolidator` agent to produce final deliverables.
   - Validates output completeness.
   - Generates `_meta/run-summary.json`.
4. Wait for completion. Verify all three synthesis files exist:
   - `docs/oathe/runs/{RUN_ID}/synthesis/ranked-hypotheses.md`
   - `docs/oathe/runs/{RUN_ID}/synthesis/synthesis-report.md`
   - `docs/oathe/runs/{RUN_ID}/synthesis/evolution-log.md`
5. Transition to COMPLETE.

### Phase 7: COMPLETE

1. Transition state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} COMPLETE`.
2. Present results to the user:
   - Summary of findings: top 3 hypotheses with confidence scores (from `ranked-hypotheses.md`).
   - Paths to all output artifacts.
   - Total papers analyzed, rounds completed, hypotheses generated vs. survived.
3. Provide the full synthesis directory path: `docs/oathe/runs/{RUN_ID}/synthesis/`.
4. Shut down all remaining agents in the team.

## Error Handling and Resume

### Transition to ERROR

When any phase fails critically:

1. Transition state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/update-run-state.sh {RUN_ID} ERROR`.
2. Log error details to `_meta/run.json` — include: which state failed, error message, and timestamp.
3. Report to the user: which phase failed, why, and how to resume.

### Resume from ERROR

When the user resumes a failed run (e.g., `/research --run {RUN_ID}` or `/research-debate --run {RUN_ID}`):

1. Read `docs/oathe/runs/{RUN_ID}/_meta/run.json` to determine the current state and last successful state from `state_history`.
2. Restore the original configuration from `run.json`'s `config` object.
3. Resume from the failed state:
   - **INGEST failed**: Retry ingestion. Papers already ingested (present in `manifest.json` with status `"ingested"`) are skipped.
   - **GENERATE failed**: Re-run hypothesis generation using already-ingested papers.
   - **DEBATE failed**: Resume from the last completed round (check `debates/` for existing round directories).
   - **EVOLVE failed**: Re-run evolution for the current round using existing debate data.
   - **SYNTHESIZE failed**: Re-run synthesis using all available debate and evolution data.

### Partial Recovery

If a phase partially succeeds:
- **Partial ingest** (2+ papers OK): Continue with available papers; log failures.
- **Partial debate round** (some agents failed): Continue with remaining agents if 2+ are still active.
- **Partial synthesis**: Retry the consolidator once; if still failing, produce minimal output from available scores.

## User Checkpoints

The pipeline pauses for user input at these points:

1. **After INGEST**: Report papers found, ask to proceed or adjust.
2. **Every 2 debate rounds**: Mandatory checkpoint with current standings and recommendation (continue/converge).
3. **New paper requests**: Evolver may request up to 3 additional papers across the run. Each requires explicit user approval.
4. **Before SYNTHESIZE**: Confirm the user wants to finalize (in case they want more rounds).

## Run Directory Layout

```
docs/oathe/runs/{RUN_ID}/
  _meta/
    run.json              # State machine state + config + state_history
    run-summary.json      # Final summary (created at COMPLETE)
  papers/
    manifest.json         # Paper roster with ingest status
    {arxiv_id}/
      summary.json        # Per-paper structured summary + credibility
  generation/
    hypotheses-raw.json   # All generated hypotheses before verification
    hypotheses-verified.json  # Hypotheses that passed claim verification
  debates/
    round-{N}/
      exchanges/          # Debate transcripts
      scores/
        judge-{N}-scores.md
        consensus-scores.md
      advancing.json      # Hypotheses advancing to next round
    final-results.json    # Final debate outcomes
  evolution/
    evolved-r{N}.json     # Evolved hypotheses per round
    evolution-reasoning-r{N}.md  # Human-readable reasoning
  synthesis/
    ranked-hypotheses.md  # Final ranked hypothesis list
    synthesis-report.md   # Full synthesis with evidence analysis
    evolution-log.md      # Round-by-round evolution narrative
  team/                   # Team coordination artifacts
```
