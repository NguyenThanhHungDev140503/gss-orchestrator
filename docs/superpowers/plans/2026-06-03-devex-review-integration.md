# plan-devex-review Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate GStack's `plan-devex-review` skill into the GSS Orchestrator as a conditional Phase 2.3 (`GSTACK_DX_REVIEW`), dispatched only when `gss-gsd-runner` classifies the project as having a developer-facing surface.

**Architecture:** `gss-gsd-runner` adds `devex_surface` + `devex_rationale` to its `PLANNING_COMPLETE` JSON. The orchestrator writes this to `GSS_STATE.json` via `update_state.sh $3`. At the end of Phase 2, a conditional check routes to `GSTACK_DX_REVIEW` (new state) or skips to `GSTACK_DESIGN_PLAN`. A new `gss-devex-reviewer` agent invokes `plan-devex-review` and returns compact JSON.

**Tech Stack:** bash, jq, SKILL.md (orchestrator instructions), markdown agent definitions

---

## Task 1: `update_state.sh` — accept optional `devex_surface` arg

**Files:**
- Modify: `scripts/update_state.sh`
- Test: `tests/update_state_devex_test.sh` (new)

- [ ] **Step 1: Write the failing test**

Create `tests/update_state_devex_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/update_state.sh"

fail() { echo "$1" >&2; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Bootstrap a minimal GSS_STATE.json
mkdir -p "$tmpdir/.planning"
cat > "$tmpdir/.planning/GSS_STATE.json" <<'EOF'
{"loop_state":"PLANNING","current_milestone":"01-auth"}
EOF

# Test 1: passing devex_surface=true writes the field
(
  cd "$tmpdir"
  bash "$SCRIPT" "GSTACK_REVIEW" "01-auth" "true"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "true" ] || fail "Expected devex_surface=true, got '$val'"
)

# Test 2: passing devex_surface=false writes false
(
  cd "$tmpdir"
  bash "$SCRIPT" "GSTACK_DX_REVIEW" "" "false"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "false" ] || fail "Expected devex_surface=false, got '$val'"
)

# Test 3: omitting $3 does NOT overwrite an existing devex_surface
(
  cd "$tmpdir"
  # state already has devex_surface=false from test 2
  bash "$SCRIPT" "SP_BRAINSTORM"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "false" ] || fail "Expected devex_surface preserved as false, got '$val'"
)

echo "update_state devex contract ok"
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
cd /home/nguyen-thanh-hung/Downloads/gsd-gstack-sp-orchestrator
bash tests/update_state_devex_test.sh
```
Expected: FAIL — `update_state.sh` does not yet accept `$3`.

- [ ] **Step 3: Modify `scripts/update_state.sh` to accept `$3`**

Add `DEVEX="${3:-}"` after the existing `MILESTONE` line, and add a jq update block inside the `if jq` branch:

```bash
#!/usr/bin/env bash
# scripts/update_state.sh
# Update GSS_STATE.json deterministic — không phụ thuộc Claude parse/remember state.
# Đây là source of truth duy nhất cho orchestrator loop.
#
# Usage:
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth"
#   bash scripts/update_state.sh SP_EXECUTING
#   bash scripts/update_state.sh GSTACK_REVIEW "phase-01-auth" true   # sets devex_surface

set -e
STATE_FILE=".planning/GSS_STATE.json"
NEW_STATE="${1:-}"
MILESTONE="${2:-}"
DEVEX="${3:-}"

[ -z "$NEW_STATE" ] && echo "Usage: update_state.sh <STATE> [milestone] [devex_surface]" && exit 1

mkdir -p .planning

if [ -f "$STATE_FILE" ] && command -v jq &>/dev/null; then
  TMP=$(mktemp)
  jq ".loop_state = \"$NEW_STATE\"" "$STATE_FILE" > "$TMP"
  [ -n "$MILESTONE" ] && jq ".current_milestone = \"$MILESTONE\"" "$TMP" > "${TMP}2" \
    && mv "${TMP}2" "$TMP"
  [ -n "$DEVEX" ] && jq --argjson d "$DEVEX" '.devex_surface = $d' "$TMP" > "${TMP}3" \
    && mv "${TMP}3" "$TMP"
  mv "$TMP" "$STATE_FILE"
else
  cat > "$STATE_FILE" << EOF
{
  "loop_state": "$NEW_STATE",
  "current_milestone": "${MILESTONE:-null}",
  "milestones_done": [],
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

echo "✓ State → $NEW_STATE${MILESTONE:+ (milestone: $MILESTONE)}${DEVEX:+ (devex_surface: $DEVEX)}"
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
bash tests/update_state_devex_test.sh
```
Expected: `update_state devex contract ok`

