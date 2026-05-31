# Obsidian-First Compatible Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic Obsidian metadata and Bases generation for `.planning/` while preserving the existing GSS runtime file contract.

**Architecture:** Introduce `scripts/obsidian_meta.sh` as the only writer for Obsidian frontmatter and `.base` files. Existing agents and scripts keep writing the same runtime artifacts, then call the helper to normalize metadata after writes.

**Tech Stack:** Bash shell scripts, Markdown docs, existing shell contract tests.

---

## File Structure

- Create: `scripts/obsidian_meta.sh`
  - Owns project slug derivation, frontmatter insertion/update, known artifact normalization, and Obsidian Bases generation.
- Create: `tests/obsidian_contract_test.sh`
  - Contract test for the metadata helper, decision logging integration, and runtime documentation references.
- Modify: `scripts/setup.sh`
  - Calls metadata helper during setup and generates Bases files.
- Modify: `scripts/resolve_gsd_paths.sh`
  - Exports metadata-related paths such as `GSD_PROJECT_SLUG` and `GSD_BASES_DIR`.
- Modify: `scripts/log_decision.sh`
  - Ensures decision files have frontmatter before appending.
- Modify: `scripts/inject_answer.sh`
  - Ensures decision file frontmatter before appending injected answers.
- Modify: `scripts/summarize_gstack.sh`
  - Ensures decision file frontmatter before appending summaries.
- Modify: `scripts/checkpoint.sh`
  - Ensures checkpoint history has frontmatter before appending checkpoints.
- Modify: `agents/gss-researcher.md`
  - Documents that `RESEARCH.md` remains the source of truth and should be normalized.
- Modify: `agents/gss-gsd-runner.md`
  - Documents metadata normalization after GSD artifact creation.
- Modify: `agents/gss-reviewer.md`
  - Documents decision frontmatter normalization.
- Modify: `agents/gss-brainstormer.md`
  - Documents brainstorm and plan normalization.
- Modify: `SKILL.md`
  - Replace hand-written Obsidian YAML/Bases instructions with helper calls, remove nonexistent agent references, and preserve current runtime contract.
- Modify: `SKILL.codex.md`
  - Add the same metadata helper contract using Codex-compatible wording.
- Modify: `README.md`
  - Describe Obsidian-first compatible mode and runtime structure.
- Modify: `references/decisions-template.md`
  - Add YAML frontmatter-compatible template content.

## Implementation Notes

- Do not remove `.planning/RESEARCH.md`.
- Do not add `gss-research-synthesizer` or `gss-roadmapper`.
- Do not split research into `research/*.md`.
- Keep `SKILL.md` edits scoped to reconciling the current dirty Obsidian diff with this plan.
- Run `git status --short` before every commit and stage only files from the current task.

### Task 1: Obsidian Contract Test Scaffold

**Files:**
- Create: `tests/obsidian_contract_test.sh`

- [ ] **Step 1: Write the failing contract test**

Create `tests/obsidian_contract_test.sh` with this content:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/obsidian_contract_test.sh
```

Expected: FAIL with `Expected file to exist: .../scripts/obsidian_meta.sh`.

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/obsidian_contract_test.sh
git commit -m "test: add obsidian metadata contract"
```

### Task 2: Metadata Helper Script

**Files:**
- Create: `scripts/obsidian_meta.sh`
- Test: `tests/obsidian_contract_test.sh`

- [ ] **Step 1: Implement minimal helper script**

