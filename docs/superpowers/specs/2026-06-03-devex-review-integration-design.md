# Design: plan-devex-review Integration into GSS Orchestrator

**Date:** 2026-06-03
**Status:** Approved
**Scope:** Add `plan-devex-review` (GStack) as a conditional phase in the GSS Orchestrator loop

---

## Problem

The GSS Orchestrator integrates 7 of 9 GStack design-phase skills. `plan-devex-review` — which reviews developer experience for APIs, CLIs, SDKs, libraries, platforms, and docs — is missing. Projects with developer-facing surfaces ship without DX review, leading to poor onboarding, unclear error messages, and friction that reduces adoption.

## Goals

- Add `plan-devex-review` as a conditional phase between `GSTACK_REVIEW` and `GSTACK_DESIGN_PLAN`
- Only dispatch when the project has a developer-facing surface (agentic detection, not hardcoded grep)
- Follow existing orchestrator patterns: new state, new agent, compact JSON, Obsidian artifacts
- Zero impact on projects without developer-facing surfaces (fast skip path)

## Decisions

- **Conditional dispatch** (not always-on): avoids unnecessary subagent cost for non-dev-facing projects
- **AI-based detection via `gss-gsd-runner`**: extends PLANNING_COMPLETE JSON with `devex_surface` + `devex_rationale` — the agent already has full project context at planning time
- **New state `GSTACK_DX_REVIEW`**: deserves own checkpoint like `GSTACK_DESIGN_PLAN`; Phase 2 crash recovery won't re-run CEO+Eng reviews unnecessarily
- **New agent `gss-devex-reviewer.md`**: single responsibility, follows `gss-designer.md` pattern exactly

---

## Architecture

### Updated State Machine

```
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → GSTACK_DX_REVIEW → GSTACK_DESIGN_PLAN → SP_BRAINSTORM → SP_EXECUTING
                                                    ↑
                                         skip if devex_surface=false
                                                    │
              GSD_DISPATCH ← GSTACK_DOCS ← GSTACK_DESIGN_QA ← GSTACK_QA ──────────────────────────────┘
```

### Detection Flow

`gss-gsd-runner` (Phase 1 — PLANNING) includes in its `PLANNING_COMPLETE` JSON:

```json
{
  "status": "PLANNING_COMPLETE",
  "current_phase": "phase-1",
  "plan_path": ".planning/phases/phase-1/PLAN.md",
  "devex_surface": true,
  "devex_rationale": "Project exposes a REST API and CLI for developer integration"
}
```

Orchestrator reads `devex_surface` and writes it to `GSS_STATE.json` via `update_state.sh` optional arg.

`GSS_STATE.json` schema after Phase 1:
```json
{
  "loop_state": "GSTACK_REVIEW",
  "current_phase": "phase-1",
  "devex_surface": true
}
```

---

## Phase 2.3 — GSTACK DX REVIEW (new)

**Trigger:** `loop_state` is `GSTACK_DX_REVIEW`

Inserted between Phase 2 (GSTACK_REVIEW) and Phase 2.5 (GSTACK_DESIGN_PLAN).

### Step 2.3.1 — Conditional skip

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" != "true" ]; then
  echo "No developer-facing surface — skipping DX review"
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
  # → Proceed to PHASE 2.5
fi
```

### Step 2.3.2 — Dispatch `gss-devex-reviewer`

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

## New Agent: `gss-devex-reviewer.md`

**Location:** `agents/gss-devex-reviewer.md`

**Frontmatter:**
```yaml
---
name: gss-devex-reviewer
description: >
  GStack DX review specialist for GSS Orchestrator. Invoke for pre-implementation
  developer experience plan review. Calls plan-devex-review, stores full output on
  disk, and returns compact JSON only.