- [ ] **Step 5: Commit**

```bash
git add scripts/update_state.sh tests/update_state_devex_test.sh
git commit -m "feat: update_state.sh accepts optional devex_surface arg"
```

---

## Task 2: `resolve_gsd_paths.sh` — add `GSD_DEVEX_REVIEW`

**Files:**
- Modify: `scripts/resolve_gsd_paths.sh`
- Modify: `tests/resolve_gsd_paths_contract_test.sh`

- [ ] **Step 1: Add the failing assertion to the test**

In `tests/resolve_gsd_paths_contract_test.sh`, after the existing `assert_eq` calls, add:

```bash
  assert_eq "$GSD_DEVEX_REVIEW" \
    ".planning/phases/$phase/DEVEX_REVIEW.md" \
    "GSD_DEVEX_REVIEW"
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bash tests/resolve_gsd_paths_contract_test.sh
```
Expected: FAIL — `GSD_DEVEX_REVIEW` is unbound or empty.

- [ ] **Step 3: Add `GSD_DEVEX_REVIEW` to `scripts/resolve_gsd_paths.sh`**

After line `GSD_DESIGN_QA_REPORT="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/DESIGN_QA.md"`, add:

```bash
GSD_DEVEX_REVIEW="$PLANNING_DIR/phases/$GSD_CURRENT_PHASE/DEVEX_REVIEW.md"
```

Then add `GSD_DEVEX_REVIEW` to the `export` statement at the bottom (after `GSD_DESIGN_QA_REPORT`):

```bash
export GSD_STATE_FILE GSD_ROADMAP_FILE GSD_CURRENT_PHASE \
       GSD_PHASE_DIR GSD_PLAN_FILE GSD_EXEC_PROMPT \
       GSD_DECISIONS_FILE GSD_BLOCKED_FILE GSD_BLOCKED_TYPE_FILE \
       GSD_LOG_DIR GSD_GLOBAL_DECISIONS GSD_SHARED_CONTEXT \
       GSD_BRAINSTORM_DOC GSD_PROJECT_DESIGN GSD_PHASE_DESIGN \
       GSD_DESIGN_QA_REPORT GSD_DEVEX_REVIEW GSD_DOCS_REPORT \
       GSD_PROJECT_SLUG_FILE GSD_PROJECT_SLUG GSD_BASES_DIR
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
bash tests/resolve_gsd_paths_contract_test.sh
```
Expected: `resolve gsd paths contract ok`

- [ ] **Step 5: Commit**

```bash
git add scripts/resolve_gsd_paths.sh tests/resolve_gsd_paths_contract_test.sh
git commit -m "feat: add GSD_DEVEX_REVIEW path to resolve_gsd_paths.sh"
```

---

## Task 3: `obsidian_meta.sh` — add `DEVEX_REVIEW.md` to `normalize-known`

**Files:**
- Modify: `scripts/obsidian_meta.sh`
- Modify: `tests/obsidian_contract_test.sh`

- [ ] **Step 1: Add fixture and failing assertion to the obsidian test**

In `tests/obsidian_contract_test.sh`, after the `DOCS_REPORT.md` fixture block and before the `(cd "$tmpdir" ...)` execution block, add:

```bash
cat > "$tmpdir/.planning/phases/01-demo/DEVEX_REVIEW.md" <<'EOF'
# DX Review
TTHW: 3 steps, ~2 min.
EOF
```

After the existing `assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DOCS_REPORT.md"` assertion, add:

```bash
assert_frontmatter_type "$tmpdir/.planning/phases/01-demo/DEVEX_REVIEW.md" "devex-review"
assert_contains "$tmpdir/.planning/phases/01-demo/DEVEX_REVIEW.md" "phase: 01-demo"
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bash tests/obsidian_contract_test.sh
```
Expected: FAIL — `DEVEX_REVIEW.md` has no frontmatter / wrong type.

- [ ] **Step 3: Add `DEVEX_REVIEW.md` to `normalize_known()` in `scripts/obsidian_meta.sh`**

