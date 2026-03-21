---
name: research-evolve
description: "Use when evolving hypotheses between debate rounds. Manages hypothesis recombination, evidence gap identification, convergence detection, and optional new paper ingestion. Triggered between debate rounds by the debate orchestrator."
---

# Research Evolve Skill

## Purpose

Between debate rounds, this skill evolves the hypothesis pool — combining complementary ideas, strengthening survivors with debate insights, pruning the defeated, and identifying evidence gaps that may warrant new paper ingestion.

## Inputs

The evolver receives the following from the debate orchestrator:

1. **Winning hypotheses from the last round** — each with its credibility-weighted score and supporting evidence citations.
2. **Interesting losers** — hypotheses that scored well but didn't advance. These may contain partial insights worth recombining.
3. **Debate transcripts from the round** — full exchange records including advocate arguments, challenger rebuttals, and judge reasoning.
4. **Paper summaries** — summary.json for every paper in the run (from `docs/oathe/runs/{RUN_ID}/papers/`).
5. **Previous evolution history** — if this is not the first evolution, all prior `evolved-r{N}.json` and `evolution-reasoning-r{N}.md` files.

## Evolution Operations

### 1. COMBINE

Identify complementary hypotheses from different papers. Look for:

- Hypotheses that address **different aspects of the same phenomenon** (e.g., one explains the mechanism, another predicts the boundary conditions).
- Hypotheses where **one's evidence fills the other's gap** (e.g., Paper A claims X but lacks experimental support; Paper B has the experiment but frames it differently).
- Synthesis must be **grounded in evidence from BOTH papers** — no speculative bridges. Every claim in the combined hypothesis must trace to a specific section/result in at least one paper.

When combining:
- Assign a new hypothesis ID (H-{N} continuing the sequence).
- Record lineage as both parent hypothesis IDs and their source papers.
- Set evolution_type to "COMBINED".
- The combined hypothesis's confidence should not exceed the lower of the two parents' confidences unless new evidence justifies it.

### 2. STRENGTHEN

Review successful rebuttals and exchanges from the debate. Incorporate:

- **Counterargument handling** — if a hypothesis survived a challenge by incorporating a qualification or caveat, bake that into the evolved statement.
- **Additional evidence discovered during debate** — sometimes an advocate cites evidence from a paper that wasn't in the original hypothesis. Add these citations.
- **Refined scope/qualifications** — if the debate revealed that a hypothesis only holds under certain conditions, narrow the claim accordingly.

When strengthening:
- Keep the same hypothesis ID lineage but mark evolution_type as "STRENGTHENED".
- Document exactly what changed and why in the reasoning file.

### 3. IDENTIFY GAPS

Systematically review the debate for missing evidence:

- **Thin winners** — claims that won but had thin evidence (scored well on logic/novelty but low on evidence quality).
- **Unanswered questions** — questions raised during debate exchanges that no paper could answer.
- **Methodological blind spots** — are all papers using the same methodology? Same datasets? Same assumptions? Note what alternative approaches are missing.

Each gap should be recorded with:
- What specific evidence is needed.
- Which hypothesis/hypotheses it would affect.
- How confident we'd become if the evidence were found.
- A suggested search query for finding relevant papers.

### 4. NEW PAPER REQUEST (capped at 3 total across all rounds)

When a critical evidence gap is found and the remaining budget allows:

1. Formulate a targeted search query based on the identified gap.
2. Use `mcp__semantic-scholar__search_papers` to find candidates.
3. Check abstracts via `mcp__arxiv-latex__get_paper_abstract` for the top candidates.
4. **Present candidates to the user for approval — NEVER auto-ingest.**
5. If the user approves a paper, trigger the `research-ingest` skill for that paper.
6. The new paper's hypotheses enter the pool in the next round.

Budget tracking:
- Track total papers requested across ALL rounds in the run metadata.
- Display remaining budget in each evolution report.
- If budget is exhausted, still identify the gaps but note that no more papers can be fetched.

### 5. PRUNE

Remove hypotheses that:

- Were **decisively refuted with evidence** — a challenger presented concrete counter-evidence that the advocate could not address.
- **Failed to defend against challenges** — scored poorly on counter-argument handling across multiple exchanges.
- Are **subsumed by a stronger evolved hypothesis** — if H-1 and H-3 were combined into H-5, and H-5 is strictly stronger, prune the parents (unless they contain independent claims not captured in the combination).

When pruning:
- Record the hypothesis ID, the reason for pruning, and which round it was eliminated in.
- Pruned hypotheses are never re-introduced (they remain in the historical record but don't re-enter the pool).

## Convergence Detection

After each evolution round, calculate convergence metrics:

1. **Score delta**: For each of the top-3 hypotheses, compute `|score_this_round - score_last_round|`.
2. **Convergence check**:
   - If ALL top-3 deltas < 0.5 → **recommend convergence** (hypotheses are stable, further debate unlikely to change rankings).
   - If max rounds reached (as configured in run.json) → **forced convergence** regardless of deltas.
   - Otherwise → **continue** to next round.
3. Report convergence status to the debate orchestrator with:
   - The delta values for each top hypothesis.
   - A recommendation: "continue" or "converge".
   - Reasoning for the recommendation.

## User Gates

### Mandatory Checkpoint (every 2 rounds)

After every 2 completed rounds, present the user with:

- **Current top hypotheses** — statements, scores, and trend (improving/declining/stable).
- **Evolution summary** — what was combined, strengthened, pruned this cycle.
- **Recommended next action** — continue debating, fetch a new paper, or converge.

**Wait for user approval before continuing.** The user may:
- Approve continuation as recommended.
- Override to force convergence early.
- Request a different evolution strategy.
- Add manual hypotheses or observations.

### New Paper Approval

Before any new paper fetch:
- Present the paper title, authors, abstract, and why it's relevant to the evidence gap.
- Wait for explicit user approval.
- If denied, record the gap as unresolved and continue without the paper.

## Output

All outputs are saved to `docs/oathe/runs/{RUN_ID}/evolution/`.

### evolved-r{N}.json

```json
{
  "round": N,
  "evolved_hypotheses": [
    {
      "id": "H-{N}",
      "statement": "...",
      "lineage": ["H-1 (Paper A)", "H-3 (Paper C)"],
      "evolution_type": "COMBINED|STRENGTHENED|NOVEL|SURVIVED",
      "supporting_evidence": [
        {"paper": "...", "section": "...", "detail": "..."}
      ],
      "confidence": 0.0,
      "score_from_last_round": 0,
      "new_evidence_needed": "...",
      "vulnerabilities": ["..."]
    }
  ],
  "pruned": ["H-2 (reason)", "H-4 (reason)"],
  "convergence": {
    "delta": 0.0,
    "recommendation": "continue|converge",
    "reasoning": "..."
  },
  "new_paper_requests": []
}
```

### evolution-reasoning-r{N}.md

A human-readable markdown file documenting:
- The reasoning for each evolution decision (combine, strengthen, prune).
- Why specific gaps were identified.
- Convergence analysis with score trends.
- Any new paper requests and their justification.

This file serves as an audit trail for the evolution process and is consumed by the synthesis skill at the end of the run.
