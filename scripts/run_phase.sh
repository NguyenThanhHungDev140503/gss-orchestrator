#!/usr/bin/env bash
# scripts/run_phase.sh
# Fallback executor khi Task tool không available.
# Implement ralph-style loop qua claude -p subprocess.
# Orchestrator chỉ thấy signal cuối — không thấy implementation.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

MAX_ITER=""; MODE="normal"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations) MAX_ITER="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --verify) VERIFY=true; shift ;;
    *) shift ;;
  esac
done

CFG=".planning/config.json"
if [ -z "$MAX_ITER" ] && [ -f "$CFG" ] && command -v jq &>/dev/null; then
  [ "$MODE" = "qa_retry" ] \
    && MAX_ITER=$(jq -r '.ralph_loop.qa_retry_max_iterations // 10' "$CFG") \
    || MAX_ITER=$(jq -r '.ralph_loop.default_max_iterations // 15' "$CFG")
fi
MAX_ITER="${MAX_ITER:-15}"

EXEC_PROMPT="$GSD_EXEC_PROMPT"
LOG_DIR="$GSD_LOG_DIR"
PLAN_FILE="$GSD_PLAN_FILE"
PLAN_BASENAME="${PLAN_FILE%-PLAN.md}"
RESULT_FILE="$LOG_DIR/phase_result.json"
mkdir -p "$LOG_DIR"

[ ! -f "$EXEC_PROMPT" ] && \
  echo -e "${RED}ERROR: EXEC_PROMPT.md not found. Run write_exec_prompt.sh first.${NC}" && exit 1

check_implicit_done() {
  [ ! -f "$PLAN_FILE" ] && return 1
  [ "$(grep -c "^\- \[ \]" "$PLAN_FILE" 2>/dev/null || echo 1)" -eq 0 ]
}

parse_signal() {
  grep -E "<promise>" "$1" 2>/dev/null | tail -1 || echo ""
}

write_artifacts() {
  local summary="${PLAN_BASENAME}-SUMMARY.md"
  local verify="${PLAN_BASENAME}-VERIFICATION.md"
  {
    echo "# Summary — $(basename "$PLAN_BASENAME")"
    echo "$(date -u +'%Y-%m-%d %H:%M UTC') | iter: $ITER/$MAX_ITER"
    echo ""; echo "## Done"
    grep "^\- \[x\]" "$PLAN_FILE" 2>/dev/null || echo "_none_"
    echo ""; echo "## Pending"
    grep "^\- \[ \]" "$PLAN_FILE" 2>/dev/null || echo "_none_"
  } > "$summary"
  {
    echo "# Verification — $(basename "$PLAN_BASENAME")"
    echo "$(date -u +'%Y-%m-%d %H:%M UTC')"
    echo ""; git log --oneline -10 2>/dev/null || echo "no git"
  } > "$verify"
  echo "  → $(basename "$summary")"
  echo "  → $(basename "$verify")"
}

echo ""
echo "━━ Phase execution (fallback: claude -p loop) ━━"
echo "  Plan: $(basename "$PLAN_FILE")"
echo "  Max: $MAX_ITER | mode: $MODE"

# Recovery
if check_implicit_done; then
  echo -e "${YELLOW}⚡ All [x] already — implicit done${NC}"
  ITER=0; write_artifacts
  echo '{"status":"DONE","note":"recovered"}' > "$RESULT_FILE"
  bash "$SCRIPT_DIR/update_state.sh" "GSTACK_QA"
  echo -e "${GREEN}✅ Done${NC}"; echo "Next: /gstack:qa then QA skill"; exit 0
fi

ITER=0; RESULT="UNKNOWN"

while [ $ITER -lt $MAX_ITER ]; do
  ITER=$((ITER + 1))
  LOG_FILE="$LOG_DIR/iter_${ITER}_$(date +%s).log"
  echo "── Iter $ITER/$MAX_ITER ──"
  check_implicit_done && { RESULT="DONE"; break; }

  # subprocess — output vào log, không vào stdout
  claude -p "$(cat "$EXEC_PROMPT")" \
    --allowedTools "Bash,Read,Write,Edit" \
    --output-format text \
    > "$LOG_FILE" 2>&1 || true

  SIG=$(parse_signal "$LOG_FILE")

  if echo "$SIG" | grep -q "PHASE_COMPLETE"; then
    echo -e "  ${GREEN}✓ PHASE_COMPLETE${NC}"; RESULT="DONE"; break
  elif echo "$SIG" | grep -q "PHASE_BLOCKED:TECH:"; then
    Q=$(echo "$SIG" | sed 's/.*PHASE_BLOCKED:TECH://;s|</promise>||')
    echo "$Q" > "$GSD_BLOCKED_FILE"; echo "TECH" > "$GSD_BLOCKED_TYPE_FILE"
    RESULT="BLOCKED_TECH"; break
  elif echo "$SIG" | grep -q "PHASE_BLOCKED"; then
    Q=$(echo "$SIG" | sed 's/.*PHASE_BLOCKED://;s|</promise>||')
    echo "$Q" > "$GSD_BLOCKED_FILE"; echo "DECISION" > "$GSD_BLOCKED_TYPE_FILE"
    RESULT="BLOCKED"; break
  else
    check_implicit_done && { RESULT="DONE"; break; }
    sleep 2
  fi
done

echo ""
case "$RESULT" in
  "DONE")
    write_artifacts
    echo '{"status":"DONE"}' > "$RESULT_FILE"
    bash "$SCRIPT_DIR/update_state.sh" "GSTACK_QA"
    echo -e "${GREEN}✅ Phase complete — $ITER iter(s)${NC}"
    echo "Next: /gstack:qa then QA skill"
    exit 0 ;;
  "BLOCKED"|"BLOCKED_TECH")
    Q=$(cat "$GSD_BLOCKED_FILE" 2>/dev/null)
    TYPE=$(cat "$GSD_BLOCKED_TYPE_FILE" 2>/dev/null)
    echo '{"status":"BLOCKED"}' > "$RESULT_FILE"
    bash "$SCRIPT_DIR/update_state.sh" "GSTACK_QA"
    echo -e "${YELLOW}⏸ BLOCKED [$TYPE]: $Q${NC}"
    echo "Next: invoke GStack skill with question, then inject_answer.sh, then retry"
    exit 1 ;;
  *)
    echo -e "${RED}⚠ Max iter reached${NC}"
    echo "Logs: $LOG_DIR/"
    exit 2 ;;
esac
