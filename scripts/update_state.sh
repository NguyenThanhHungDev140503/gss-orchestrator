#!/usr/bin/env bash
# scripts/update_state.sh
# Update GSS_STATE.json deterministic — không phụ thuộc Claude parse/remember state.
# Đây là source of truth duy nhất cho orchestrator loop.
#
# Usage:
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth"
#   bash scripts/update_state.sh SP_EXECUTING
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth" true

set -e
STATE_FILE=".planning/GSS_STATE.json"
NEW_STATE="${1:-}"
MILESTONE="${2:-}"
DEVEX="${3:-}"

[ -z "$NEW_STATE" ] && echo "Usage: update_state.sh <STATE> [milestone] [devex_surface]" && exit 1

mkdir -p .planning

if [ -f "$STATE_FILE" ] && command -v jq &>/dev/null; then
  TMP=$(mktemp)
  jq ".loop_state = \"$NEW_STATE\"" "$STATE_FILE" > "$TMP"
  [ -n "$MILESTONE" ] && jq ".current_milestone = \"$MILESTONE\"" "$TMP" > "${TMP}2" \
    && mv "${TMP}2" "$TMP"
  [ -n "$DEVEX" ] && jq --argjson d "$DEVEX" '.devex_surface = $d' "$TMP" > "${TMP}3" \
    && mv "${TMP}3" "$TMP"
  mv "$TMP" "$STATE_FILE"
elif [ -f "$STATE_FILE" ]; then
  TMP=$(mktemp)
  cp "$STATE_FILE" "$TMP"
  sed -i "s/\"loop_state\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"loop_state\": \"$NEW_STATE\"/" "$TMP"
  [ -n "$MILESTONE" ] && sed -i "s/\"current_milestone\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"current_milestone\": \"$MILESTONE\"/" "$TMP"
  if [ -n "$DEVEX" ]; then
    if grep -q '"devex_surface"' "$TMP"; then
      sed -i "s/\"devex_surface\"[[:space:]]*:[[:space:]]*[^,}]*/\"devex_surface\": $DEVEX/" "$TMP"
    else
      sed -i "s/\"current_milestone\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/&,\n  \"devex_surface\": $DEVEX/" "$TMP"
    fi
  fi
  mv "$TMP" "$STATE_FILE"
else
  DEVEX_FIELD=""
  [ -n "$DEVEX" ] && DEVEX_FIELD="  \"devex_surface\": $DEVEX,"
  cat > "$STATE_FILE" << EOF
{
  "loop_state": "$NEW_STATE",
  "current_milestone": "${MILESTONE:-null}",
$DEVEX_FIELD
  "milestones_done": [],
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

echo "✓ State → $NEW_STATE${MILESTONE:+ (milestone: $MILESTONE)}${DEVEX:+ (devex_surface: $DEVEX)}"
