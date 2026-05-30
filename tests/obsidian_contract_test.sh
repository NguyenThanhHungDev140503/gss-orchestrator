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

echo "obsidian contract ok"
