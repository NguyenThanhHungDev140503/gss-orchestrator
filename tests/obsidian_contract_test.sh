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

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to not contain: $pattern" >&2
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
cat > "$tmpdir/.planning/DESIGN.md" <<'EOF'
# Project Design
Use the existing visual system.
EOF
cat > "$tmpdir/.planning/phases/01-demo/DESIGN.md" <<'EOF'
# Phase Design
Use a compact review layout.
EOF
cat > "$tmpdir/.planning/phases/01-demo/DESIGN_QA.md" <<'EOF'
# Design QA
Visual review passed.
EOF
cat > "$tmpdir/.planning/phases/01-demo/DOCS_REPORT.md" <<'EOF'
# Docs Report
Release docs updated.
EOF
cat > "$tmpdir/.planning/phases/01-demo/DEVEX_REVIEW.md" <<'EOF'
# DX Review
TTHW: 3 steps, ~2 min.
EOF
cat > "$tmpdir/.planning/phases/01-demo/DEBUG_REPORT.md" <<'EOF'
# Debug Report
Root cause identified before retry.
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
assert_frontmatter_type "$tmpdir/.planning/DESIGN.md" "design"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DESIGN.md" "design"
assert_contains "$tmpdir/.planning/phases/01-demo/DESIGN.md" "phase: 01-demo"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DESIGN_QA.md" "design-qa"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DOCS_REPORT.md" "documentation"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DEVEX_REVIEW.md" "devex-review"
assert_contains "$tmpdir/.planning/phases/01-demo/DEVEX_REVIEW.md" "phase: 01-demo"
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DEBUG_REPORT.md" "debug-report"
assert_contains "$tmpdir/.planning/phases/01-demo/DEBUG_REPORT.md" "phase: 01-demo"

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
assert_contains "$ROOT/agents/gss-devex-reviewer.md" "obsidian_meta.sh"
assert_contains "$ROOT/agents/gss-devex-reviewer.md" "ensure-frontmatter"
assert_contains "$ROOT/agents/gss-designer.md" "obsidian_meta.sh"
assert_contains "$ROOT/agents/gss-designer.md" "ensure-frontmatter"
assert_contains "$ROOT/agents/gss-docs.md" "obsidian_meta.sh"
assert_contains "$ROOT/agents/gss-docs.md" "ensure-frontmatter"
assert_contains "$ROOT/agents/gss-debugger.md" "obsidian_meta.sh"
assert_contains "$ROOT/agents/gss-debugger.md" "ensure-frontmatter"
assert_not_contains "$ROOT/agents/gss-devex-reviewer.md" ".claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh"
assert_not_contains "$ROOT/agents/gss-designer.md" ".claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh"
assert_not_contains "$ROOT/agents/gss-docs.md" ".claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh"
assert_not_contains "$ROOT/agents/gss-debugger.md" ".claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh"
assert_not_contains "$ROOT/agents/gss-devex-reviewer.md" "write frontmatter manually"
assert_not_contains "$ROOT/agents/gss-designer.md" "write frontmatter manually"
assert_not_contains "$ROOT/agents/gss-docs.md" "write frontmatter manually"
assert_not_contains "$ROOT/agents/gss-debugger.md" "write frontmatter manually"

assert_contains "$ROOT/SKILL.md" "scripts/obsidian_meta.sh"
assert_contains "$ROOT/SKILL.md" ".planning/RESEARCH.md"
assert_not_contains "$ROOT/SKILL.md" "gss-research-synthesizer"
assert_not_contains "$ROOT/SKILL.md" "gss-roadmapper"
assert_not_contains "$ROOT/SKILL.md" "research/STACK.md"
assert_not_contains "$ROOT/SKILL.md" "research/FEATURES.md"
assert_not_contains "$ROOT/SKILL.md" "research/ARCHITECTURE.md"
assert_not_contains "$ROOT/SKILL.md" "research/PITFALLS.md"
assert_contains "$ROOT/SKILL.codex.md" "obsidian_meta.sh"
assert_contains "$ROOT/SKILL.codex.md" 'phases/<phase>/DESIGN_QA.md'
assert_contains "$ROOT/SKILL.codex.md" 'DEVEX_REVIEW.md'
assert_contains "$ROOT/SKILL.codex.md" 'DEBUG_REPORT.md'
assert_contains "$ROOT/SKILL.codex.md" 'phases/<phase>/DOCS_REPORT.md'
assert_contains "$ROOT/README.md" ".planning/.project_slug"
assert_contains "$ROOT/README.md" ".planning/bases/"
assert_contains "$ROOT/README.md" ".planning/RESEARCH.md"