Create `scripts/obsidian_meta.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

PLANNING_DIR="${GSS_PLANNING_DIR:-.planning}"
SLUG_FILE="$PLANNING_DIR/.project_slug"

today() {
  date +%Y-%m-%d
}

slugify() {
  local raw="${1:-}"
  if [ -z "$raw" ]; then
    raw="$(basename "$PWD")"
  fi
  printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' _' '--' \
    | sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//'
}

project_slug() {
  mkdir -p "$PLANNING_DIR"
  if [ -s "$SLUG_FILE" ]; then
    cat "$SLUG_FILE"
    return
  fi
  slugify "$(basename "$PWD")" | tee "$SLUG_FILE"
}

write_slug() {
  mkdir -p "$PLANNING_DIR"
  local slug
  slug="$(slugify "${1:-}")"
  if [ -z "$slug" ]; then
    slug="project"
  fi
  printf '%s\n' "$slug" > "$SLUG_FILE"
  printf '%s\n' "$slug"
}

has_frontmatter() {
  local file="$1"
  [ -f "$file" ] || return 1
  [ "$(sed -n '1p' "$file")" = "---" ] || return 1
  sed -n '2,80p' "$file" | grep -qx -- "---"
}

frontmatter_for() {
  local file="$1"
  local type="$2"
  local phase="${3:-}"
  local slug="$4"
  local date="$5"
  local title
  title="$(basename "$file" .md)"

  cat <<EOF
---
title: "$title"
type: $type
project_slug: $slug
tags:
  - gsd
  - $type
  - project/$slug
created: $date
updated: $date
EOF

  if [ "$type" = "research" ]; then
    echo "research_dimension: summary"
  fi
  if [ -n "$phase" ]; then
    cat <<EOF
phase: $phase
project: "[[../../PROJECT]]"
EOF
  elif [ "$file" != "$PLANNING_DIR/PROJECT.md" ]; then
    echo 'project: "[[PROJECT]]"'
  fi

  case "$type" in
    decision-log)
      if [ -n "$phase" ]; then
        echo 'plan: "[[PLAN]]"'
      fi
      ;;
    brainstorm)
      echo 'plan: "[[PLAN]]"'
      echo 'decisions: "[[DECISIONS]]"'
      ;;
    roadmap)
      echo 'related:'
      echo '  - "[[REQUIREMENTS]]"'
      echo '  - "[[PROJECT]]"'
      ;;
    requirements)
      echo 'related:'
      echo '  - "[[ROADMAP]]"'
      echo '  - "[[PROJECT]]"'
      ;;
  esac

  echo "---"
}

ensure_frontmatter() {
  local file="${1:-}"
  local type="${2:-}"
  local phase="${3:-}"
  [ -n "$file" ] && [ -n "$type" ] || {
    echo "Usage: obsidian_meta.sh ensure-frontmatter <path> <type> [phase]" >&2
    exit 1
  }
  [ -f "$file" ] || return 0

  local slug date tmp
  slug="$(project_slug)"
  date="$(today)"
  tmp="$(mktemp)"

  if has_frontmatter "$file"; then
    awk -v updated="$date" '
      BEGIN { in_fm=0; done=0 }
      NR==1 && $0=="---" { in_fm=1; print; next }
      in_fm && $0=="---" {
        if (!done) print "updated: " updated
        in_fm=0
        print
        next
      }
      in_fm && $0 ~ /^updated:/ {
        print "updated: " updated
        done=1
        next
      }
      { print }
    ' "$file" > "$tmp"
  elif [ "$(sed -n '1p' "$file")" = "---" ]; then
    echo "WARN: malformed frontmatter in $file; left unchanged" >&2
    rm -f "$tmp"
    return 0
  else
    frontmatter_for "$file" "$type" "$phase" "$slug" "$date" > "$tmp"
    printf '\n' >> "$tmp"
    cat "$file" >> "$tmp"
  fi

  mv "$tmp" "$file"
}

normalize_known() {
  ensure_frontmatter "$PLANNING_DIR/REQUIREMENTS.md" requirements
  ensure_frontmatter "$PLANNING_DIR/RESEARCH.md" research
  ensure_frontmatter "$PLANNING_DIR/PROJECT.md" project
  ensure_frontmatter "$PLANNING_DIR/ROADMAP.md" roadmap
  ensure_frontmatter "$PLANNING_DIR/DECISIONS.md" decision-log
  ensure_frontmatter "$PLANNING_DIR/shared_context.md" shared-context
  ensure_frontmatter "$PLANNING_DIR/CHECKPOINT_HISTORY.md" checkpoint-log

  local phase_dir phase
  for phase_dir in "$PLANNING_DIR"/phases/*; do
    [ -d "$phase_dir" ] || continue
    phase="$(basename "$phase_dir")"
    ensure_frontmatter "$phase_dir/PLAN.md" plan "$phase"
    ensure_frontmatter "$phase_dir/DECISIONS.md" decision-log "$phase"
    ensure_frontmatter "$phase_dir/BRAINSTORM_DOC.md" brainstorm "$phase"
    ensure_frontmatter "$phase_dir/EXEC_PROMPT.md" execution-prompt "$phase"
  done
}

write_bases() {
  local slug
  slug="$(project_slug)"
  mkdir -p "$PLANNING_DIR/bases"

  cat > "$PLANNING_DIR/bases/project-dashboard.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - file.hasTag("project/$slug")

properties:
  type:
    displayName: "Type"
  status:
    displayName: "Status"
  phase:
    displayName: "Phase"

views:
  - type: table
    name: "All Documents"
    order:
      - file.name
      - type
      - status
      - file.mtime
    groupBy:
      property: type
      direction: ASC
EOF

  cat > "$PLANNING_DIR/bases/phases.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - type == "plan"
    - file.hasTag("project/$slug")

views:
  - type: table
    name: "All Phases"
    order:
      - file.name
      - phase
      - status
      - file.mtime
EOF

  cat > "$PLANNING_DIR/bases/research.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - type == "research"
    - file.hasTag("project/$slug")

views:
  - type: table
    name: "Research Docs"
    order:
      - file.name
      - research_dimension
      - file.mtime
EOF

  cat > "$PLANNING_DIR/bases/decisions.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - type == "decision-log"
    - file.hasTag("project/$slug")

views:
  - type: table
    name: "All Decisions"
    order:
      - file.name
      - phase
      - file.mtime
EOF
}

cmd="${1:-}"
case "$cmd" in
  init-project)
    write_slug "${2:-}"
    ;;
  ensure-frontmatter)
    ensure_frontmatter "${2:-}" "${3:-}" "${4:-}"
    ;;
  normalize-known)
    normalize_known
    ;;
  write-bases)
    write_bases
    ;;
  *)
    echo "Usage: obsidian_meta.sh init-project [name] | ensure-frontmatter <path> <type> [phase] | normalize-known | write-bases" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Make the script executable**

Run:

```bash
chmod +x scripts/obsidian_meta.sh
```

- [ ] **Step 3: Run Obsidian contract test**

Run:

```bash
bash tests/obsidian_contract_test.sh
```

Expected: PASS and print `obsidian contract ok`.

- [ ] **Step 4: Run helper smoke test directly**

Run:

```bash
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/.planning"
(
  cd "$tmpdir"
  bash /home/nguyen-thanh-hung/Downloads/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh init-project "Demo App"
  test "$(cat .planning/.project_slug)" = "demo-app"
)
rm -rf "$tmpdir"
```

Expected: command exits 0.

- [ ] **Step 5: Commit helper script**

```bash
git add scripts/obsidian_meta.sh
git commit -m "feat: add obsidian metadata helper"
```

### Task 3: Integrate Helper Into Runtime Scripts

**Files:**
- Modify: `scripts/resolve_gsd_paths.sh`
- Modify: `scripts/setup.sh`
- Modify: `scripts/log_decision.sh`
- Modify: `scripts/inject_answer.sh`
- Modify: `scripts/summarize_gstack.sh`
- Modify: `scripts/checkpoint.sh`
- Test: `tests/obsidian_contract_test.sh`

- [ ] **Step 1: Write focused failing assertions for script integration**

Extend `tests/obsidian_contract_test.sh` after the Bases assertions:

```bash
assert_contains "$ROOT/scripts/setup.sh" "obsidian_meta.sh"
assert_contains "$ROOT/scripts/resolve_gsd_paths.sh" "GSD_PROJECT_SLUG"
assert_contains "$ROOT/scripts/log_decision.sh" "ensure-frontmatter"
assert_contains "$ROOT/scripts/inject_answer.sh" "ensure-frontmatter"
assert_contains "$ROOT/scripts/summarize_gstack.sh" "ensure-frontmatter"
assert_contains "$ROOT/scripts/checkpoint.sh" "ensure-frontmatter"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/obsidian_contract_test.sh
```

Expected: FAIL with `Expected '.../scripts/setup.sh' to contain: obsidian_meta.sh`.

- [ ] **Step 3: Update `resolve_gsd_paths.sh`**

Add after `GSD_BRAINSTORM_DOC=...`:

```bash
GSD_PROJECT_SLUG_FILE="$PLANNING_DIR/.project_slug"
GSD_PROJECT_SLUG="$(cat "$GSD_PROJECT_SLUG_FILE" 2>/dev/null || basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//')"
GSD_BASES_DIR="$PLANNING_DIR/bases"
```

Add these names to the `export` block:

```bash
GSD_PROJECT_SLUG_FILE GSD_PROJECT_SLUG GSD_BASES_DIR
```

- [ ] **Step 4: Update `setup.sh`**

After `.planning/config.json` creation and before `GSS_STATE.json`, add:

```bash
# Obsidian metadata
if [ -x "$SKILL_DIR/scripts/obsidian_meta.sh" ]; then
  PROJECT_NAME="$(basename "$PWD")"
  bash "$SKILL_DIR/scripts/obsidian_meta.sh" init-project "$PROJECT_NAME" >/dev/null
  bash "$SKILL_DIR/scripts/obsidian_meta.sh" normalize-known >/dev/null
  bash "$SKILL_DIR/scripts/obsidian_meta.sh" write-bases >/dev/null
  echo -e "  ${GREEN}✓${NC} Obsidian metadata"
