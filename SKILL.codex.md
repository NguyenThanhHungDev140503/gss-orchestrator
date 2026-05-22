---
name: gsd-gstack-sp-orchestrator
description: >
  Full development orchestrator for Codex. Coordinates GSD planning, GStack reviews,
  Superpowers Brainstorming gate, and TDD execution through a structured loop:
  plan milestones → review decisions → brainstorm design → execute → QA → dispatch.
  Trigger with: "orchestrate", "start gss loop", "build this project with planning",
  "run the full development loop". Uses Codex-native subagents plus concrete skill IDs.
---

# GSS Orchestrator — Codex Edition

## IDENTITY

You are the GSS Orchestrator.

In Codex, skills are **instruction bundles**, not callable tools.
To load a skill, the spawned subagent's **initial message** must mention the
concrete `$skill-name`.

Rules:
- There is **no** `invoke skill ...` command
- There is **no** Claude Code `Task(...)` syntax
- Do **not** use umbrella ids like `$gsd`, `$gstack`, or `$superpowers`
- Do **not** treat a skill's metadata/frontmatter as completion
- After each subagent completes, return here and advance this state machine

Read state at every turn:
```bash
cat .planning/GSS_STATE.json 2>/dev/null || echo '{"loop_state":"IDLE"}'
```

---

## HOW TO LOAD SKILLS IN CODEX

Bad patterns:
```text
Any literal "invoke skill ..." command
Any umbrella skill id such as $gsd / $gstack / $superpowers
Any Claude Code Task(...) block
```

Correct patterns:

Planning subagent:
```text
$gsd-new-project --auto
[the rest of the instructions]
```

CEO review subagent:
```text
$plan-ceo-review
[the rest of the instructions]
```

Engineering review subagent:
```text
$plan-eng-review
[the rest of the instructions]
```

Brainstorming gate subagent:
```text
$brainstorming
$writing-plans
[the rest of the instructions]
```

Execution subagent:
```text
$test-driven-development
$verification-before-completion
[the rest of the instructions]
```

Use only concrete skill ids that exist in Codex.

---

## STATE MACHINE

```text
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → SP_BRAINSTORM → SP_EXECUTING → GSTACK_QA → GSD_DISPATCH
                                  ↑                 ↕                                          │
                                  │          BLOCKED:DESIGN                                    │
                                  │        (→ GStack routing                                   │
                                  │          → retry brainstorm)                               │
                                  └────────────────────────────────────────────────────────────┘
                                                  NEXT_PHASE loop
```

---

## PHASE 0 — RESEARCH

**Trigger:** `loop_state` is `IDLE`

Pre-planning web research feeds GSD with a compact `RESEARCH.md` so it does not
need to dispatch nested research agents.

Save requirements:
```bash
mkdir -p .planning
cat > .planning/REQUIREMENTS.md << 'EOF'
[paste user's requirements here]
EOF
```

Spawn one researcher subagent. Its **initial message must begin with**:
```text
You are gss-researcher.

Use WebSearch and WebFetch directly — you have those tools.
Do NOT try to spawn subagents.

Read .planning/REQUIREMENTS.md, gather:
- Tech stack validation (best libraries/frameworks, versions, deprecations)
- Architecture patterns (production evidence, trade-offs)
- Implementation specifics (API/schema/auth/security/perf)
- Dependency risks (compatibility, breaking changes)

Write .planning/RESEARCH.md (max 500 lines, actionable decisions only).

When finished, output only:
RESEARCH_COMPLETE
[3-line summary of most important findings]
```

After `RESEARCH_COMPLETE`:
```bash
ls -la .planning/RESEARCH.md
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "PLANNING"
```

→ PHASE 1

---

## PHASE 1 — PLANNING

**Trigger:** `loop_state` is `PLANNING`

GSD handles interview, roadmap, and PLAN.md draft.
Pre-planning research has already produced `.planning/RESEARCH.md` in Phase 0 —
GSD MUST consume that file as research context and SKIP its own internal research
dispatch.

Verify Phase 0 outputs exist:
```bash
ls -la .planning/REQUIREMENTS.md .planning/RESEARCH.md
```

Both files must exist. If either is missing, return to PHASE 0 — do not dispatch GSD without research.

