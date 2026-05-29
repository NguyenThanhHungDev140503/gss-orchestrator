#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to contain: $pattern" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to not contain: $pattern" >&2
    exit 1
  fi
}

assert_not_line() {
  local file="$1"
  local line="$2"
  if grep -Fxq -- "$line" "$file"; then
    echo "Expected '$file' to not contain line: $line" >&2
    exit 1
  fi
}

assert_contains "$ROOT/SKILL.codex.md" '$gsd-new-project --auto'
assert_contains "$ROOT/SKILL.codex.md" '$plan-ceo-review'
assert_contains "$ROOT/SKILL.codex.md" '$plan-eng-review'
assert_contains "$ROOT/SKILL.codex.md" '$test-driven-development'
assert_contains "$ROOT/SKILL.codex.md" '$verification-before-completion'
assert_contains "$ROOT/SKILL.codex.md" 'write_exec_prompt_codex.sh'
assert_not_contains "$ROOT/SKILL.codex.md" 'Invoke the $gsd skill to plan this project.'
assert_not_contains "$ROOT/SKILL.codex.md" 'Invoke the $gstack skill for CEO review of this phase plan.'
assert_not_contains "$ROOT/SKILL.codex.md" '$superpowers skill'
assert_not_contains "$ROOT/SKILL.codex.md" 'invoke skill superpowers'

assert_contains "$ROOT/install_codex.sh" '- gsd-new-project'
assert_contains "$ROOT/install_codex.sh" '- gsd-progress'
assert_contains "$ROOT/install_codex.sh" '- plan-ceo-review'
assert_contains "$ROOT/install_codex.sh" '- plan-eng-review'
assert_contains "$ROOT/install_codex.sh" '- test-driven-development'
assert_contains "$ROOT/install_codex.sh" '- verification-before-completion'
assert_contains "$ROOT/install_codex.sh" 'SKILL_VERSION='
assert_contains "$ROOT/install_codex.sh" 'Previous install backed up'
assert_contains "$ROOT/install_codex.sh" 'cp -a "$SKILL_DEST" "$BACKUP_DEST"'
assert_contains "$ROOT/install_codex.sh" 'printf "%s\n" "$SKILL_VERSION" > "$SKILL_DEST/VERSION"'
assert_contains "$ROOT/install_codex.sh" '"version": "$SKILL_VERSION"'
assert_not_line "$ROOT/install_codex.sh" '    - gsd'
assert_not_line "$ROOT/install_codex.sh" '    - gstack'
assert_not_line "$ROOT/install_codex.sh" '    - superpowers'

SCRIPT="$ROOT/scripts/write_exec_prompt_codex.sh"
if [ ! -x "$SCRIPT" ]; then
  echo "Expected executable script: $SCRIPT" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.planning/phases/01-demo"
cat > "$tmpdir/.planning/STATE.md" <<'EOF'
Current Phase: 01-demo
EOF
cat > "$tmpdir/.planning/config.json" <<'EOF'
{
  "superpowers": {
    "default_max_iterations": 7
  }
}
EOF
cat > "$tmpdir/.planning/phases/01-demo/PLAN.md" <<'EOF'
- [ ] Write regression test
EOF
cat > "$tmpdir/.planning/phases/01-demo/DECISIONS.md" <<'EOF'
none
EOF
cat > "$tmpdir/.planning/shared_context.md" <<'EOF'
none
EOF

(
  cd "$tmpdir"
  bash "$SCRIPT" >/dev/null
)

PROMPT_FILE="$tmpdir/.planning/phases/01-demo/EXEC_PROMPT.md"
assert_contains "$PROMPT_FILE" '$test-driven-development'
assert_contains "$PROMPT_FILE" '$verification-before-completion'
assert_contains "$PROMPT_FILE" 'Max iterations: 7.'
assert_not_contains "$PROMPT_FILE" 'invoke skill superpowers'

RUN_PHASE="$ROOT/scripts/run_phase.sh"
assert_contains "$RUN_PHASE" 'bash "$SCRIPT_DIR/update_state.sh" "GSTACK_QA"'
blocked_branch=$(sed -n '/"BLOCKED"|"BLOCKED_TECH")/,/exit 1 ;;/p' "$RUN_PHASE")
if printf '%s\n' "$blocked_branch" | grep -Fq 'update_state.sh" "GSTACK_QA"'; then
  echo "Blocked execution must not transition to GSTACK_QA" >&2
  exit 1
fi

echo "codex contract ok"