In the `normalize_known()` function (around line 268), after the `BRAINSTORM_DOC.md` line, add:

```bash
    ensure_frontmatter "$phase_dir/DEVEX_REVIEW.md" devex-review "$phase"
```

The updated block looks like:
```bash
    ensure_frontmatter "$phase_dir/PLAN.md" plan "$phase"
    ensure_frontmatter "$phase_dir/DECISIONS.md" decision-log "$phase"
    ensure_frontmatter "$phase_dir/DESIGN.md" design "$phase"
    ensure_frontmatter "$phase_dir/DESIGN_QA.md" design-qa "$phase"
    ensure_frontmatter "$phase_dir/DEVEX_REVIEW.md" devex-review "$phase"
    ensure_frontmatter "$phase_dir/DOCS_REPORT.md" documentation "$phase"
    ensure_frontmatter "$phase_dir/BRAINSTORM_DOC.md" brainstorm "$phase"
    ensure_frontmatter "$phase_dir/EXEC_PROMPT.md" execution-prompt "$phase"
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
bash tests/obsidian_contract_test.sh
```
Expected: `obsidian contract ok` (or similar pass message)

- [ ] **Step 5: Commit**

```bash
git add scripts/obsidian_meta.sh tests/obsidian_contract_test.sh
git commit -m "feat: add DEVEX_REVIEW.md to obsidian normalize-known"
```

---

## Task 4: `agents/gss-gsd-runner.md` — add `devex_surface` to PLANNING_COMPLETE JSON

**Files:**
- Modify: `agents/gss-gsd-runner.md`

No new test needed — this is an instruction change in a markdown agent file. The orchestrator integration in Task 6 covers the contract.

- [ ] **Step 1: Update PLANNING_COMPLETE JSON output spec**

In `agents/gss-gsd-runner.md`, replace the `PLANNING_COMPLETE` JSON block:

Old:
```json
{
  "mode": "PLANNING",
  "status": "PLANNING_COMPLETE",
  "current_phase": "01-auth",
  "phase_count": 5,
  "roadmap_path": ".planning/ROADMAP.md",
  "plan_path": ".planning/phases/01-auth/PLAN.md"
}
```

New:
```json
{
  "mode": "PLANNING",
  "status": "PLANNING_COMPLETE",
  "current_phase": "01-auth",
  "phase_count": 5,
  "roadmap_path": ".planning/ROADMAP.md",
  "plan_path": ".planning/phases/01-auth/PLAN.md",
  "devex_surface": true,
  "devex_rationale": "Project exposes a REST API and CLI for developer integration"
}
```

- [ ] **Step 2: Add classification instruction to Mode: PLANNING steps**

In the `### Mode: PLANNING` section, after Step 4 (read result from disk), add Step 5:

```
5. Classify developer-facing surface: based on the requirements and PLAN.md,
   determine if the project has a developer-facing surface (API, CLI, SDK,
   library, npm package, platform, docs, Claude Code skill). Set:
   - `devex_surface: true` if the plan exposes any interface developers
     integrate against or that ships as a developer tool
   - `devex_surface: false` for internal tools, pure UI apps, backend
     services with no external API, or infrastructure-only projects
   - `devex_rationale`: one sentence explaining the classification
```

- [ ] **Step 3: Commit**

```bash
git add agents/gss-gsd-runner.md
git commit -m "feat: gss-gsd-runner returns devex_surface in PLANNING_COMPLETE JSON"
```

---

## Task 5: Create `agents/gss-devex-reviewer.md`

**Files:**
- Create: `agents/gss-devex-reviewer.md`

- [ ] **Step 1: Create the agent file**

```markdown
---
name: gss-devex-reviewer
description: >
  GStack DX review specialist for GSS Orchestrator. Invoke this subagent for
  pre-implementation developer experience plan review. Calls plan-devex-review,
  stores full output on disk, and returns compact JSON only.
tools: Bash, Read, Write, Edit, Skill, AskUserQuestion
---

# GSS DevEx Reviewer — GStack DX Specialist

You run GStack DX review workflows inside the orchestrator boundary. The
orchestrator receives only compact JSON; full GStack output is stored in
phase logs and phase artifacts.

## Core Rules

1. Always invoke `plan-devex-review` via the Skill tool — do NOT simulate.
2. Save full skill output to `$GSD_LOG_DIR`; return only summary JSON.
3. Log actionable DX decisions to `$GSD_DECISIONS_FILE`.
4. Do not start implementation or make code changes.
5. Do not hand-write Obsidian YAML — use `scripts/obsidian_meta.sh`.

## Setup

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
mkdir -p "$GSD_LOG_DIR"
```

