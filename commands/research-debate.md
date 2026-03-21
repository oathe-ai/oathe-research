---
name: research-debate
description: Start or resume a debate on already-ingested papers. Use after /research-ingest or to resume a paused debate.
argument-hint: --run RUN_ID --rounds 3 --judges 2
    required: false
---

# /research-debate — Debate on Ingested Papers

Dispatch to `skills/debate/SKILL.md`. This command starts or resumes a multi-agent debate on papers that have already been ingested. Use when:
- Papers were ingested separately via `/research-ingest` and the user now wants to debate
- A previous debate was interrupted and the user wants to resume
- The user wants to re-run a debate with different parameters on the same papers

## Input Parsing

Parse option flags with these defaults:

| Flag | Default | Description |
|------|---------|-------------|
| `--run ID` | latest | Specific run ID to use (e.g., `run_20260304_143022`) |
| `--rounds N` | 3 | Maximum number of debate rounds |
| `--format` | auto | Debate format: `ffa`, `bracket`, or `1v1` |
| `--judges N` | 2 | Number of judge agents |

## Execution

### Step 1: Locate Run

**If `--run` is provided:**
- Verify `docs/oathe/runs/{RUN_ID}/papers/manifest.json` exists
- Verify at least 2 papers have `"status": "ingested"` in the manifest
- Read the manifest to confirm paper availability

**If `--run` is not provided:**
- Scan `docs/oathe/runs/` for the most recent run directory (sorted by timestamp in the run ID)
- Check each for a valid `papers/manifest.json` with at least 2 ingested papers
- Use the most recent qualifying run
- If no qualifying run is found, tell the user to run `/research-ingest` first

### Step 2: Check for Existing Debate State

Look for existing debate data in the run directory:
- If `debates/final-results.json` exists: the debate already completed. Ask the user if they want to re-run with fresh parameters or view existing results.
- If `debates/round-N/` directories exist but no final results: offer to resume from the last completed round.
- If no debate data exists: start a fresh debate.

### Step 3: Update Run Config

Update `docs/oathe/runs/{RUN_ID}/_meta/run-config.json` with debate parameters:
- `max_rounds`, `debate_format`, `judges`
- `timestamp_debate_start`

### Step 4: Invoke Debate Skill

Dispatch the `research-debate` skill (from `skills/debate/SKILL.md`) with:
- The RUN_ID
- `--format`, `--rounds`, `--judges` settings

The debate skill handles everything from here:
- Spawning paper agents (one per ingested paper) and judge agents
- Hypothesis generation with mandatory claim verification
- Debate rounds with argumentation, scoring, and hypothesis advancement
- Between-round hypothesis evolution (via `skills/evolve/SKILL.md`)
- Convergence detection and user checkpoints every 2 rounds

### Step 5: Post-Debate Synthesis

After the debate converges, invoke the `research-synthesize` skill (from `skills/synthesize/SKILL.md`) to produce the final synthesis.

Present the results to the user:
1. The top 3-5 ranked hypotheses with confidence levels
2. A brief summary of consensus points and key disputes
3. The path to the full synthesis directory
4. Total debate rounds completed and hypotheses evaluated

## Error Handling

- **No ingested papers found**: Direct the user to run `/research-ingest` first.
- **Only 1 paper ingested**: A debate requires at least 2 papers. Ask the user to ingest more via `/research-ingest`.
- **Resumption conflict**: If resuming and the user's parameters differ from the original run config, warn about potential inconsistency and ask for confirmation before proceeding.
- **Debate interrupted**: State is saved per-round. The user can re-run this command to resume from the last completed round.
