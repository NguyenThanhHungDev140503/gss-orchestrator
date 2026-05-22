#!/usr/bin/env bash
# scripts/mark_milestone_done.sh
# Mark current GSD phase/milestone done in deterministic local state.
# Usage:
#   bash scripts/mark_milestone_done.sh [phase-id]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"

PHASE="${1:-$GSD_CURRENT_PHASE}"
STATE_FILE=".planning/GSS_STATE.json"
PHASE_STATE=".planning/phases/$PHASE/STATE.md"

if [ -z "$PHASE" ]; then
  echo "Usage: mark_milestone_done.sh [phase-id]"
  echo "Could not resolve current phase from .planning/STATE.md"
  exit 1
fi

mkdir -p .planning

# Mark phase-local state done when present.
if [ -f "$PHASE_STATE" ]; then
  if grep -qi '^status:' "$PHASE_STATE"; then
    sed -i 's/^status:.*/status: done/I' "$PHASE_STATE"
  else
    printf '\nstatus: done\n' >> "$PHASE_STATE"
  fi
fi

# Keep GSS state in sync.
if command -v jq >/dev/null 2>&1; then
  if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<EOF
{
  "loop_state": "GSD_DISPATCH",
  "current_milestone": "$PHASE",
  "milestones_done": [],
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi

  tmp=$(mktemp)
  jq --arg phase "$PHASE" '
    .current_milestone = $phase |
    .milestones_done = ((.milestones_done // []) + [$phase] | unique)
  ' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
else
  echo "WARN: jq not found; skipped GSS_STATE milestones_done update" >&2
fi

echo "✓ Milestone done → $PHASE"
