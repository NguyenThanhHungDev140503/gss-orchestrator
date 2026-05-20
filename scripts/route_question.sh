#!/usr/bin/env bash
# ralph-loop/scripts/route_question.sh
# Phân tích câu hỏi blocking và recommend đúng GStack skill

QUESTION="${1:-}"

if [ -z "$QUESTION" ]; then
  echo "Usage: route_question.sh '<question>'"
  exit 1
fi

echo ""
echo "━━ Question routing ━━"
echo "Question: $QUESTION"
echo ""

# Keyword routing rules (đơn giản nhưng hiệu quả)
Q_LOWER=$(echo "$QUESTION" | tr '[:upper:]' '[:lower:]')

# CEO / product / business
if echo "$Q_LOWER" | grep -qE "business|requirement|user|feature|scope|priority|product|why|should we|do we need"; then
  echo "→ Route to: /gstack:ceo"
  echo "   Reason: product/business decision"
  echo "ROUTE=/gstack:ceo"

# Architecture / design
elif echo "$Q_LOWER" | grep -qE "architect|pattern|design|database|schema|api|interface|contract|struct|model|service|layer|module"; then
  echo "→ Route to: /plan-eng-review"
  echo "   Reason: architecture/design decision"
  echo "ROUTE=/plan-eng-review"

# Technical implementation
elif echo "$Q_LOWER" | grep -qE "implement|how to|library|package|algorithm|performance|cache|index|query|optimiz"; then
  echo "→ Route to: /gstack:engineer"
  echo "   Reason: technical implementation decision"
  echo "ROUTE=/gstack:engineer"

# QA / edge case / validation
elif echo "$Q_LOWER" | grep -qE "edge case|validat|error|fail|exception|null|empty|boundary|test|verify|check"; then
  echo "→ Route to: /gstack:qa"
  echo "   Reason: QA/validation decision"
  echo "ROUTE=/gstack:qa"

# Security
elif echo "$Q_LOWER" | grep -qE "security|auth|permission|encrypt|token|secret|vulnerab|inject|xss|csrf"; then
  echo "→ Route to: /plan-eng-review"
  echo "   Reason: security requires architecture review"
  echo "ROUTE=/plan-eng-review"

# Deployment / infra
elif echo "$Q_LOWER" | grep -qE "deploy|infra|env|config|docker|k8s|ci|cd|pipeline|server|port|host"; then
  echo "→ Route to: /gstack:release-manager"
  echo "   Reason: deployment/infra decision"
  echo "ROUTE=/gstack:release-manager"

# Default — engineer
else
  echo "→ Route to: /gstack:engineer  (default)"
  echo "   Reason: no specific keyword match, defaulting to engineer"
  echo "ROUTE=/gstack:engineer"
fi

echo ""
echo "After calling the GStack skill:"
echo "  bash .claude/skills/ralph-loop/scripts/log_decision.sh 'task-question' '<q_and_a>'"
echo "  Then retry: bash .claude/skills/ralph-loop/scripts/execute_task.sh '<task_id>' '<task_content_with_answer>'"
