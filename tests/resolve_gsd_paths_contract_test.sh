#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/resolve_gsd_paths.sh"

fail() {
  echo "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [ "$actual" != "$expected" ]; then
    fail "Expected $label to be '$expected', got '$actual'"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

phase="01-mvp-accounts-decks-basic-study"
mkdir -p "$tmpdir/.planning/phases/$phase"
cat > "$tmpdir/.planning/STATE.md" <<'EOF'
# Project State

Phase: 1 of 4 (MVP - Accounts, Decks & Basic Study)
Status: planning
EOF
cat > "$tmpdir/.planning/phases/$phase/01-05-PLAN.md" <<'EOF'
# Plan
EOF

(
  cd "$tmpdir"
  source "$SCRIPT"

  assert_eq "$GSD_CURRENT_PHASE" "$phase" "GSD_CURRENT_PHASE"
  assert_eq "$GSD_PHASE_DIR" ".planning/phases/$phase" "GSD_PHASE_DIR"
  assert_eq "$GSD_EXEC_PROMPT" ".planning/phases/$phase/EXEC_PROMPT.md" "GSD_EXEC_PROMPT"
  assert_eq "$GSD_PLAN_FILE" ".planning/phases/$phase/01-05-PLAN.md" "GSD_PLAN_FILE"
  assert_eq "$GSD_DEVEX_REVIEW" ".planning/phases/$phase/DEVEX_REVIEW.md" "GSD_DEVEX_REVIEW"
)

echo "resolve gsd paths contract ok"
