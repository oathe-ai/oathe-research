#!/bin/bash
# gate-evolve.sh — PreToolUse(Write) hook
# Blocks advancing.json writes for round N when evolution for round N-1 is missing.
#
# PreToolUse exit codes:
#   0 = allow the tool call
#   2 = block the tool call (stderr becomes feedback to Claude)

set -euo pipefail

# jq guard — cannot enforce without it
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Fast path: only care about advancing.json writes in debate round dirs
if ! echo "$FILE_PATH" | grep -qE '/debates/round-[0-9]+/advancing\.json$'; then
  exit 0
fi

# Extract round number
ROUND=$(echo "$FILE_PATH" | grep -oE 'round-[0-9]+' | grep -oE '[0-9]+')
if [ -z "$ROUND" ]; then
  exit 0
fi

# Round 1 — no prior evolution needed
if [ "$ROUND" -le 1 ]; then
  exit 0
fi

# Derive run directory (parent of debates/)
RUN_DIR=$(echo "$FILE_PATH" | sed 's|/debates/round-.*||')
PREV_ROUND=$((ROUND - 1))
EVOLUTION_FILE="${RUN_DIR}/evolution/evolved-r${PREV_ROUND}.json"

# Check if evolution for previous round exists
if [ -f "$EVOLUTION_FILE" ]; then
  exit 0
fi

# BLOCK — evolution missing
echo "BLOCKED: Cannot write advancing.json for debate round ${ROUND}." >&2
echo "Missing: evolution/evolved-r${PREV_ROUND}.json" >&2
echo "" >&2
echo "You MUST invoke the research-evolve skill for round ${PREV_ROUND} BEFORE" >&2
echo "finalizing round ${ROUND}. The evolve skill will:" >&2
echo "  - Combine complementary hypotheses" >&2
echo "  - Strengthen hypotheses with successful rebuttals" >&2
echo "  - Identify evidence gaps" >&2
echo "  - Prune decisively defeated hypotheses" >&2
echo "  - Check convergence" >&2
echo "" >&2
echo "Run: Skill(skill='oathe-research:evolve') with round ${PREV_ROUND} results." >&2
exit 2
