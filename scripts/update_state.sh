#!/usr/bin/env bash
# scripts/update_state.sh
# Update GSS_STATE.json deterministic — không phụ thuộc Claude parse/remember state.
# Đây là source of truth duy nhất cho orchestrator loop.
#
# Usage:
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth"
#   bash scripts/update_state.sh SP_EXECUTING
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth" true "REST API and CLI"

set -e
STATE_FILE=".planning/GSS_STATE.json"
NEW_STATE="${1:-}"
MILESTONE="${2:-}"
DEVEX="${3:-}"
DEVEX_RATIONALE="${4:-}"
PROJECT_MODE="${5:-}"

[ -z "$NEW_STATE" ] && echo "Usage: update_state.sh <STATE> [milestone] [devex_surface] [devex_rationale] [project_mode]" && exit 1

mkdir -p .planning

if [ -f "$STATE_FILE" ] && command -v jq &>/dev/null; then
  TMP=$(mktemp)
  jq ".loop_state = \"$NEW_STATE\"" "$STATE_FILE" > "$TMP"
  [ -n "$MILESTONE" ] && jq ".current_milestone = \"$MILESTONE\"" "$TMP" > "${TMP}2" \
    && mv "${TMP}2" "$TMP"
  [ -n "$DEVEX" ] && jq --argjson d "$DEVEX" '.devex_surface = $d' "$TMP" > "${TMP}3" \
    && mv "${TMP}3" "$TMP"
  [ -n "$DEVEX_RATIONALE" ] && jq --arg r "$DEVEX_RATIONALE" '.devex_rationale = $r' "$TMP" > "${TMP}4" \
    && mv "${TMP}4" "$TMP"
  [ -n "$PROJECT_MODE" ] && jq --arg m "$PROJECT_MODE" '.project_mode = $m' "$TMP" > "${TMP}5" \
    && mv "${TMP}5" "$TMP"
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
  if [ -n "$DEVEX_RATIONALE" ]; then
    ESCAPED_RATIONALE=$(printf '%s' "$DEVEX_RATIONALE" | sed 's/[\/&]/\\&/g')
    if grep -q '"devex_rationale"' "$TMP"; then
      sed -i "s/\"devex_rationale\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"devex_rationale\": \"$ESCAPED_RATIONALE\"/" "$TMP"
    else
      sed -i "s/\"current_milestone\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/&,\n  \"devex_rationale\": \"$ESCAPED_RATIONALE\"/" "$TMP"
    fi
  fi
  if [ -n "$PROJECT_MODE" ]; then
    ESCAPED_PROJECT_MODE=$(printf '%s' "$PROJECT_MODE" | sed 's/[\/&]/\\&/g')
    if grep -q '"project_mode"' "$TMP"; then
      sed -i "s/\"project_mode\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"project_mode\": \"$ESCAPED_PROJECT_MODE\"/" "$TMP"
    else
      sed -i "s/\"current_milestone\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/&,\n  \"project_mode\": \"$ESCAPED_PROJECT_MODE\"/" "$TMP"
    fi
  fi
  mv "$TMP" "$STATE_FILE"
else
  DEVEX_FIELD=""
  [ -n "$DEVEX" ] && DEVEX_FIELD="  \"devex_surface\": $DEVEX,"
  DEVEX_RATIONALE_FIELD=""
  [ -n "$DEVEX_RATIONALE" ] && DEVEX_RATIONALE_FIELD="  \"devex_rationale\": \"$DEVEX_RATIONALE\","
  PROJECT_MODE_FIELD=""
  [ -n "$PROJECT_MODE" ] && PROJECT_MODE_FIELD="  \"project_mode\": \"$PROJECT_MODE\","
  cat > "$STATE_FILE" << EOF
{
  "loop_state": "$NEW_STATE",
  "current_milestone": "${MILESTONE:-null}",
$DEVEX_FIELD
$DEVEX_RATIONALE_FIELD
$PROJECT_MODE_FIELD
  "milestones_done": [],
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

echo "✓ State → $NEW_STATE${MILESTONE:+ (milestone: $MILESTONE)}${DEVEX:+ (devex_surface: $DEVEX)}${DEVEX_RATIONALE:+ (devex_rationale saved)}${PROJECT_MODE:+ (project_mode: $PROJECT_MODE)}"
