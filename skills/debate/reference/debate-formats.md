# Debate Format Reference

## Format Selection Criteria

| Paper Count | Format | Rationale |
|-------------|--------|-----------|
| 2-3 | Free-For-All (FFA) | Small enough for all agents to engage directly |
| 4-6 | FFA + Panel Judges | Need multiple judges for fairness at this scale |
| 7+ | Bracket → FFA Finals | Too many agents for single arena; bracket narrows field |

## Free-For-All (FFA)

All paper agents debate in a single arena simultaneously.

**Structure:**
- All agents receive the same debate round prompt
- Any agent can respond to any other agent (not locked to pairs)
- Exchanges are broadcast to all participants via SendMessage
- Judges observe all exchanges before scoring

**Round flow:**
1. Opening: Each agent advocates for their top hypothesis
2. Challenge: Agents challenge each other's claims
3. Rebuttal: Agents respond to challenges
4. (Optional) Synthesis: Agents propose combined positions

**Best for:** 2-3 papers, focused topics, exploring depth

## FFA with Panel Judges

Same as FFA but with multiple independent judges for reliability.

**Structure:**
- Same debate flow as FFA
- 2+ judges score independently
- Judges reconcile scores after independent scoring
- Consensus scores require agreement or documented disagreement

**Judge Reconciliation Protocol:**
1. Each judge submits independent scores
2. For scores within 2 points: average them
3. For scores >2 points apart: judges discuss via SendMessage
4. Must reach consensus or document the specific disagreement
5. If deadlocked: use the more conservative (lower) score

**Best for:** 4-6 papers, complex topics, high stakes

## Bracket Rounds → FFA Finals

Papers compete in smaller groups, winners advance to a final FFA.

**Structure:**
- Round 1: Papers grouped into brackets of 2-3
  - Group papers by topic similarity or contrasting methodology
  - Each bracket debates independently
  - Top 1-2 hypotheses per bracket advance
- Round 2+: Advancing hypotheses compete in FFA format
  - May combine brackets as field narrows
- Finals: Top 4-6 hypotheses in single FFA

**Bracket assignment:**
- Maximize diversity within brackets (don't put similar papers together)
- Ensure each bracket has at least 2 papers
- If odd number of papers, one bracket gets an extra

**Best for:** 7+ papers, broad topics, survey-style research

## 1v1 Format (Optional/Manual)

Two papers debate directly on a specific claim.

**Structure:**
- Paper A advocates position
- Paper B challenges
- Paper A rebuts
- Paper B counter-rebuts
- Judge scores

**Best for:** Resolving specific disputed claims between two papers

## Configuration Options
- `--format ffa|bracket|1v1`: Override automatic format selection
- `--rounds N`: Maximum debate rounds (default: 3)
- `--judges N`: Number of judges (default: 2)
- `--exchanges N`: Exchanges per round (default: 2)
