---
name: gsd-gstack-sp-orchestrator
description: >
  Full development orchestrator for Codex. Coordinates GSD planning, GStack reviews,
  and Superpowers-style TDD execution through a structured loop:
  research → plan → review → execute → QA → dispatch.
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
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → SP_EXECUTING → GSTACK_QA → GSD_DISPATCH
```

---

## PHASE 0 — RESEARCH

**Trigger:** `loop_state` is `IDLE`

Save requirements:
```bash
mkdir -p .planning
cat > .planning/REQUIREMENTS.md << 'EOF'
[paste user's requirements here]
EOF
```

Spawn one subagent for research:
```text
Spawn one subagent to research technical context for this project.
The subagent should:
1. Read .planning/REQUIREMENTS.md
2. Use web search to find: best libraries, architecture patterns, known pitfalls
3. Write findings to .planning/RESEARCH.md in this format:

## Stack Recommendations
- [library]: [reason, version]

## Architecture Decisions
- [pattern]: [trade-off]

## Avoid
- [anti-pattern]: [reason]

When done, output the single word: RESEARCH_COMPLETE
```

After subagent outputs `RESEARCH_COMPLETE`:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "PLANNING"
```

---

## PHASE 1 — PLANNING

**Trigger:** `loop_state` is `PLANNING`

Read research:
```bash
cat .planning/RESEARCH.md
```

Spawn one planning subagent.
Its **initial message must begin with**:
```text
$gsd-new-project --auto
Initialize or refresh the planning artifacts for this project.

Requirements:
[user requirements]

Research findings already completed — use these first and do not redo research
unless a required fact is missing:
[paste .planning/RESEARCH.md]

If planning artifacts already exist, update them instead of replacing unrelated work.
When finished, output only:
PLANNING_DONE: [current phase name]
```

After subagent outputs `PLANNING_DONE`:
```bash
cat .planning/STATE.md
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<phase>"
```

---

## PHASE 2 — REVIEW

**Trigger:** `loop_state` is `GSTACK_REVIEW`

Read phase plan:
```bash
source .agents/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
cat "$GSD_PLAN_FILE" 2>/dev/null || cat .planning/ROADMAP.md
```

### CEO Review

Spawn one review subagent.
Its **initial message must begin with**:
```text
$plan-ceo-review
Review this phase plan in hold-scope mode.

Plan to review:
[paste plan content]

Return only:
DECISIONS_START
1. ...
2. ...
DECISIONS_END
CEO_DONE
```

After `CEO_DONE`, extract numbered decisions and log:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "ceo-review" "[extracted numbered decisions]"
```

### Engineering Review

Spawn one review subagent.
Its **initial message must begin with**:
```text
$plan-eng-review
Review this phase plan for architecture, dependencies, constraints, and testability.

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

bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/write_exec_prompt_codex.sh

bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"

bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```

---

## PHASE 3 — EXECUTE

**Trigger:** `loop_state` is `SP_EXECUTING`

Build the Codex execution prompt:
```bash
source .agents/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/write_exec_prompt_codex.sh
cat "$GSD_EXEC_PROMPT"
```

Spawn one execution subagent and use the full contents of `EXEC_PROMPT.md`
as the **initial message**.

That prompt must start with:
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
→ PHASE 4

**If output contains `PHASE_BLOCKED:`:**
Extract the question → PHASE 3b

**If no signal** — check implicit done:
```bash
grep -c "^\- \[ \]" "$GSD_PLAN_FILE" && echo "tasks pending" || echo "all done"
```

### Phase 3b — Route Blocked Question

```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/route_question.sh "<question>"
```

Then route by role:

If role is `CEO`, spawn one subagent whose initial message begins with:
```text
$plan-ceo-review
Answer this blocked execution question with one clear decision.

Question:
[question with options]

Return only:
ROLE: CEO
DECISION: [single clear answer]
QA_ANSWER_DONE
```

If role is `ENG`, spawn one subagent whose initial message begins with:
```text
$plan-eng-review
Answer this blocked execution question with one clear implementation decision.

Question:
[question with options]

Return only:
ROLE: ENG
DECISION: [single clear answer]
QA_ANSWER_DONE
```

If role is `QA`, spawn one plain validation subagent (no GStack umbrella skill) and instruct it to:
- read `PLAN.md` and `DECISIONS.md`
- answer the question conservatively
- return only:
```text
ROLE: QA
DECISION: [single clear answer]
QA_ANSWER_DONE
```

After `QA_ANSWER_DONE`:
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "sp-blocked" "[role + decision]"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "[decision]"
```
→ Re-spawn execution subagent (return to Phase 3)

---

## PHASE 4 — QA VALIDATION

**Trigger:** `loop_state` is `GSTACK_QA`

```bash
source .agents/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
grep -A10 -i "acceptance criteria" "$GSD_PLAN_FILE" | head -15
```

Spawn one plain validation subagent.
Do **not** use `$qa` here; that skill is for interactive web-app QA/fix loops,
not phase acceptance validation.

Validation subagent instructions:
```text
Validate this completed phase against PLAN.md acceptance criteria.

Read:
- PLAN.md
- DECISIONS.md
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
→ PHASE 5

**If `QA_STATUS: FAILED`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "QA FAILED: [issues]"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"
```
→ Re-spawn execution subagent

---

## PHASE 5 — DISPATCH

**Trigger:** `loop_state` is `GSD_DISPATCH`

Spawn one dispatch subagent.
Its **initial message must begin with**:
```text
$gsd-progress --next --force
Advance the planning workflow after this phase is complete.

Completed phases:
[list from GSS_STATE.json]

Roadmap:
[paste ROADMAP.md]

Return only one of:
NEXT_PHASE: [phase-id]
DELIVERED
```

**If `NEXT_PHASE: <id>`:**
```bash
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_shared_context.sh
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<id>"
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh --milestone
```
→ Return to PHASE 2

**If `DELIVERED`:**
```bash
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

## RECOVERY

```bash
cat .planning/GSS_STATE.json
cat .planning/STATE.md
```

Resume from `loop_state` shown. Orchestrator identity resumes immediately.
