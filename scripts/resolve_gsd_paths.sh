#!/usr/bin/env bash
# scripts/resolve_gsd_paths.sh
# Đọc cấu trúc thực của GSD và export các path đúng.
# Source file này trong các script khác: source scripts/resolve_gsd_paths.sh

PLANNING_DIR=".planning"
STATE_FILE="$PLANNING_DIR/STATE.md"
ROADMAP_FILE="$PLANNING_DIR/ROADMAP.md"

resolve_project_slug() {
  local slug_file="$PLANNING_DIR/.project_slug"
  if [ -s "$slug_file" ]; then
    cat "$slug_file"
    return
  fi

  local slug
  slug="$(basename "$PWD" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' _' '--' \
    | sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//')"
  # Match obsidian_meta.sh fallback for empty/odd directory names.
  [ -z "$slug" ] && slug="project"
  printf '%s\n' "$slug"
}

# ── Tìm active phase từ STATE.md ──────────────────────────────────────────
resolve_current_phase() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "" ; return
  fi
  # GSD ghi "Current Phase: XX" hoặc "Active: XX" trong STATE.md
  grep -iE "^current phase:|^active phase:|^phase:" "$STATE_FILE" 2>/dev/null \
    | head -1 | sed 's/.*: *//' | tr -d '[:space:]' \
    || grep -oE '[0-9]{2}-[a-z-]+' "$STATE_FILE" 2>/dev/null | head -1 \
    || ls "$PLANNING_DIR/phases/" 2>/dev/null | sort | tail -1
}

# ── Tìm PLAN.md hiện tại trong phase ─────────────────────────────────────
resolve_plan_file() {
  local phase="${1:-$(resolve_current_phase)}"
  local phase_dir="$PLANNING_DIR/phases/$phase"

  if [ -z "$phase" ] || [ ! -d "$phase_dir" ]; then
    # Fallback: tìm PLAN.md bất kỳ trong phases/
    find "$PLANNING_DIR/phases" -name "*-PLAN.md" -o -name "PLAN.md" 2>/dev/null \
      | sort | tail -1
    return
  fi

  # Ưu tiên file plan chưa có SUMMARY tương ứng (chưa done)
  local pending
  pending=$(for f in "$phase_dir"/*-PLAN.md "$phase_dir"/PLAN.md; do
    [ -f "$f" ] || continue
    base="${f%-PLAN.md}"
    summary="${base}-SUMMARY.md"
    [ ! -f "$summary" ] && echo "$f"
  done | sort | head -1)

  if [ -n "$pending" ]; then
    echo "$pending"
  else
    # Tất cả đã có SUMMARY → lấy cái cuối cùng
    ls "$phase_dir"/*-PLAN.md "$phase_dir"/PLAN.md 2>/dev/null | sort | tail -1
  fi
}

# ── Export ────────────────────────────────────────────────────────────────
GSD_STATE_FILE="$STATE_FILE"
GSD_ROADMAP_FILE="$ROADMAP_FILE"
GSD_CURRENT_PHASE=$(resolve_current_phase)
GSD_PHASE_DIR="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE"
GSD_PLAN_FILE=$(resolve_plan_file "$GSD_CURRENT_PHASE")
GSD_EXEC_PROMPT="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/EXEC_PROMPT.md"
GSD_DECISIONS_FILE="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/DECISIONS.md"
GSD_BLOCKED_FILE="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/BLOCKED_QUESTION.txt"
GSD_BLOCKED_TYPE_FILE="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/BLOCKED_TYPE.txt"
GSD_LOG_DIR="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/logs"
GSD_GLOBAL_DECISIONS="$PLANNING_DIR/DECISIONS.md"
GSD_SHARED_CONTEXT="$PLANNING_DIR/shared_context.md"
GSD_BRAINSTORM_DOC="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/BRAINSTORM_DOC.md"
GSD_PROJECT_SLUG_FILE="$PLANNING_DIR/.project_slug"
GSD_PROJECT_SLUG="$(resolve_project_slug)"
GSD_BASES_DIR="$PLANNING_DIR/bases"

# Legacy fallback nếu dùng cấu trúc milestones cũ
if [ -z "$GSD_PLAN_FILE" ] || [ ! -f "$GSD_PLAN_FILE" ]; then
  for legacy in \
    ".planning/milestones/current/PLAN.md" \
    ".planning/PLAN.md"; do
    if [ -f "$legacy" ]; then
      GSD_PLAN_FILE="$legacy"
      GSD_EXEC_PROMPT="$(dirname "$legacy")/EXEC_PROMPT.md"
      GSD_DECISIONS_FILE="$(dirname "$legacy")/DECISIONS.md"
      GSD_BLOCKED_FILE="$(dirname "$legacy")/BLOCKED_QUESTION.txt"
      GSD_BLOCKED_TYPE_FILE="$(dirname "$legacy")/BLOCKED_TYPE.txt"
      GSD_LOG_DIR="$(dirname "$legacy")/logs"
      break
    fi
  done
fi

export GSD_STATE_FILE GSD_ROADMAP_FILE GSD_CURRENT_PHASE \
       GSD_PHASE_DIR GSD_PLAN_FILE GSD_EXEC_PROMPT \
       GSD_DECISIONS_FILE GSD_BLOCKED_FILE GSD_BLOCKED_TYPE_FILE \
       GSD_LOG_DIR GSD_GLOBAL_DECISIONS GSD_SHARED_CONTEXT \
       GSD_BRAINSTORM_DOC GSD_PROJECT_SLUG_FILE GSD_PROJECT_SLUG \
       GSD_BASES_DIR

# Debug info (chỉ in khi GSS_DEBUG=1)
if [ "${GSS_DEBUG:-0}" = "1" ]; then
  echo "[resolve_gsd_paths]"
  echo "  phase    : $GSD_CURRENT_PHASE"
  echo "  phase_dir: $GSD_PHASE_DIR"
  echo "  plan     : $GSD_PLAN_FILE"
  echo "  exec_p   : $GSD_EXEC_PROMPT"
fi
