# Ranked Hypotheses — {RUN_ID}

> Generated after {TOTAL_ROUNDS} rounds of structured debate across {TOTAL_PAPERS} papers.

---

## Format per Hypothesis

### H-{RANK}: {HYPOTHESIS_STATEMENT} — Confidence: {X}%

**Final Score:** {ADJUSTED_SCORE}/40

| Dimension | Score | Notes |
|-----------|-------|-------|
| Evidence Quality | {X}/10 | {brief note} |
| Logical Coherence | {X}/10 | {brief note} |
| Counter-argument Handling | {X}/10 | {brief note} |
| Novelty/Insight | {X}/10 | {brief note} |
| Credibility Adjustment | {+/-X} | Based on source paper credibility |

**Supporting Evidence:**
- [{PAPER_TITLE}] Section {X}: {specific evidence quote or summary}
- [{PAPER_TITLE}] Section {Y}: {specific evidence quote or summary}
- ... (list ALL supporting evidence from debate — every citation that was used to defend this hypothesis)

**Survived Challenges:**
- Challenge from {PAPER_AGENT}: {brief challenge description} -> Rebuttal: {how it was defended}
- ... (list all challenges this hypothesis survived across all rounds)

**Remaining Vulnerabilities:**
- {What evidence could disprove this hypothesis}
- {What conditions might not hold}
- {Methodological limitations}

**Lineage:**
- Origin: {which paper, which round, original statement}
- Evolution: {how it changed through rounds, e.g., "Combined with H-3 in Round 2, strengthened after addressing X in Round 3"}
- Final form: {if the statement changed from origin, note the key differences}

---

{REPEAT FOR EACH SURVIVING HYPOTHESIS, ordered by final credibility-weighted score descending}

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total hypotheses generated | {N} |
| Hypotheses after verification | {N} |
| Hypotheses entering debate | {N} |
| Hypotheses after debate | {N} |
| Final ranked hypotheses | {N} |
| Highest confidence | {X}% |
| Lowest confidence (surviving) | {X}% |
| Average confidence | {X}% |
| Median confidence | {X}% |

## Score Distribution

| Score Range | Count |
|-------------|-------|
| 35-40 (Exceptional) | {N} |
| 30-34 (Strong) | {N} |
| 25-29 (Moderate) | {N} |
| 20-24 (Weak) | {N} |
| Below 20 (Eliminated) | {N} |