else
  echo -e "  ${YELLOW}↺${NC} obsidian_meta.sh missing — skipped"
fi
```

- [ ] **Step 5: Update decision-appending scripts**

In `scripts/log_decision.sh`, after `mkdir -p .planning/milestones/current`, add:

```bash
if [ -x "$SCRIPT_DIR/obsidian_meta.sh" ]; then
  bash "$SCRIPT_DIR/obsidian_meta.sh" ensure-frontmatter "$MILESTONE_FILE" decision-log "${GSD_CURRENT_PHASE:-}"
  bash "$SCRIPT_DIR/obsidian_meta.sh" ensure-frontmatter "$GLOBAL_FILE" decision-log
fi
```

In `scripts/inject_answer.sh`, before the `cat >> "$EXEC_PROMPT"` block, add:

```bash
if [ -x "$SCRIPT_DIR/obsidian_meta.sh" ]; then
  bash "$SCRIPT_DIR/obsidian_meta.sh" ensure-frontmatter "$DECISIONS_FILE" decision-log "${GSD_CURRENT_PHASE:-}"
fi
```

In `scripts/summarize_gstack.sh`, before appending to `DECISIONS_FILE`, add:

```bash
if [ -x "$SCRIPT_DIR/obsidian_meta.sh" ]; then
  bash "$SCRIPT_DIR/obsidian_meta.sh" ensure-frontmatter "$DECISIONS_FILE" decision-log "${GSD_CURRENT_PHASE:-}"
  bash "$SCRIPT_DIR/obsidian_meta.sh" ensure-frontmatter "$GLOBAL_FILE" decision-log
