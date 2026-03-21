#!/bin/bash
# enforce-evolve-on-stop.sh — Stop hook
# Blocks session exit if debate rounds completed without corresponding evolutions.
#
# Stop exit codes:
#   0 = allow stop
#   2 = block stop (force continuation, stderr becomes feedback)

set -euo pipefail

# jq guard
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)

# Prevent infinite loop (hooks guide pattern)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Only enforce if research is actively running (marker file)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="${PROJECT_DIR}/.oathe-research-active"
if [ ! -f "$MARKER" ]; then
  exit 0
fi

# Find runs directory
RUNS_DIR="${PROJECT_DIR}/docs/oathe/runs"
if [ ! -d "$RUNS_DIR" ]; then
  exit 0
fi

# Find the most recent run directory
LATEST_RUN=$(ls -1dt "${RUNS_DIR}"/*/ 2>/dev/null | head -1)
if [ -z "$LATEST_RUN" ]; then
  exit 0
fi

# Staleness check — if run metadata older than 2 hours, treat as abandoned
RUN_JSON="${LATEST_RUN}_meta/run.json"
if [ ! -f "$RUN_JSON" ]; then
  exit 0
fi

if command -v stat &>/dev/null; then
  # macOS stat
  MTIME=$(stat -f %m "$RUN_JSON" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$(( NOW - MTIME ))
  if [ "$AGE" -gt 7200 ]; then
    # Run is stale (>2hr) — allow stop
    exit 0
  fi
fi

# Check current state — only enforce during DEBATE or EVOLVE
STATE=$(jq -r '.state // empty' "$RUN_JSON" 2>/dev/null)
if [ "$STATE" != "DEBATE" ] && [ "$STATE" != "EVOLVE" ]; then
  exit 0
fi

# Count completed debate rounds (dirs with advancing.json)
DEBATE_ROUNDS=$(find "${LATEST_RUN}debates/" -name "advancing.json" 2>/dev/null | wc -l | tr -d ' ')

# Count completed evolutions
EVOLUTION_ROUNDS=$(find "${LATEST_RUN}evolution/" -name "evolved-r*.json" 2>/dev/null | wc -l | tr -d ' ')

# With N debate rounds, we need N-1 evolutions (between each pair)
EXPECTED=$(( DEBATE_ROUNDS - 1 ))
if [ "$EXPECTED" -lt 0 ]; then
  EXPECTED=0
fi

if [ "$DEBATE_ROUNDS" -gt 1 ] && [ "$EVOLUTION_ROUNDS" -lt "$EXPECTED" ]; then
  MISSING=$(( EXPECTED - EVOLUTION_ROUNDS ))
  echo "BLOCKED: Cannot stop — ${DEBATE_ROUNDS} debate round(s) completed but only ${EVOLUTION_ROUNDS} evolution(s) found (expected ${EXPECTED})." >&2
  echo "${MISSING} evolution round(s) are missing." >&2
  echo "" >&2
  echo "Invoke the research-evolve skill for each missing round before stopping." >&2
  echo "Check: evolution/evolved-r*.json files in ${LATEST_RUN}evolution/" >&2
  exit 2
fi

exit 0
