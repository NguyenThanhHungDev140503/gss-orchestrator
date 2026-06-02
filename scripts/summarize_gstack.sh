#!/usr/bin/env bash
# scripts/summarize_gstack.sh
# Compress GStack output thành bullet decisions trước khi vào orchestrator context.
# Gọi NGAY SAU mỗi GStack invocation — đây là lớp bảo vệ context hygiene chính.
#
# Usage:
#   bash scripts/summarize_gstack.sh "<paste GStack output>"
#   echo "<output>" | bash scripts/summarize_gstack.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"

GREEN='\033[0;32m'; NC='\033[0m'

DECISIONS_FILE="${GSD_DECISIONS_FILE:-.planning/DECISIONS.md}"
GLOBAL_FILE="${GSD_GLOBAL_DECISIONS:-.planning/DECISIONS.md}"
LOG_DIR="${GSD_LOG_DIR:-.planning/logs}"
OBSIDIAN_META="$SCRIPT_DIR/obsidian_meta.sh"
mkdir -p "$LOG_DIR"

GSTACK_OUTPUT="${1:-}"
[ -z "$GSTACK_OUTPUT" ] && GSTACK_OUTPUT=$(cat)
[ -z "$GSTACK_OUTPUT" ] && echo "No input." && exit 1

SUMMARY_LOG="$LOG_DIR/gstack_full_$(date +%s).log"
SUMMARY_RESULT="$LOG_DIR/gstack_summary_$(date +%s).md"

# Full output vào log — orchestrator không thấy
echo "$GSTACK_OUTPUT" > "$SUMMARY_LOG"

# claude -p compress — output vào file, không stdout
claude -p "Extract actionable decisions from this GStack review output.
Max 10 bullets. Each: [ROLE] decision. No prose, no preamble.

$GSTACK_OUTPUT" \
  --allowedTools "" \
  --output-format text \
  > "$SUMMARY_RESULT" 2>&1 || true

SUMMARY=$(cat "$SUMMARY_RESULT")
TS=$(date -u +"%Y-%m-%d %H:%M UTC")

# Log vào DECISIONS.md
mkdir -p "$(dirname "$DECISIONS_FILE")" "$(dirname "$GLOBAL_FILE")"
touch "$DECISIONS_FILE" "$GLOBAL_FILE"
if [ -x "$OBSIDIAN_META" ]; then
  bash "$OBSIDIAN_META" ensure-frontmatter "$DECISIONS_FILE" decision-log "${GSD_CURRENT_PHASE:-}"
  bash "$OBSIDIAN_META" ensure-frontmatter "$GLOBAL_FILE" decision-log
fi

{
  echo ""
  echo "---"
  echo "### [$TS] gstack-summary"
  echo "$SUMMARY"
} >> "$DECISIONS_FILE"

[ "$DECISIONS_FILE" != "$GLOBAL_FILE" ] && \
  printf "\n---\n### [%s] gstack-summary\n%s\n" "$TS" "$SUMMARY" >> "$GLOBAL_FILE"

# Chỉ print summary ngắn + paths — đây là tất cả vào orchestrator context
echo ""
echo "━━ GStack Summary ━━"
echo "$SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Logged → $DECISIONS_FILE${NC}"
echo "  Full output: $SUMMARY_LOG"
