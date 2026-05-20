#!/usr/bin/env bash
# scripts/print_summary.sh
STATE=".planning/GSS_STATE.json"
DECISIONS=".planning/DECISIONS.md"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   GSS Orchestrator — DELIVERED ✅            ║"
echo "║   GSD + GStack + Superpowers + ralph-loop    ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

M=$(ls -d .planning/archive/milestone-* 2>/dev/null | wc -l || echo 0)
D=$(grep -c "^###" "$DECISIONS" 2>/dev/null || echo 0)
L=$(find .planning -name "EXEC_PROMPT.md" 2>/dev/null | wc -l || echo 0)

echo "Milestones completed : $M"
echo "GStack decisions     : $D"
echo "ralph-loop phases    : $L"
echo ""
echo "Audit trail  : .planning/DECISIONS.md"
echo "Shared ctx   : .planning/shared_context.md"
echo "Archive      : .planning/archive/"
echo ""
START=$(grep started_at "$STATE" 2>/dev/null | grep -o '"[^"]*Z"' | tr -d '"' || echo "unknown")
echo "Started  : $START"
echo "Finished : $(date -u +"%Y-%m-%d %H:%M UTC")"
