#!/usr/bin/env bash
# scripts/log_decision.sh
TYPE="${1:-}" CONTENT="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"
MILESTONE_FILE="${GSD_DECISIONS_FILE:-.planning/milestones/current/DECISIONS.md}"
GLOBAL_FILE="${GSD_GLOBAL_DECISIONS:-.planning/DECISIONS.md}"
TS=$(date -u +"%Y-%m-%d %H:%M UTC")

mkdir -p .planning/milestones/current

ENTRY="
---
### [$TS] $TYPE
$CONTENT
"
echo "$ENTRY" >> "$MILESTONE_FILE"
echo "$ENTRY" >> "$GLOBAL_FILE"
echo "✓ Decision logged: $TYPE ($(wc -c <<< "$CONTENT") chars)"