fi
```

In `scripts/checkpoint.sh`, before appending to `CHECKPOINT_LOG`, add:

```bash
if [ -x "$SCRIPT_DIR/obsidian_meta.sh" ]; then
  touch "$CHECKPOINT_LOG"
  bash "$SCRIPT_DIR/obsidian_meta.sh" ensure-frontmatter "$CHECKPOINT_LOG" checkpoint-log
fi
```

- [ ] **Step 6: Run tests**

Run:

```bash
bash tests/obsidian_contract_test.sh
bash tests/codex_contract_test.sh
bash tests/browser_automation_contract_test.sh
```

Expected: all three tests pass.

- [ ] **Step 7: Commit script integration**

```bash
git add scripts/resolve_gsd_paths.sh scripts/setup.sh scripts/log_decision.sh scripts/inject_answer.sh scripts/summarize_gstack.sh scripts/checkpoint.sh tests/obsidian_contract_test.sh
git commit -m "feat: integrate obsidian metadata helper"
```

### Task 4: Template And Agent Documentation Updates

**Files:**
- Modify: `references/decisions-template.md`
- Modify: `agents/gss-researcher.md`
- Modify: `agents/gss-gsd-runner.md`
- Modify: `agents/gss-reviewer.md`
- Modify: `agents/gss-brainstormer.md`
- Test: `tests/obsidian_contract_test.sh`

- [ ] **Step 1: Add failing documentation assertions**

Append to `tests/obsidian_contract_test.sh`:

```bash
assert_contains "$ROOT/references/decisions-template.md" "type: decision-log"
assert_contains "$ROOT/agents/gss-researcher.md" "obsidian_meta.sh"
assert_contains "$ROOT/agents/gss-gsd-runner.md" "normalize-known"
assert_contains "$ROOT/agents/gss-reviewer.md" "ensure-frontmatter"
assert_contains "$ROOT/agents/gss-brainstormer.md" "BRAINSTORM_DOC.md"
assert_contains "$ROOT/agents/gss-brainstormer.md" "normalize-known"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/obsidian_contract_test.sh
```

Expected: FAIL with missing `type: decision-log` or missing `obsidian_meta.sh`.

- [ ] **Step 3: Update `references/decisions-template.md`**

Replace the file header with:

```markdown
---
title: "Decisions"
type: decision-log
project_slug: project
tags:
  - gsd
  - decision-log
  - project/project
