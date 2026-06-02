#!/usr/bin/env bash
# scripts/checkpoint.sh
# Compact checkpoint — gọi trước /compact để đảm bảo state đầy đủ.
# Sau /compact, GSD tự resume qua HANDOFF.json.
# Script này bổ sung thêm GSS-specific state vào HANDOFF.json.
#
# Usage:
#   bash scripts/checkpoint.sh              ← checkpoint thường
#   bash scripts/checkpoint.sh --milestone  ← sau khi complete milestone
#   bash scripts/checkpoint.sh --phase      ← sau khi complete phase

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

MODE="${1:---normal}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_FILE=".planning/GSS_STATE.json"
HANDOFF_FILE=".planning/HANDOFF.json"
CHECKPOINT_LOG=".planning/CHECKPOINT_HISTORY.md"
OBSIDIAN_META="$SCRIPT_DIR/obsidian_meta.sh"

# ── 1. Đọc state hiện tại ──────────────────────────────────────────────────
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "{}")
CURRENT_PHASE="${GSD_CURRENT_PHASE:-unknown}"
PLAN_FILE="${GSD_PLAN_FILE:-none}"

# Tasks còn lại
PENDING_TASKS=0
DONE_TASKS=0
if [ -f "$PLAN_FILE" ]; then
  PENDING_TASKS=$(grep -c "^\- \[ \]" "$PLAN_FILE" 2>/dev/null || echo 0)
  DONE_TASKS=$(grep -c "^\- \[x\]" "$PLAN_FILE" 2>/dev/null || echo 0)
fi

# ── 2. Ghi GSS addon vào HANDOFF.json ─────────────────────────────────────
# GSD tự quản lý HANDOFF.json — chúng ta chỉ merge thêm gss_state
if [ -f "$HANDOFF_FILE" ] && command -v jq &>/dev/null; then
  GSS_ADDON=$(cat << JSON
{
  "gss_state": {
    "checkpoint_at": "$TS",
    "mode": "$MODE",
    "current_phase": "$CURRENT_PHASE",
    "plan_file": "$PLAN_FILE",
    "tasks_done": $DONE_TASKS,
    "tasks_pending": $PENDING_TASKS,
    "exec_prompt_exists": $([ -f "$GSD_EXEC_PROMPT" ] && echo true || echo false),
    "blocked_question": "$(cat "$GSD_BLOCKED_FILE" 2>/dev/null | head -1 | tr '"' "'")",
    "loop_state": $(echo "$CURRENT_STATE" | jq -r '.loop_state // "unknown"' | xargs -I{} echo '"{}"')
  }
}
JSON
)
  jq ". + $GSS_ADDON" "$HANDOFF_FILE" > "${HANDOFF_FILE}.tmp" 2>/dev/null \
    && mv "${HANDOFF_FILE}.tmp" "$HANDOFF_FILE" \
    || true  # nếu jq fail, HANDOFF.json vẫn nguyên vẹn
else
  # Tạo minimal HANDOFF nếu chưa có (GSD sẽ overwrite khi /compact)
  cat > "$HANDOFF_FILE" << JSON
{
  "gss_state": {
    "checkpoint_at": "$TS",
    "current_phase": "$CURRENT_PHASE",
    "plan_file": "$PLAN_FILE",
    "tasks_done": $DONE_TASKS,
    "tasks_pending": $PENDING_TASKS,
    "loop_state": "CHECKPOINT"
  }
}
JSON
fi

# ── 3. Ghi DECISIONS.md summary ngắn để context sau compact không bị mất ──
LAST_DECISIONS=$(cat "$GSD_DECISIONS_FILE" 2>/dev/null | tail -60 || echo "none")
RESUMPTION_HINT=""

if [ "$PENDING_TASKS" -gt 0 ]; then
  RESUMPTION_HINT="Phase $CURRENT_PHASE in progress. $DONE_TASKS tasks done, $PENDING_TASKS pending. Run: bash scripts/run_phase.sh"
elif [ -f "$GSD_BLOCKED_FILE" ]; then
  Q=$(cat "$GSD_BLOCKED_FILE" 2>/dev/null | head -1)
  RESUMPTION_HINT="BLOCKED waiting for GStack decision: $Q. Run: bash scripts/route_question.sh"
else
  RESUMPTION_HINT="Phase $CURRENT_PHASE complete. Run GStack QA via gss-reviewer, then /gsd-complete-milestone"
fi

# ── 4. Append vào checkpoint history ──────────────────────────────────────
touch "$CHECKPOINT_LOG"
if [ -x "$OBSIDIAN_META" ]; then
  bash "$OBSIDIAN_META" ensure-frontmatter "$CHECKPOINT_LOG" checkpoint-log
fi

cat >> "$CHECKPOINT_LOG" << LOG

---
## Checkpoint [$TS] mode=$MODE
- Phase: $CURRENT_PHASE
- Tasks: $DONE_TASKS done / $PENDING_TASKS pending
- Loop state: $(echo "$CURRENT_STATE" | grep -o '"loop_state": "[^"]*"' | head -1)
- Resumption: $RESUMPTION_HINT
LOG

# ── 5. Print tối giản ra stdout ───────────────────────────────────────────
echo ""
echo "━━ GSS Checkpoint [$MODE] ━━"
echo "  Phase  : $CURRENT_PHASE"
echo "  Tasks  : ✓$DONE_TASKS pending:$PENDING_TASKS"
echo "  Resume : $RESUMPTION_HINT"
echo ""
echo -e "${GREEN}✓ State saved to HANDOFF.json + CHECKPOINT_HISTORY.md${NC}"
echo ""
echo -e "${YELLOW}Now run /compact in Claude Code.${NC}"
echo "GSD will auto-resume from HANDOFF.json when session restarts."
echo "After resuming, re-run: bash scripts/checkpoint.sh --verify"
