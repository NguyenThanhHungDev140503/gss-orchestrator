#!/usr/bin/env bash
# scripts/update_state.sh
# Update GSS_STATE.json deterministic — không phụ thuộc Claude parse/remember state.
# Đây là source of truth duy nhất cho orchestrator loop.
#
# Usage:
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth"
#   bash scripts/update_state.sh SP_EXECUTING

set -e
STATE_FILE=".planning/GSS_STATE.json"
NEW_STATE="${1:-}"
MILESTONE="${2:-}"

[ -z "$NEW_STATE" ] && echo "Usage: update_state.sh <STATE> [milestone]" && exit 1

mkdir -p .planning

if [ -f "$STATE_FILE" ] && command -v jq &>/dev/null; then
  TMP=$(mktemp)
  jq ".loop_state = \"$NEW_STATE\"" "$STATE_FILE" > "$TMP"
  [ -n "$MILESTONE" ] && jq ".current_milestone = \"$MILESTONE\"" "$TMP" > "${TMP}2" \
    && mv "${TMP}2" "$TMP"
  mv "$TMP" "$STATE_FILE"
else
  cat > "$STATE_FILE" << EOF
{
  "loop_state": "$NEW_STATE",
  "current_milestone": "${MILESTONE:-null}",
  "milestones_done": [],
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

echo "✓ State → $NEW_STATE${MILESTONE:+ (milestone: $MILESTONE)}"