created: 1970-01-01
updated: 1970-01-01
---

# DECISIONS.md — GSS Audit Trail
```

Keep the existing format explanation below the heading.

- [ ] **Step 4: Update agent docs with helper instructions**

In `agents/gss-researcher.md`, after the `.planning/RESEARCH.md` output block, add:

~~~markdown
After writing `.planning/RESEARCH.md`, normalize Obsidian metadata if the helper
is available:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known 2>/dev/null || true
```
~~~

In `agents/gss-gsd-runner.md`, after artifact verification in planning mode, add:

~~~markdown
After GSD writes planning artifacts, run:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known 2>/dev/null || true
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh write-bases 2>/dev/null || true
```
~~~

In `agents/gss-reviewer.md`, before the decision append example, add:

~~~markdown
Before appending decisions, ensure decision files have frontmatter:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh ensure-frontmatter "$GSD_DECISIONS_FILE" decision-log "$GSD_CURRENT_PHASE" 2>/dev/null || true
```
~~~

In `agents/gss-brainstormer.md`, after writing `BRAINSTORM_DOC.md`, add:

~~~markdown
After writing `BRAINSTORM_DOC.md` or refining `PLAN.md`, run:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known 2>/dev/null || true
```
~~~

- [ ] **Step 5: Run tests**

Run:

```bash
bash tests/obsidian_contract_test.sh
bash tests/codex_contract_test.sh
```

Expected: both tests pass.

- [ ] **Step 6: Commit docs integration**

```bash
git add references/decisions-template.md agents/gss-researcher.md agents/gss-gsd-runner.md agents/gss-reviewer.md agents/gss-brainstormer.md tests/obsidian_contract_test.sh
git commit -m "docs: document obsidian metadata normalization"
```

### Task 5: Orchestrator Documentation Reconciliation

**Files:**
- Modify: `SKILL.md`
- Modify: `SKILL.codex.md`
- Modify: `README.md`
- Test: `tests/obsidian_contract_test.sh`
- Test: `tests/codex_contract_test.sh`

- [ ] **Step 1: Add failing orchestrator documentation assertions**

Append to `tests/obsidian_contract_test.sh`:

```bash
assert_contains "$ROOT/SKILL.md" "scripts/obsidian_meta.sh"
assert_contains "$ROOT/SKILL.md" ".planning/RESEARCH.md"
assert_not_contains "$ROOT/SKILL.md" "research/STACK.md"
assert_not_contains "$ROOT/SKILL.md" "research/FEATURES.md"
assert_not_contains "$ROOT/SKILL.md" "research/ARCHITECTURE.md"
assert_not_contains "$ROOT/SKILL.md" "research/PITFALLS.md"
assert_contains "$ROOT/SKILL.codex.md" "obsidian_meta.sh"
assert_contains "$ROOT/README.md" ".planning/.project_slug"
assert_contains "$ROOT/README.md" ".planning/bases/"
assert_contains "$ROOT/README.md" ".planning/RESEARCH.md"
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bash tests/obsidian_contract_test.sh
```

Expected: FAIL while current `SKILL.md` still contains structured research references or lacks helper wording.

- [ ] **Step 3: Reconcile `SKILL.md`**

Edit the current dirty `SKILL.md` to match compatible-first behavior:

- Keep project slug initialization, but replace placeholder shell with:

```bash
PROJECT_NAME="[project name from user request, or basename \"$PWD\" if unclear]"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh init-project "$PROJECT_NAME"
```

- After writing requirements, add:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
```