tools: Bash, Read, Write, Edit, Skill, AskUserQuestion
---
```

**Core Rules:**
1. Always invoke `plan-devex-review` via Skill tool — do NOT simulate
2. Save full output to `$GSD_LOG_DIR`; return summary JSON only
3. Log actionable DX decisions to `$GSD_DECISIONS_FILE`
4. Do not start implementation or make code changes
5. Do not hand-write Obsidian YAML — use `scripts/obsidian_meta.sh`

**Setup:**
```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
mkdir -p "$GSD_LOG_DIR"
```

**Read context:** `$GSD_PLAN_FILE`, `$GSD_DECISIONS_FILE`, `.planning/REQUIREMENTS.md`, `.planning/RESEARCH.md`, `.planning/shared_context.md`

**Required skill:** `plan-devex-review`

**Extract from skill output:**
- DX gaps and decisions (actionable only)
- TTHW estimate if produced
- Open product/API questions
- Recommended improvements within plan scope

**Write artifact:** `$GSD_DEVEX_REVIEW`
```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh \
  ensure-frontmatter "$GSD_DEVEX_REVIEW" devex-review "$GSD_CURRENT_PHASE" 2>/dev/null || true
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known 2>/dev/null || true
```

**JSON output:**
```json
{
  "mode": "DEVEX_REVIEW",
  "status": "APPROVED | NEEDS_CLARIFICATION",
  "decisions": ["[DX] Getting started flow reduced to 3 steps"],
  "dx_gaps": ["Missing error message for invalid API key"],
  "tthw_estimate": "~4 min",
  "open_questions": [],
  "artifacts": [".planning/phases/01-demo/DEVEX_REVIEW.md"],
  "log_file": ".planning/phases/01-demo/logs/devex_review_123.log"
}
```

**Do Not:**
- Return full `plan-devex-review` prose to orchestrator
- Make code changes or refactor existing API design
- Skip `plan-devex-review` — do not simulate the review

---

## Supporting File Changes

### `scripts/resolve_gsd_paths.sh`

Add 1 export:
```bash
export GSD_DEVEX_REVIEW="$GSD_PHASE_DIR/DEVEX_REVIEW.md"
```

### `scripts/obsidian_meta.sh`

Add to `normalize-known` case block:
```bash
"$GSD_PHASE_DIR/DEVEX_REVIEW.md"|*"/DEVEX_REVIEW.md")
  type="devex-review" ;;
```

### `scripts/update_state.sh`

Accept optional arg `$3` for `devex_surface` (backward compatible):
```bash
if [ -n "${3:-}" ]; then
  jq --argjson devex "$3" '.devex_surface = $devex' \
    .planning/GSS_STATE.json > /tmp/gss_state_tmp.json \
    && mv /tmp/gss_state_tmp.json .planning/GSS_STATE.json
fi
```

**Note on timing:** `devex_surface` is written to `GSS_STATE.json` at the end of Phase 1
Step 1.4 (when `update_state.sh "GSTACK_REVIEW"` is called with `$3` = value from
`gss-gsd-runner` PLANNING_COMPLETE JSON). By the time Phase 2 ends and
`GSTACK_DX_REVIEW` is the next state, `devex_surface` is already in state — Step 2.3.1
reads it via `jq`.

### `agents/gss-gsd-runner.md`

Add to PLANNING_COMPLETE JSON output spec:
- `devex_surface: boolean` — true if project has developer-facing surface
- `devex_rationale: string` — one sentence explaining why

### `SKILL.md`

Changes:
1. State machine diagram: add `GSTACK_DX_REVIEW` between `GSTACK_REVIEW` and `GSTACK_DESIGN_PLAN`
2. Phase 2 end (Step 2.4): change `update_state.sh "GSTACK_DESIGN_PLAN"` → `update_state.sh "GSTACK_DX_REVIEW"` + read `devex_surface` from gss-gsd-runner JSON result
3. New Phase 2.3 section (full content above)
4. File Communication Contract table: add `DEVEX_REVIEW.md` row

---

## File Communication Contract (additions)

| File | Written by | Read by | Obsidian type |
|------|-----------|---------|---------------|
| `phases/<phase>/DEVEX_REVIEW.md` | `gss-devex-reviewer` | `gss-designer`, `gss-docs` | `devex-review` |

`gss-designer` reads DEVEX_REVIEW.md to avoid contradicting DX decisions in visual design.
`gss-docs` reads DEVEX_REVIEW.md when writing release notes for developer-facing changes.

---

## Files Changed Summary

| File | Change type |
|------|------------|
| `SKILL.md` | Update state machine, Phase 2 end, add Phase 2.3 |
| `agents/gss-devex-reviewer.md` | **New file** |
| `agents/gss-gsd-runner.md` | Add `devex_surface` + `devex_rationale` to PLANNING_COMPLETE JSON spec |
| `scripts/resolve_gsd_paths.sh` | Add `GSD_DEVEX_REVIEW` export |
| `scripts/obsidian_meta.sh` | Add `DEVEX_REVIEW.md` to normalize-known |
| `scripts/update_state.sh` | Accept optional `$3` devex_surface arg |

6 files total. No new scripts needed.