# ── Idempotency / preservation regressions ───────────────────────────────────
idem="$(mktemp -d)"
trap 'rm -rf "$tmpdir" "$idem"' EXIT
mkdir -p "$idem/.planning/phases/01-demo"

(
  cd "$idem"
  bash "$SCRIPT" init-project "My Real Product" >/dev/null
)
if [ "$(cat "$idem/.planning/.project_slug")" != "my-real-product" ]; then
  echo "init-project with a name did not set the slug" >&2
  exit 1
fi

# init-project WITHOUT a name is no-clobber: the every-turn bootstrap must not
# overwrite a slug already chosen in Phase 0.
(
  cd "$idem"
  bash "$SCRIPT" init-project >/dev/null
)
if [ "$(cat "$idem/.planning/.project_slug")" != "my-real-product" ]; then
  echo "argument-less init-project overwrote an existing slug" >&2
  exit 1
fi

# init-project WITH a name is an intentional set: it overrides a placeholder
# slug that the bootstrap derived from the directory name.
plc="$(mktemp -d)"
mkdir -p "$plc/.planning"
(
  cd "$plc"
  bash "$SCRIPT" init-project >/dev/null          # bootstrap-style: derive from dir
  bash "$SCRIPT" init-project "Real Chosen Name" >/dev/null  # Phase 0: real name
)
if [ "$(cat "$plc/.planning/.project_slug")" != "real-chosen-name" ]; then
  echo "named init-project did not override a derived slug" >&2
  rm -rf "$plc"
  exit 1
fi
rm -rf "$plc"

# ensure-frontmatter must preserve created and unmanaged fields on re-normalize
cat > "$idem/.planning/ROADMAP.md" <<'EOF'
---
title: "Old Title"
type: roadmap
project_slug: my-real-product
created: 2020-01-01
updated: 2020-01-01
status: final
phase_count: 7
---
# Roadmap
Body stays.
EOF

(
  cd "$idem"
  bash "$SCRIPT" ensure-frontmatter ".planning/ROADMAP.md" roadmap >/dev/null
)
assert_contains "$idem/.planning/ROADMAP.md" "created: 2020-01-01"
assert_contains "$idem/.planning/ROADMAP.md" "status: final"
assert_contains "$idem/.planning/ROADMAP.md" "phase_count: 7"
assert_contains "$idem/.planning/ROADMAP.md" "Body stays."
if [ "$(grep -c '^updated:' "$idem/.planning/ROADMAP.md")" != "1" ]; then
  echo "ROADMAP.md should have exactly one updated field" >&2
  exit 1
fi

# a read-style ensure-frontmatter on a missing-slug repo must not create a slug
noslug="$(mktemp -d)"
mkdir -p "$noslug/.planning"
cat > "$noslug/.planning/DECISIONS.md" <<'EOF'
# Decisions
EOF
(
  cd "$noslug"
  bash "$SCRIPT" ensure-frontmatter ".planning/DECISIONS.md" decision-log >/dev/null
)
if [ -f "$noslug/.planning/.project_slug" ] && [ -s "$noslug/.planning/.project_slug" ]; then
  echo "ensure-frontmatter must not persist a .project_slug file" >&2
  rm -rf "$noslug"
  exit 1
fi
rm -rf "$noslug"

echo "obsidian contract ok"
