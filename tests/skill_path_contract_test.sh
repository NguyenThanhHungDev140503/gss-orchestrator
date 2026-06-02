#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_contains() {
  local file="$1" pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to contain: $pattern" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1" pattern="$2"
  if grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to NOT contain: $pattern" >&2
    exit 1
  fi
}

# Brittle hardcoded forms must be gone; resolved form must be used instead.
assert_not_contains "$ROOT/SKILL.md" "bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/"
assert_not_contains "$ROOT/SKILL.md" "source .claude/skills/gsd-gstack-sp-orchestrator/scripts/"
assert_contains "$ROOT/SKILL.md" '$(cat .planning/.gss_home)/scripts/'
assert_contains "$ROOT/SKILL.md" "# >>> gss-resolve"

assert_not_contains "$ROOT/SKILL.codex.md" "bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/"
assert_not_contains "$ROOT/SKILL.codex.md" "source .agents/skills/gsd-gstack-sp-orchestrator/scripts/"
assert_contains "$ROOT/SKILL.codex.md" '$(cat .planning/.gss_home)/scripts/'
assert_contains "$ROOT/SKILL.codex.md" "# >>> gss-resolve"

# Functional: extract the resolver snippet from SKILL.md and run it against a
# skill installed only at a fake GLOBAL location, with cwd in a separate project.
extract_resolver() {
  awk '/# >>> gss-resolve/{f=1;next} /# <<< gss-resolve/{f=0} f' "$1"
}

snippet="$(extract_resolver "$ROOT/SKILL.md")"
[ -n "$snippet" ] || { echo "resolver snippet not found in SKILL.md" >&2; exit 1; }

fake_home="$(mktemp -d)"
project="$(mktemp -d)"
trap 'rm -rf "$fake_home" "$project"' EXIT

mkdir -p "$fake_home/.claude/skills/gsd-gstack-sp-orchestrator/scripts"
echo 'echo setup' > "$fake_home/.claude/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh"

(
  cd "$project"
  HOME="$fake_home" bash -c "$snippet"
)

resolved="$(cat "$project/.planning/.gss_home")"
case "$resolved" in
  /*) : ;;
  *) echo "resolved path is not absolute: $resolved" >&2; exit 1 ;;
esac
if [ ! -f "$resolved/scripts/setup.sh" ]; then
  echo "resolved path does not contain scripts/setup.sh: $resolved" >&2
  exit 1
fi

echo "skill path contract ok"