Spawn one planning subagent. Its **initial message must begin with**:
```text
$gsd-new-project --auto
Initialize planning artifacts for this project.

Requirements: .planning/REQUIREMENTS.md
Research context: .planning/RESEARCH.md  (already produced in Phase 0)

Run the GSD workflow using the supplied research.
SKIP GSD's internal research dispatch — RESEARCH.md is on disk and is the
authoritative research context for this milestone.
Answer any AskUserQuestion gates using the requirements when possible.
When finished, output only:
PLANNING_DONE: [current milestone name]
```

After subagent outputs `PLANNING_DONE`:
```bash
cat .planning/STATE.md
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<milestone>"
```

---

## PHASE 2 — GSTACK REVIEW

**Trigger:** `loop_state` is `GSTACK_REVIEW`

Read milestone plan:
```bash
source .agents/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
cat "$GSD_PLAN_FILE" 2>/dev/null || cat .planning/ROADMAP.md
```

### CEO Review

Spawn one review subagent. Its **initial message must begin with**:
```text
$plan-ceo-review
Review this milestone plan. Focus on user value, scope, acceptance criteria, risk.

Plan to review:
[paste plan content]

Return only:
DECISIONS_START
1. ...
2. ...
DECISIONS_END
CEO_DONE
```

After `CEO_DONE`, log decisions:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "ceo-review" "[extracted numbered decisions]"
```

### Engineering Review

Spawn one review subagent. Its **initial message must begin with**:
```text
$plan-eng-review
Review this milestone plan for architecture, dependencies, constraints, testability.

Plan to review:
[paste plan content]

CEO decisions already made:
[paste logged CEO decisions]

Return only:
DECISIONS_START
1. ...
2. ...
DECISIONS_END
ENG_DONE
```

After `ENG_DONE`:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "eng-review" "[extracted numbered decisions]"

bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_BRAINSTORM"

bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```

---

## PHASE 3 — SUPERPOWERS BRAINSTORMING GATE

**Trigger:** `loop_state` is `SP_BRAINSTORM`

This is a **HARD GATE** — execution cannot start until design is confirmed here.
The brainstormer reads codebase + DECISIONS.md, proposes 2-3 approaches with YAGNI
filter, confirms the best approach, then refines PLAN.md with implementation details.

Spawn one brainstorming subagent. Its **initial message must begin with**:
```text
$brainstorming
$writing-plans

You are the design gate for GSS Orchestrator. Your job:
1. Read codebase structure + DECISIONS.md + PLAN.md draft
2. Propose 2-3 implementation approaches for this milestone (apply YAGNI filter)
3. Confirm the best approach using DECISIONS.md constraints (HARD GATE — do not guess)
4. Refine PLAN.md in place with implementation details and test stubs
5. Write BRAINSTORM_DOC.md with the confirmed approach rationale

Current milestone: [milestone id from STATE.md]
Decisions: .planning/phases/<milestone>/DECISIONS.md
PLAN.md draft: .planning/phases/<milestone>/PLAN.md

If no approach can be confirmed from DECISIONS.md alone, output:
BRAINSTORM_BLOCKED: [question with 2-3 options A) B) C)]
STOP.

If design is confirmed, output:
BRAINSTORM_DONE: [selected approach name]
```

After subagent output:

**If `BRAINSTORM_DONE`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/write_exec_prompt_codex.sh
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```
→ PHASE 4

**If `BRAINSTORM_BLOCKED`:**

Route the design question to GStack. Spawn one review subagent:
```text
$plan-eng-review
Answer this design question from the Superpowers brainstorming gate.

Question:
[paste BRAINSTORM_BLOCKED question]

Return only:
ROLE: ENG
DECISION: [single clear answer]
QA_ANSWER_DONE
```
(Use `$plan-ceo-review` if question is about product scope or acceptance criteria.)

After `QA_ANSWER_DONE`:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "brainstorm-gate" "[role + decision]"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "[decision]"
```
→ Re-spawn brainstorming subagent (return to top of Phase 3)

---

## PHASE 4 — EXECUTE (HEADLESS TDD)

**Trigger:** `loop_state` is `SP_EXECUTING`

