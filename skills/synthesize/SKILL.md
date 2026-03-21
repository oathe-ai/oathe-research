---
name: research-synthesize
description: "Use when producing final research synthesis after debate convergence. Dispatches the research-consolidator agent to create ranked hypotheses, synthesis report, and evolution log from all debate data."
---

# Research Synthesize Skill

## Purpose

After the debate process converges (either by stability criteria or max rounds), this skill produces the final research output — a comprehensive synthesis of everything learned during the run.

## Trigger

Called by the main research dispatcher after debate convergence is confirmed. The convergence signal comes from the evolve skill's convergence detection (all top-3 score deltas < 0.5, max rounds reached, or user-forced convergence).

## Pre-Synthesis Data Collection

Before dispatching the consolidator, gather ALL data from the run directory:

```
docs/oathe/runs/{RUN_ID}/
├── papers/          → all summary.json files (paper metadata, credibility scores, key findings)
├── generation/      → initial and verified hypotheses (pre-debate pool)
├── debates/         → all round data:
│   ├── round-{N}/
│   │   ├── exchanges/    → individual debate exchange transcripts
│   │   ├── scores.json   → scoring for each hypothesis
│   │   └── advancing.json → which hypotheses advanced
├── evolution/       → all evolution data:
│   ├── evolved-r{N}.json       → evolved hypothesis pools
│   └── evolution-reasoning-r{N}.md → evolution reasoning
└── _meta/run.json   → run configuration (topic, max rounds, papers list)
```

Collect and organize:
1. **Paper data**: title, arxiv ID, credibility score, key findings for each paper.
2. **Hypothesis lifecycle**: trace each hypothesis from generation through verification, debate rounds, evolution, and final state.
3. **Debate records**: all exchanges, scores, judge reasoning across all rounds.
4. **Evolution records**: all combine/strengthen/prune decisions and their outcomes.
5. **Run metadata**: original research question, configuration parameters, total rounds completed.

## Dispatch

Spawn a `research-consolidator` agent as a **subagent** (not a teammate — this is a one-shot synthesis task).

Pass the consolidator:
- All collected data from above.
- The three output templates (ranked-hypotheses.md, synthesis-report.md, evolution-log.md).
- The run ID and output directory path.

The consolidator is responsible for:
- Analyzing all data holistically.
- Producing the three output artifacts following the templates.
- Computing final statistics and summary metrics.

## Output Artifacts

The consolidator produces 3 files in `docs/oathe/runs/{RUN_ID}/synthesis/`:

### 1. ranked-hypotheses.md

A ranked list of all surviving hypotheses ordered by final credibility-weighted score. For each hypothesis:
- Statement and confidence percentage.
- Final score breakdown (evidence, logic, counter-argument, novelty, credibility adjustment).
- All supporting evidence with specific paper + section citations.
- Challenges survived with brief rebuttal summaries.
- Remaining vulnerabilities and what could disprove it.
- Full lineage from origin through evolution.

Follow the `ranked-hypotheses.md` template.

### 2. synthesis-report.md

The main research output document containing:
- Executive summary (3-5 sentences capturing the most defensible conclusion).
- Research question restated.
- Papers analyzed table with credibility scores and contributions.
- Consensus points across all papers.
- Key disputes with evidence on both sides.
- Novel connections discovered during the debate process.
- Evidence gaps and what experiments would resolve them.
- Recommended next research steps with priorities.
- Methodology notes on how the debate process may have affected outcomes.

Follow the `synthesis-report.md` template.

### 3. evolution-log.md

A complete record of the debate and evolution process:
- Round-by-round timeline with hypotheses entered, key exchanges, scores, and advancement decisions.
- Evolution actions between rounds (combine, strengthen, prune, gaps).
- Hypothesis lineage graph showing how ideas evolved.
- Debate statistics (total rounds, hypotheses generated/eliminated/evolved, exchanges, penalties).
- Papers involved table with contribution tracking.

Follow the `evolution-log.md` template.

## Post-Synthesis

After the consolidator completes:

1. **Verify outputs** — confirm all 3 files exist and are non-empty in the synthesis directory.
2. **Update run state** — set the run status to "COMPLETE" in `_meta/run.json`.
3. **Report completion** to the user with:
   - A brief summary of the top finding (1-2 sentences from the executive summary).
   - The number of hypotheses that survived to final ranking.
   - Paths to all 3 output artifacts.
4. **Present the ranked hypotheses** — show the top 3 hypotheses with their scores and confidence levels directly in the completion message so the user gets immediate value without needing to open files.
