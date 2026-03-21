#!/usr/bin/env bash
#
# update-run-state.sh — Manages run state for Oathe research pipeline
#
# Usage: update-run-state.sh <RUN_ID> <NEW_STATE>
#
# Valid states: INIT, INGEST, GENERATE, DEBATE, EVOLVE, SYNTHESIZE, COMPLETE, ERROR

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
RUNS_DIR="${PLUGIN_ROOT}/docs/oathe/runs"

VALID_STATES=("INIT" "INGEST" "GENERATE" "DEBATE" "EVOLVE" "SYNTHESIZE" "COMPLETE" "ERROR")

usage() {
    echo "Usage: $0 <RUN_ID> <NEW_STATE>"
    echo "Valid states: ${VALID_STATES[*]}"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

RUN_ID="$1"
NEW_STATE="$2"

# Validate state
state_valid=false
for s in "${VALID_STATES[@]}"; do
    if [[ "$s" == "$NEW_STATE" ]]; then
        state_valid=true
        break
    fi
done

if [[ "$state_valid" != "true" ]]; then
    echo "Error: Invalid state '${NEW_STATE}'"
    echo "Valid states: ${VALID_STATES[*]}"
    exit 1
fi

META_DIR="${RUNS_DIR}/${RUN_ID}/_meta"
RUN_JSON="${META_DIR}/run.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create _meta directory if it doesn't exist
mkdir -p "$META_DIR"

# Update run.json using jq if available, otherwise fall back to python
if command -v jq &>/dev/null; then
    if [[ -f "$RUN_JSON" ]]; then
        tmp=$(mktemp)
        jq --arg state "$NEW_STATE" --arg ts "$TIMESTAMP" '
            .state = $state |
            .updated_at = $ts |
            .transitions += [{"state": $state, "timestamp": $ts}]
        ' "$RUN_JSON" > "$tmp" && mv "$tmp" "$RUN_JSON"
    else
        jq -n --arg id "$RUN_ID" --arg state "$NEW_STATE" --arg ts "$TIMESTAMP" '{
            run_id: $id,
            state: $state,
            created_at: $ts,
            updated_at: $ts,
            transitions: [{"state": $state, "timestamp": $ts}]
        }' > "$RUN_JSON"
    fi
else
    python3 -c "
import json, os, sys

run_json = '$RUN_JSON'
run_id = '$RUN_ID'
new_state = '$NEW_STATE'
timestamp = '$TIMESTAMP'

if os.path.exists(run_json):
    with open(run_json, 'r') as f:
        data = json.load(f)
    data['state'] = new_state
    data['updated_at'] = timestamp
    data.setdefault('transitions', []).append({'state': new_state, 'timestamp': timestamp})
else:
    data = {
        'run_id': run_id,
        'state': new_state,
        'created_at': timestamp,
        'updated_at': timestamp,
        'transitions': [{'state': new_state, 'timestamp': timestamp}]
    }

with open(run_json, 'w') as f:
    json.dump(data, f, indent=2)
"
fi

echo "Run ${RUN_ID}: state -> ${NEW_STATE} at ${TIMESTAMP}"