Read current phase context:
- `$GSD_PLAN_FILE`
- `$GSD_DECISIONS_FILE`
- `.planning/REQUIREMENTS.md`
- `.planning/RESEARCH.md`
- `.planning/shared_context.md`

## Mode: DEVEX_REVIEW

Purpose: review the milestone plan for developer experience gaps — getting
started friction, API/CLI ergonomics, error message quality, documentation
completeness — before Superpowers brainstorming refines the implementation plan.

Required skill:
- `plan-devex-review`

Extract:
- DX gaps and actionable decisions
- TTHW estimate (Time to Hello World) if produced by the skill
- Open product/API questions that require orchestrator routing
- Recommended improvements within the plan's current scope

Write compact DX findings to `$GSD_DEVEX_REVIEW`:

```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh \
  ensure-frontmatter "$GSD_DEVEX_REVIEW" devex-review "$GSD_CURRENT_PHASE" \
  2>/dev/null || true
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known \
  2>/dev/null || true
```

Return:
```json
{
  "mode": "DEVEX_REVIEW",
  "status": "APPROVED | NEEDS_CLARIFICATION",
  "decisions": ["[DX] Getting started flow reduced to 3 steps"],
  "dx_gaps": ["Missing error message for invalid API key"],
  "tthw_estimate": "~2 min",
  "open_questions": [],
  "artifacts": [".planning/phases/01-demo/DEVEX_REVIEW.md"],
  "log_file": ".planning/phases/01-demo/logs/devex_review_123.log"
}
```

## Do Not

- Return full `plan-devex-review` prose to the orchestrator.
- Make code changes or refactor existing API design inline.
- Skip `plan-devex-review` — do not simulate the review.
- Mark DX issues as resolved without AskUserQuestion confirmation.
```

- [ ] **Step 2: Verify file exists and is well-formed**

```bash
head -5 agents/gss-devex-reviewer.md
grep -c "plan-devex-review" agents/gss-devex-reviewer.md
```
Expected: frontmatter visible, at least 2 matches for `plan-devex-review`.

- [ ] **Step 3: Commit**

```bash
git add agents/gss-devex-reviewer.md
git commit -m "feat: add gss-devex-reviewer agent for DX plan review"
```

---

## Task 6: `SKILL.md` — state machine + Phase 1.4 + Phase 2.4 + Phase 2.3 + contract table

**Files:**
- Modify: `SKILL.md`

This task has 4 independent edits. Each is a targeted string replacement.

### Edit A: State machine diagram

- [ ] **Step 1: Update the state machine diagram**

Find the current diagram block:
```
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → GSTACK_DESIGN_PLAN → SP_BRAINSTORM → SP_EXECUTING
                                  ↑                                      ↕
                                  │                               BLOCKED:DESIGN
                                  │                             (→ gss-reviewer
                                  │                               → back to BRAINSTORM)
                                  │
                                  └── GSD_DISPATCH ← GSTACK_DOCS ← GSTACK_DESIGN_QA ← GSTACK_QA
                                                   NEXT_PHASE loop
```

Replace with:
```
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → GSTACK_DX_REVIEW → GSTACK_DESIGN_PLAN → SP_BRAINSTORM → SP_EXECUTING
                                  ↑                ↑                                         ↕
                                  │         (skip if no                             BLOCKED:DESIGN
                                  │          devex_surface)                       (→ gss-reviewer
                                  │                                                 → back to BRAINSTORM)
                                  │
                                  └── GSD_DISPATCH ← GSTACK_DOCS ← GSTACK_DESIGN_QA ← GSTACK_QA
                                                   NEXT_PHASE loop
```

### Edit B: Phase 1 Step 1.4 — write `devex_surface` to state

- [ ] **Step 2: Update Phase 1 Step 1.4**

Find:
```bash
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW" "<phase-from-STATE.md>"
```

Replace with:
```bash
# Extract devex_surface from gss-gsd-runner PLANNING_COMPLETE JSON
DEVEX_SURFACE=$(echo '<planning_json_result>' | jq -r '.devex_surface // false')
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW" "<phase-from-STATE.md>" "$DEVEX_SURFACE"
```

### Edit C: Phase 2 Step 2.4 — conditional routing to `GSTACK_DX_REVIEW`

- [ ] **Step 3: Update Phase 2 Step 2.4**

Find:
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "eng-review" "[extracted engineering decisions]"

bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"

bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```

