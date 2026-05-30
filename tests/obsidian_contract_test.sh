#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_file_exists() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Expected file to exist: $path" >&2
    exit 1
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to contain: $pattern" >&2
    exit 1
  fi
}

assert_frontmatter_type() {
  local file="$1"
  local type="$2"
  if [ "$(sed -n '1p' "$file")" != "---" ]; then
    echo "Expected '$file' to start with YAML frontmatter" >&2
    exit 1
  fi
  assert_contains "$file" "type: $type"
  assert_contains "$file" "project_slug: demo-app"
}

SCRIPT="$ROOT/scripts/obsidian_meta.sh"
assert_file_exists "$SCRIPT"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.planning/phases/01-demo"
cat > "$tmpdir/.planning/REQUIREMENTS.md" <<'EOF'
# Requirements
Build the demo app.
EOF
cat > "$tmpdir/.planning/RESEARCH.md" <<'EOF'
---
title: "Old Research"
type: note
project_slug: stale-project
tags:
  - old
created: 2020-01-01
updated: 2020-01-01
research_dimension: detail
---
# Research Summary
Use boring tech.
EOF
cat > "$tmpdir/.planning/ROADMAP.md" <<'EOF'
# Roadmap
### Phase 1
Ship demo.
EOF
cat > "$tmpdir/.planning/DECISIONS.md" <<'EOF'
# Decisions
EOF
cat > "$tmpdir/.planning/shared_context.md" <<'EOF'
# Shared Context
EOF
cat > "$tmpdir/.planning/phases/01-demo/PLAN.md" <<'EOF'
# Plan
- [ ] Add test
EOF
cat > "$tmpdir/.planning/phases/01-demo/DECISIONS.md" <<'EOF'
# Phase Decisions
EOF
cat > "$tmpdir/.planning/phases/01-demo/BRAINSTORM_DOC.md" <<'EOF'
# Brainstorm
EOF

(
  cd "$tmpdir"
  bash "$SCRIPT" init-project "Demo App" >/dev/null
  bash "$SCRIPT" normalize-known >/dev/null
  bash "$SCRIPT" write-bases >/dev/null
)

if [ "$(cat "$tmpdir/.planning/.project_slug")" != "demo-app" ]; then
  echo "Expected slug demo-app" >&2
  exit 1
fi

assert_frontmatter_type "$tmpdir/.planning/REQUIREMENTS.md" "requirements"
assert_frontmatter_type "$tmpdir/.planning/RESEARCH.md" "research"
assert_contains "$tmpdir/.planning/RESEARCH.md" "research_dimension: summary"
assert_contains "$tmpdir/.planning/RESEARCH.md" "Use boring tech."
assert_frontmatter_type "$tmpdir/.planning/ROADMAP.md" "roadmap"
assert_frontmatter_type "$tmpdir/.planning/DECISIONS.md" "decision-log"
assert_frontmatter_type "$tmpdir/.planning/shared_context.md" "shared-context"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/PLAN.md" "plan"
assert_contains "$tmpdir/.planning/phases/01-demo/PLAN.md" "phase: 01-demo"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DECISIONS.md" "decision-log"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/BRAINSTORM_DOC.md" "brainstorm"

assert_file_exists "$tmpdir/.planning/bases/project-dashboard.base"
assert_file_exists "$tmpdir/.planning/bases/phases.base"
assert_file_exists "$tmpdir/.planning/bases/research.base"
assert_file_exists "$tmpdir/.planning/bases/decisions.base"
assert_contains "$tmpdir/.planning/bases/project-dashboard.base" 'file.hasTag("project/demo-app")'
assert_contains "$tmpdir/.planning/bases/phases.base" 'type == "plan"'
assert_contains "$tmpdir/.planning/bases/research.base" 'type == "research"'
assert_contains "$tmpdir/.planning/bases/decisions.base" 'type == "decision-log"'

assert_contains "$ROOT/scripts/setup.sh" "obsidian_meta.sh"
assert_contains "$ROOT/scripts/resolve_gsd_paths.sh" "GSD_PROJECT_SLUG"
assert_contains "$ROOT/scripts/log_decision.sh" "ensure-frontmatter"
assert_contains "$ROOT/scripts/inject_answer.sh" "ensure-frontmatter"
assert_contains "$ROOT/scripts/summarize_gstack.sh" "ensure-frontmatter"
assert_contains "$ROOT/scripts/checkpoint.sh" "ensure-frontmatter"

long_frontmatter="$tmpdir/.planning/LONG_FRONTMATTER.md"
{
  echo "---"
  echo 'title: "Long Frontmatter"'
  for i in $(seq 1 85); do
    echo "field_$i: value_$i"
  done
  echo "---"
  echo "# Long Frontmatter"
  echo "Body stays here."
} > "$long_frontmatter"

(
  cd "$tmpdir"
  bash "$SCRIPT" ensure-frontmatter ".planning/LONG_FRONTMATTER.md" note >/dev/null
)

assert_contains "$long_frontmatter" "updated:"
assert_contains "$long_frontmatter" "Body stays here."

assert_contains "$ROOT/references/decisions-template.md" "type: decision-log"
assert_contains "$ROOT/agents/gss-researcher.md" "obsidian_meta.sh"
assert_contains "$ROOT/agents/gss-gsd-runner.md" "normalize-known"
assert_contains "$ROOT/agents/gss-reviewer.md" "ensure-frontmatter"
assert_contains "$ROOT/agents/gss-brainstormer.md" "normalize-known"

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to not contain: $pattern" >&2
    exit 1
  fi
}

assert_contains "$ROOT/SKILL.md" "scripts/obsidian_meta.sh"
assert_contains "$ROOT/SKILL.md" ".planning/RESEARCH.md"
assert_not_contains "$ROOT/SKILL.md" "gss-research-synthesizer"
assert_not_contains "$ROOT/SKILL.md" "gss-roadmapper"
assert_not_contains "$ROOT/SKILL.md" "research/STACK.md"
assert_not_contains "$ROOT/SKILL.md" "research/FEATURES.md"
assert_not_contains "$ROOT/SKILL.md" "research/ARCHITECTURE.md"
assert_not_contains "$ROOT/SKILL.md" "research/PITFALLS.md"
assert_contains "$ROOT/SKILL.codex.md" "obsidian_meta.sh"
assert_contains "$ROOT/README.md" ".planning/.project_slug"
assert_contains "$ROOT/README.md" ".planning/bases/"
assert_contains "$ROOT/README.md" ".planning/RESEARCH.md"

echo "obsidian contract ok"
