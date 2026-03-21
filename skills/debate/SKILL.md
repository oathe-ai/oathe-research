---
name: research-debate
description: "Use when orchestrating multi-agent research debates. Manages Agent Teams creation, paper agent dispatch, debate rounds, judge scoring, and hypothesis advancement. Core of the AI Co-Scientist system."
---

# Research Debate Skill

Orchestrates structured multi-agent debates between paper agents to evaluate, refine, and advance research hypotheses through adversarial argumentation and empirical scoring.

## Pre-Debate Setup

### 1. Load Context

Read all paper summaries from `docs/oathe/runs/{RUN_ID}/papers/` — each paper's `summary.json` contains the structured summary and credibility profile.

Read verified hypotheses from `docs/oathe/runs/{RUN_ID}/generation/hypotheses-verified.json` — this is the starting hypothesis pool.

### 2. Determine Debate Format

Select format based on paper count (see `reference/debate-formats.md` for full details):

| Paper Count | Format |
|-------------|--------|
| 2-3 | Free-For-All (FFA) — all agents in one arena |
| 4-6 | FFA with Panel Judges — 2 judges, reconcile scores |
| 7+ | Bracket Rounds → FFA Finals |

Override with `--format ffa|bracket|1v1` if specified.

### 3. Create the Agent Team

```
TeamCreate("oathe-research-{RUN_ID}")
```

## Team Composition

Spawn teammates via the Agent tool:

- **Paper Agents**: One `research-paper-agent` per paper, named `paper-agent-{N}` (e.g., `paper-agent-1`, `paper-agent-2`, ...)
- **Judges**: Number of `research-debate-judge` agents based on `--judges` option (default: 2), named `judge-{N}`
- **Hypothesis Evolver**: One `research-hypothesis-evolver`, named `hypothesis-evolver`

## Dispatch Protocol

### Paper Agent Dispatch

Each paper agent receives its dispatch prompt (from `templates/paper-agent-dispatch.md`) containing:

- The paper's `summary.json` content
- Its credibility profile
- The current hypothesis pool
- Instructions for this debate round

### Judge Dispatch

Each judge receives its dispatch prompt (from `templates/judge-dispatch.md`) containing:

- The scoring rubric (from `reference/scoring-rubric.md`)
- Anti-rhetoric rules (from `reference/anti-rhetoric-rules.md`)
- All paper credibility profiles (for credibility weighting)
- Output path for scores

## Hypothesis Generation Phase (Round 0)

1. Send each paper agent a message to generate 1-3 hypotheses from their paper
2. Each agent MUST spawn a `research-claim-verifier` subagent before submitting any hypothesis
3. Collect verified hypotheses from all paper agents
4. Save to `docs/oathe/runs/{RUN_ID}/generation/hypotheses-verified.json`

## FFA Debate Round Flow

For each round N:

### Step 1: Broadcast Round Prompt
Send the round prompt (from `templates/debate-round-prompt.md`) to all paper agents via `SendMessage`.

### Step 2: Agent Arguments
Paper agents broadcast their arguments advocating for their hypotheses. Any paper agent can challenge, support, or synthesize with any other.

### Step 3: Exchange Cycles
The debate proceeds for a set number of exchanges (default: 2 exchanges per agent per round).

### Step 4: Judge Scoring
After exchanges complete, send scoring request to judges. Judges score independently, writing to:
```
docs/oathe/runs/{RUN_ID}/debates/round-{N}/scores/judge-{JUDGE_N}-scores.md
```

### Step 5: Score Reconciliation
If multiple judges: judges reconcile scores via `SendMessage` to each other. Consensus scores written to:
```
docs/oathe/runs/{RUN_ID}/debates/round-{N}/scores/consensus-scores.md
```

### Step 6: Advance Hypotheses
Lead collects results, determines which hypotheses advance. Save advancing hypotheses to:
```
docs/oathe/runs/{RUN_ID}/debates/round-{N}/advancing.json
```

## Between Rounds

1. Send `hypothesis-evolver` the round results (advancing hypotheses, scores, key arguments)
2. Evolver produces evolved hypotheses for next round (merges, refinements, new angles)
3. Save evolved hypotheses to `docs/oathe/runs/{RUN_ID}/evolution/`

## Convergence Check

After each round, check for convergence:

- **Score Delta Convergence**: If top hypothesis scores delta < 0.5 between rounds, converge
- **Max Rounds**: If max rounds reached (default: 3), converge
- **User Checkpoint**: Every 2 rounds, mandatory user checkpoint — pause and ask user whether to continue

## Debate Transcript Storage

Save all `SendMessage` exchanges to:
```
docs/oathe/runs/{RUN_ID}/debates/round-{N}/exchanges/
```

Each exchange is stored as a timestamped file with sender, recipient, and content.

## Shutdown Protocol

When debate converges:

1. Send `shutdown_request` to all paper agents
2. Send `shutdown_request` to all judges
3. Keep `hypothesis-evolver` alive ONLY if more rounds may happen
4. Compile final results to `docs/oathe/runs/{RUN_ID}/debates/final-results.json`

## Output Structure

```
docs/oathe/runs/{RUN_ID}/
├── debates/
│   ├── round-1/
│   │   ├── exchanges/          # All SendMessage transcripts
│   │   ├── scores/
│   │   │   ├── judge-1-scores.md
│   │   │   ├── judge-2-scores.md
│   │   │   └── consensus-scores.md
│   │   └── advancing.json      # Hypotheses advancing to next round
│   ├── round-2/
│   │   └── ...
│   └── final-results.json
├── evolution/                   # Evolved hypotheses between rounds
└── generation/
    └── hypotheses-verified.json # Initial hypothesis pool
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `--format` | auto | Override format: `ffa`, `bracket`, `1v1` |
| `--rounds` | 3 | Maximum debate rounds |
| `--judges` | 2 | Number of judge agents |
| `--exchanges` | 2 | Exchange cycles per round |