- In Phase 1 after GSD planning output, replace the long Step 1.5 YAML blocks with:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh write-bases
```

- Remove these references from the file:
  - `gss-research-synthesizer`
  - `gss-roadmapper`
  - `research/STACK.md`
  - `research/FEATURES.md`
  - `research/ARCHITECTURE.md`
  - `research/PITFALLS.md`
  - `research/SUMMARY.md`

- File Communication Contract should list `.planning/RESEARCH.md` as `research`, not structured research folder files.

- Obsidian standard section should describe compatible-first schemas and state that `.planning/RESEARCH.md` remains the research source of truth.

- [ ] **Step 4: Update `SKILL.codex.md`**

Add compatible metadata helper calls in Codex wording:

~~~markdown
After requirements are saved:

```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh init-project "<project-name>"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
```
~~~

After planning completes:

~~~markdown
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh write-bases
```
~~~

- [ ] **Step 5: Update `README.md`**

In the runtime `.planning/` structure, add:

```text
├── .project_slug                 # Obsidian tag-safe project slug
├── bases/                        # Obsidian Bases query files
│   ├── project-dashboard.base
│   ├── phases.base
│   ├── research.base
│   └── decisions.base
```

Add a short section:

```markdown
## Obsidian-first compatible mode

GSS keeps the existing runtime files as the source of truth and adds Obsidian
frontmatter plus Bases files around them. `.planning/RESEARCH.md` remains the
research artifact consumed by GSD; research is not split into `research/*.md` in
this compatible mode.
```

- [ ] **Step 6: Run tests**

Run:

```bash
bash tests/obsidian_contract_test.sh
bash tests/codex_contract_test.sh
bash tests/browser_automation_contract_test.sh
git diff --check
```

Expected: all pass.

- [ ] **Step 7: Commit orchestrator docs**

```bash
git add SKILL.md SKILL.codex.md README.md tests/obsidian_contract_test.sh
git commit -m "docs: align orchestrator with obsidian compatible mode"
```

### Task 6: Final Verification

**Files:**
- No new files expected unless previous tasks revealed necessary corrections.

- [ ] **Step 1: Run full verification**

Run:

```bash
bash tests/obsidian_contract_test.sh
bash tests/codex_contract_test.sh
bash tests/browser_automation_contract_test.sh
git diff --check
git status --short
```

Expected:

- All tests pass.
- `git diff --check` has no output.
- `git status --short` is clean, or only contains intentionally uncommitted user changes that are unrelated.

- [ ] **Step 2: Inspect final references**

Run:

```bash
rg -n "gss-research-synthesizer|gss-roadmapper|research/STACK|research/FEATURES|research/ARCHITECTURE|research/PITFALLS|research/SUMMARY" SKILL.md SKILL.codex.md README.md agents scripts tests
```

Expected: no output.

- [ ] **Step 3: Inspect commit history**

Run:

```bash
git log --oneline --decorate -6
```

Expected: recent commits show separate test/helper/integration/docs changes.

- [ ] **Step 4: Report result**

Final report should include:

- Tests run and result.
- Commits created.
- Note that `.planning/RESEARCH.md` remains the research source of truth.
- Note that no new agents were added.