Build the Codex execution prompt:
```bash
source .agents/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/write_exec_prompt_codex.sh
cat "$GSD_EXEC_PROMPT"
```

Spawn one execution subagent and use the full contents of `EXEC_PROMPT.md`
as the **initial message**. That prompt already starts with:
```text
$test-driven-development
$verification-before-completion
```

Expected subagent outputs:
- `PHASE_COMPLETE`
- `PHASE_BLOCKED:[question with 2-3 options]`
- `PHASE_BLOCKED:TECH:[description]`

After subagent completes:

**If output contains `PHASE_COMPLETE`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_QA"
```
→ PHASE 5

**If output contains `PHASE_BLOCKED:`:**
Extract the question → route via GStack (same pattern as Phase 3 routing) → re-spawn executor

**If no signal** — check implicit done:
```bash
grep -c "^\- \[ \]" "$GSD_PLAN_FILE" && echo "tasks pending" || echo "all done"
```

### Phase 4b — Route Blocked Question

```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/route_question.sh "<question>"
```

Route by role (CEO or ENG), spawn GStack subagent, receive `QA_ANSWER_DONE`:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "sp-blocked" "[role + decision]"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "[decision]"
```
→ Re-spawn execution subagent (return to Phase 4)

---

## PHASE 5 — QA VALIDATION

**Trigger:** `loop_state` is `GSTACK_QA`

```bash
source .agents/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
grep -A10 -i "acceptance criteria" "$GSD_PLAN_FILE" | head -15
```

Spawn one plain validation subagent (no GStack skill here):
```text
Validate this completed milestone against PLAN.md acceptance criteria.

Read:
- PLAN.md
- DECISIONS.md
- BRAINSTORM_DOC.md
- shared_context.md

Then:
1. Run the relevant test commands
2. Check whether all unchecked tasks are done
3. Compare acceptance criteria against observed coverage

Return only:
QA_STATUS: PASSED or FAILED
ISSUES: [list issues if failed, or "none"]
QA_DONE
```

After `QA_DONE`:

**If `QA_STATUS: PASSED`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSD_DISPATCH"
```
→ PHASE 6

**If `QA_STATUS: FAILED`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "QA FAILED: [issues]"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"
```
→ Re-spawn execution subagent

---

## PHASE 6 — DISPATCH NEXT MILESTONE

**Trigger:** `loop_state` is `GSD_DISPATCH`

Spawn one dispatch subagent. Its **initial message must begin with**:
```text
$gsd-complete-milestone
$gsd-progress --next --force

Complete the current milestone and advance to the next.

Completed milestone: [milestone name]
Completed milestones so far: [list from GSS_STATE.json]

Roadmap:
[paste ROADMAP.md]

After GSD completion/progress finishes, run the deterministic sync script for
completed milestone before returning NEXT_PHASE or DELIVERED:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/mark_milestone_done.sh "[milestone name]"
```

Return only one of:
NEXT_PHASE: [milestone-id]
DELIVERED
```

**If `NEXT_PHASE: <id>`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_shared_context.sh
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<id>"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh --milestone
```
→ Return to PHASE 2

**If `DELIVERED`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "DELIVERED"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/print_summary.sh
```

---

## CONTEXT HYGIENE

After every subagent completion, run:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```

After each phase, run:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh --phase
```

---

## FILE COMMUNICATION CONTRACT

| File | Written by | Read by |
|------|-----------|---------|
| `REQUIREMENTS.md` | Orchestrator | Planning subagent (GSD) |
| `ROADMAP.md` | Planning subagent (GSD) | Orchestrator, review subagents |
| `PLAN.md` (draft) | Planning subagent (GSD) | Brainstorming gate subagent |
| `DECISIONS.md` | Review subagents (GStack) | Brainstorming gate, executor |
| `BRAINSTORM_DOC.md` | Brainstorming gate subagent | Executor (via EXEC_PROMPT) |
| `PLAN.md` (refined) | Brainstorming gate subagent | Executor |
| `EXEC_PROMPT.md` | write_exec_prompt_codex.sh | Executor subagent |

---

## RECOVERY

```bash
cat .planning/GSS_STATE.json
cat .planning/STATE.md
```

Resume from `loop_state` shown. Orchestrator identity resumes immediately.