Replace with:
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "eng-review" "[extracted engineering decisions]"

DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" = "true" ]; then
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DX_REVIEW"
else
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
fi

bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```

### Edit D: Insert Phase 2.3 section + update File Communication Contract

- [ ] **Step 4: Insert Phase 2.3 between Phase 2 and Phase 2.5**

Find the line:
```
## PHASE 2.5 — GSTACK DESIGN PLAN REVIEW
```

Insert the following block immediately before it:

```markdown
---

## PHASE 2.3 — GSTACK DX REVIEW

**Trigger:** `loop_state` is `GSTACK_DX_REVIEW`

### Step 2.3.1 — Conditional skip check

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" != "true" ]; then
  echo "No developer-facing surface detected — skipping DX review"
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
fi
```

If `DEVEX` is not `true`, skip to PHASE 2.5 immediately.

### Step 2.3.2 — Dispatch gss-devex-reviewer

Use **Agent/Task tool**:

```
Agent(
  subagent_type: "gss-devex-reviewer",
  prompt: "Mode: DEVEX_REVIEW

           Review the current milestone plan for developer experience gaps.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - .planning/REQUIREMENTS.md
           - .planning/RESEARCH.md
           - .planning/shared_context.md

           devex_rationale: [paste devex_rationale from GSS_STATE.json]

           Invoke plan-devex-review via the Skill tool and follow its full
           workflow. Write compact DX findings to $GSD_DEVEX_REVIEW.
           Normalize metadata with scripts/obsidian_meta.sh.
           Return DEVEX_REVIEW JSON only."
)
```

Wait for JSON.

### Step 2.3.3 — Parse result

**If `status: APPROVED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "dx-review" "[extracted DX decisions]"
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```
→ Proceed to PHASE 2.5

**If `status: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DX REVIEW NEEDS CLARIFICATION: [open_questions]"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW"
```
→ Return to PHASE 2 with DX question in context

---
```

- [ ] **Step 5: Add `DEVEX_REVIEW.md` row to the File Communication Contract table**

Find the row:
```
| `DESIGN_QA.md` | gss-designer (GStack) | gss-docs, GSD dispatch | `design-qa` |
```

Add a new row after it:
```
| `phases/<phase>/DEVEX_REVIEW.md` | gss-devex-reviewer (GStack) | gss-designer, gss-docs | `devex-review` |
```

- [ ] **Step 6: Verify SKILL.md changes are coherent**

```bash
grep -n "GSTACK_DX_REVIEW" SKILL.md
grep -n "gss-devex-reviewer" SKILL.md
grep -n "devex_surface" SKILL.md
grep -n "DEVEX_REVIEW" SKILL.md
```
Expected: each grep returns ≥2 matches — diagram, phase trigger, step body, contract table.

- [ ] **Step 7: Commit**

```bash
git add SKILL.md
git commit -m "feat: add GSTACK_DX_REVIEW phase to GSS Orchestrator state machine"
```

---

## Task 7: Run all tests and verify

- [ ] **Step 1: Run full test suite**

```bash
cd /home/nguyen-thanh-hung/Downloads/gsd-gstack-sp-orchestrator
bash tests/update_state_devex_test.sh
bash tests/resolve_gsd_paths_contract_test.sh
bash tests/obsidian_contract_test.sh
bash tests/codex_contract_test.sh
bash tests/skill_path_contract_test.sh
```
Expected: all tests pass with no errors.

- [ ] **Step 2: Verify agent roster is complete**

```bash
ls agents/
grep -l "plan-devex-review\|devex" agents/*.md
```
Expected: `agents/gss-devex-reviewer.md` listed, contains `plan-devex-review`.

- [ ] **Step 3: Verify state machine covers new state**

```bash
grep "GSTACK_DX_REVIEW" SKILL.md | wc -l
```
Expected: ≥ 4 (diagram, Phase 2.4 routing, Phase 2.3 trigger, contract table).

- [ ] **Step 4: Commit final verification**

```bash
git add -A
git status  # confirm nothing unexpected staged
git commit -m "chore: verify devex-review integration complete"
```
