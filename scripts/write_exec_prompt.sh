#!/usr/bin/env bash
# scripts/write_exec_prompt.sh
# Build EXEC_PROMPT.md từ PLAN.md + DECISIONS.md — file này feed vào Task tool.
# Không bao giờ inline content vào orchestrator conversation.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"

CFG=".planning/config.json"
PLAN_FILE="$GSD_PLAN_FILE"
DECISIONS_FILE="$GSD_DECISIONS_FILE"
SHARED_CTX="$GSD_SHARED_CONTEXT"
OUT="$GSD_EXEC_PROMPT"
mkdir -p "$(dirname "$OUT")"

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
  echo "ERROR: No PLAN.md found. Check .planning/phases/ structure."
  exit 1
fi

MAX_ITER=15
[ -f "$CFG" ] && command -v jq &>/dev/null && \
  MAX_ITER=$(jq -r '.ralph_loop.default_max_iterations // 15' "$CFG")

cat > "$OUT" << PROMPT
You are executing a development phase as part of GSS Orchestrator.
Superpowers TDD skill is active — invoke it via the Skills tool: invoke skill superpowers

━━ MISSION ━━
Execute ALL unchecked [ ] tasks in PLAN.md using strict RED/GREEN/REFACTOR TDD.
Completed [x] tasks are done — do not redo them.

━━ GSTACK DECISIONS (authoritative) ━━
$(cat "$DECISIONS_FILE" 2>/dev/null || echo "none")

━━ SHARED CONTEXT ━━
$(cat "$SHARED_CTX" 2>/dev/null || echo "none")

━━ PLAN.md ━━
$(cat "$PLAN_FILE")

━━ SUPERPOWERS BRAINSTORMING ━━
Before coding, invoke Superpowers brainstorming for each task.
If brainstorming surfaces questions not answered in DECISIONS above:
  - Collect ALL questions into: $(dirname "$GSD_PLAN_FILE")/OPEN_QUESTIONS.md
  - Format: Q: <question> | Options: A)... B)... C)...
  - Output: <promise>PHASE_BLOCKED:QUESTIONS</promise>
  - Stop — do not guess.

━━ TDD PROTOCOL ━━
Per task: RED (failing test) → GREEN (minimal impl) → REFACTOR → commit → mark [x]

━━ COMPLETION SIGNALS ━━
All tasks [x] and tests pass: <promise>PHASE_COMPLETE</promise>
Need GStack decision: <promise>PHASE_BLOCKED:<question with options></promise>
Technical blocker: <promise>PHASE_BLOCKED:TECH:<description></promise>

━━ ITERATION AWARENESS ━━
Max iterations: $MAX_ITER. Read PLAN.md from disk each iteration to see current [x] state.
PROMPT

echo "✓ EXEC_PROMPT.md → $OUT"
echo "  size: $(wc -c < "$OUT") bytes"
echo ""
echo "Next: pass content to Task tool for gss-executor subagent"
