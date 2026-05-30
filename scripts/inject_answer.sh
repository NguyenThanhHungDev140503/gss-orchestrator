#!/usr/bin/env bash
# scripts/inject_answer.sh
# Append GStack answer vào EXEC_PROMPT.md để Task tool retry với context đầy đủ.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"

ANSWER="${1:-}"
[ -z "$ANSWER" ] && echo "Usage: inject_answer.sh '<answer>'" && exit 1

EXEC_PROMPT="$GSD_EXEC_PROMPT"
DECISIONS_FILE="$GSD_DECISIONS_FILE"
OBSIDIAN_META="$SCRIPT_DIR/obsidian_meta.sh"

[ ! -f "$EXEC_PROMPT" ] && \
  echo "ERROR: EXEC_PROMPT.md not found. Run write_exec_prompt.sh first." && exit 1

TS=$(date -u +"%Y-%m-%d %H:%M UTC")

# Append vào EXEC_PROMPT — Task tool sẽ thấy khi retry
cat >> "$EXEC_PROMPT" << INJECT

━━ GSTACK ANSWER [$TS] ━━
Decision applied — do NOT ask this again.
$ANSWER

Resume executing next unchecked [ ] task with this decision.
INJECT

# Đồng thời log vào DECISIONS.md
mkdir -p "$(dirname "$DECISIONS_FILE")"
touch "$DECISIONS_FILE"
if [ -x "$OBSIDIAN_META" ]; then
  bash "$OBSIDIAN_META" ensure-frontmatter "$DECISIONS_FILE" decision-log "${GSD_CURRENT_PHASE:-}"
fi

{
  echo ""
  echo "---"
  echo "### [$TS] injected-answer"
  echo "$ANSWER"
} >> "$DECISIONS_FILE"

echo "✓ Answer injected into EXEC_PROMPT.md ($TS)"
echo "  Task tool retry will have this context."
