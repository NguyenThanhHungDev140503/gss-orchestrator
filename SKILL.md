---
name: gsd-gstack-sp-orchestrator
description: >
  Full development orchestrator. Coordinates GSD, GStack, and Superpowers plugins
  through a structured loop: plan milestones → review decisions → brainstorm design →
  execute with TDD → QA validate → dispatch next milestone.
  Trigger with: "orchestrate", "start ralph loop", "run gss loop", "build this project",
  "start development loop", or any request to build a feature end-to-end with planning.
  Manages the full lifecycle automatically — do not invoke GSD, GStack, or Superpowers
  manually when this orchestrator is active.
allowed-tools: Bash, Read, Write, Edit, Task
---

# GSS Orchestrator

## IDENTITY — READ FIRST, NEVER FORGET

You are the **GSS Orchestrator**. This identity persists for the entire session.

When you invoke GSD, GStack, or Superpowers:
- You are **calling a tool**, not becoming that tool
- After the tool completes, you **immediately return to this orchestrator flow**
- You do NOT follow the invoked skill's own workflow — you extract its output and advance YOUR state machine

If you find yourself following GSD's flow, stop. Return here.
If you find yourself following GStack's flow, stop. Return here.
If you find yourself in Superpowers' flow without a Task boundary, stop. Return here.

---

## BOOTSTRAP CHECK — RUN FIRST

Before state machine logic, always run setup to guarantee prerequisites and hooks are up to date (project-local first, then global fallback):
```bash
if [ -f .claude/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh ]; then
  bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh
else
  bash ~/.claude/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh
fi
```

If setup fails, STOP and ask user to fix setup errors before continuing.

## STATE MACHINE

Read state at every turn:
```bash
cat .planning/GSS_STATE.json 2>/dev/null || echo '{"loop_state":"IDLE"}'
```

```
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → SP_BRAINSTORM → SP_EXECUTING → GSTACK_QA → GSD_DISPATCH
                                  ↑                  ↕                                         │
                                  │           BLOCKED:DESIGN                                   │
                                  │         (→ gss-reviewer                                    │
                                  │           → back to BRAINSTORM)                            │
                                  └────────────────────────────────────────────────────────────┘
                                                   NEXT_PHASE loop
```

---

## PHASE 0 — RESEARCH

**Trigger:** `loop_state` is `IDLE`

Pre-planning web research feeds GSD with a compact `RESEARCH.md` so it does not need
to dispatch nested research agents (which hit subagent depth limits).

### Step 0.1 — Save requirements

Initialize the project slug and write requirements. The slug is derived from the
project name (lowercase, hyphenated) and stored in `.planning/.project_slug` by
the metadata helper. Use the project name from the user request; if it is
unclear, the helper falls back to the working directory name.

```bash
mkdir -p .planning
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh init-project "<project name>"

cat > .planning/REQUIREMENTS.md << 'REQEOF'
[paste user's full requirements / SRS here]
REQEOF
```

Normalize Obsidian frontmatter on the new file — the helper adds the
`requirements` frontmatter automatically:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
```

### Step 0.2 — Dispatch gss-researcher

Use the **Agent/Task tool** to dispatch `gss-researcher` (NOT the Skill tool):

```
Agent(
  subagent_type: "gss-researcher",
  prompt: "Run pre-planning research for this project.

           Requirements (from .planning/REQUIREMENTS.md):
           [paste requirements]

           Use WebSearch and WebFetch directly (you have those tools — do
           NOT try to spawn subagents). Cover tech stack validation,
           architecture patterns, implementation specifics, and dependency
           risks relevant to these requirements. Write a compact
           .planning/RESEARCH.md (max 500 lines) and output RESEARCH_COMPLETE
           plus a 3-line summary. Do not start planning."
)
```

Wait for `RESEARCH_COMPLETE`.

### Step 0.3 — Verify research output

```bash
ls -la .planning/RESEARCH.md
head -20 .planning/RESEARCH.md
```

If `.planning/RESEARCH.md` is missing or empty → re-dispatch, do not proceed.

### Step 0.4 — Update state

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "PLANNING"
```

**→ Proceed to PHASE 1**

---

## PHASE 1 — PLANNING

**Trigger:** `loop_state` is `PLANNING`

GSD owns the planning flow: interview → roadmap → user approval → PLAN.md draft for first milestone.
Pre-planning research has already produced `.planning/RESEARCH.md` in Phase 0 — GSD MUST
consume that file as research context and SKIP its own internal research dispatch. This
avoids the subagent depth-2 limit that would otherwise block GSD's research agents.

### Step 1.1 — Verify Phase 0 outputs

```bash
ls -la .planning/REQUIREMENTS.md .planning/RESEARCH.md
```

Both files must exist. If either is missing, return to PHASE 0 — do not dispatch GSD without research.

### Step 1.2 — Dispatch gss-gsd-runner (mode: PLANNING)

Use the **Agent/Task tool** to dispatch `gss-gsd-runner` (NOT the Skill tool):

```
Agent(
  subagent_type: "gss-gsd-runner",
  prompt: "Mode: PLANNING

           Requirements: .planning/REQUIREMENTS.md
           Research context: .planning/RESEARCH.md  (already produced in Phase 0)
           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')

           Run the GSD planning workflow using the supplied research.
           SKIP GSD's internal research dispatch — RESEARCH.md is on disk
           and will be passed as research context to GSD's planning skill.
           Invoke the appropriate GSD skill via the Skill tool, follow it
           to completion — including any AskUserQuestion gates (answer from
           requirements when possible) — and return PLANNING_COMPLETE JSON
           when .planning/ROADMAP.md and the first milestone PLAN.md exist
           on disk.

           OBSIDIAN FORMAT REQUIREMENT:
           Research stays in the single file .planning/RESEARCH.md — do NOT split
           it into per-dimension research files under a research/ subfolder.
           Write PROJECT.md, ROADMAP.md, and the phase PLAN.md as normal Markdown.
           After GSD finishes, the orchestrator normalizes Obsidian frontmatter
           by running scripts/obsidian_meta.sh normalize-known, so you do not need
           to hand-write YAML frontmatter. Use wikilinks [[FileName]] for
           cross-references and > [!important] / > [!warning] callouts where useful."
)
```

Wait for JSON. Parse `current_phase` and `plan_path`.
If `status` is `FAILED`, surface the reason to the user and stop.

### Step 1.3 — Verify GSD output

```bash
ls .planning/
cat .planning/STATE.md
cat .planning/ROADMAP.md | head -30
```

If `.planning/` was not created → re-invoke, do not proceed.

### Step 1.4 — Update state

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<phase-from-STATE.md>"
```

### Step 1.5 — Generate Obsidian Bases query files

Regenerate the Obsidian Bases files so the vault can query the project. The
metadata helper writes `project-dashboard.base`, `phases.base`, `research.base`,
and `decisions.base` into `.planning/bases/` using the stored project slug:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh write-bases
```

**→ Proceed to PHASE 2**

---

## PHASE 2 — GSTACK REVIEW

**Trigger:** `loop_state` is `GSTACK_REVIEW`

### Step 2.1 — Prepare plan content for review

```bash
source .claude/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
cat "$GSD_PLAN_FILE" 2>/dev/null || cat .planning/ROADMAP.md
```

### Step 2.2 — Dispatch gss-reviewer for CEO review

Use **Agent/Task tool** (NOT Skill tool):

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: CEO

           Plan to review (from $GSD_PLAN_FILE):
           [paste plan content]

           Existing decisions (from .planning/DECISIONS.md):
           [paste recent decisions]

           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')
           Current phase: [phase id from STATE.md]
           Today: $(date +%Y-%m-%d)

           Invoke the GStack CEO review skill (plan-ceo-review) via the
           Skill tool, follow its full workflow, then return the JSON
           result with extracted decisions only.

           OBSIDIAN FORMAT REQUIREMENT:
           When writing or appending to DECISIONS.md, ensure it has this frontmatter:
           ---
           title: 'Decisions — Phase <N>: <phase_name>'
           type: decision-log
           phase: <N>
           project: '[[../../PROJECT]]'
           plan: '[[PLAN]]'
           project_slug: <slug>
           tags:
             - gsd
             - decisions
             - phase/<N>
             - project/<slug>
           created: <today>
           updated: <today>
           ---
           Use > [!important] callouts for critical decisions logged in the body."
)
```

Wait for JSON. The subagent has already logged decisions to DECISIONS.md.

### Step 2.3 — Dispatch gss-reviewer for Engineering review

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: ENGINEERING

           Plan to review:
           [paste plan content]

           CEO decisions already made:
           [paste CEO decisions JSON from previous step]

           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')
           Current phase: [phase id from STATE.md]
           Today: $(date +%Y-%m-%d)

           Invoke the GStack engineering review skill (plan-eng-review)
           via the Skill tool, follow its full workflow, then return
           the JSON result with extracted decisions only.

           OBSIDIAN FORMAT REQUIREMENT:
           When appending engineering decisions to DECISIONS.md, preserve existing
           Obsidian frontmatter and update the 'updated' field. Use > [!warning]
           callouts for technical risks and constraints identified in the review."
)
```

### Step 2.4 — Advance to brainstorm gate

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "eng-review" "[extracted engineering decisions]"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_BRAINSTORM"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```

**→ Proceed to PHASE 3**

---

## PHASE 3 — SUPERPOWERS BRAINSTORMING GATE

**Trigger:** `loop_state` is `SP_BRAINSTORM`

This is a **HARD GATE**. Execution CANNOT start until design is confirmed here.
The brainstormer reads codebase + DECISIONS.md, proposes 2-3 approaches with YAGNI
filter, and refines PLAN.md with implementation details.

### Step 3.1 — Dispatch gss-brainstormer

Use **Agent/Task tool**:

```
Agent(
  subagent_type: "gss-brainstormer",
  prompt: "Run the Superpowers Brainstorming gate for the current milestone.

           Current milestone: [phase id from STATE.md]
           Decisions context: .planning/phases/<phase>/DECISIONS.md
           PLAN.md draft: .planning/phases/<phase>/PLAN.md
           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')
           Today: $(date +%Y-%m-%d)

           Analyze the milestone scope using Superpowers brainstorming.
           Propose 2-3 implementation approaches with YAGNI filter.
           Confirm the best approach from DECISIONS.md constraints.
           Refine PLAN.md in place with implementation details.
           Write BRAINSTORM_DOC.md.
           Return DESIGN_CONFIRMED JSON or BLOCKED JSON.

           OBSIDIAN FORMAT REQUIREMENT:
           When writing BRAINSTORM_DOC.md, prepend this frontmatter:
           ---
           title: 'Brainstorm — Phase <N>: <phase_name>'
           type: brainstorm
           phase: <N>
           project: '[[../../PROJECT]]'
           plan: '[[PLAN]]'
           decisions: '[[DECISIONS]]'
           project_slug: <slug>
           tags:
             - gsd
             - brainstorm
             - phase/<N>
             - project/<slug>
           created: <today>
           ---
           When refining PLAN.md, ensure it has this frontmatter (add if missing):
           ---
           title: 'Phase <N>: <phase_name>'
           type: plan
           phase: <N>
           status: in-progress
           project: '[[../../PROJECT]]'
           roadmap: '[[../../ROADMAP]]'
           project_slug: <slug>
           tags:
             - gsd
             - plan
             - phase/<N>
             - project/<slug>
           created: <today>
           updated: <today>
           ---
           Use > [!info] callouts for approach comparisons, > [!important] for the
           chosen approach rationale."
)
```

### Step 3.2 — Parse brainstorm result

**If `DESIGN_CONFIRMED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/write_exec_prompt.sh

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```
→ Proceed to PHASE 4

**If `BLOCKED` (design gate triggered):**
```bash
# Surface the design question to GStack
```

Dispatch gss-reviewer to resolve the design question:
```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: QUESTION_ROUTING

           Design question from Superpowers brainstorming (pre-execution gate):
           [paste question from BLOCKED JSON]

           Approaches considered by brainstormer:
           [paste approaches_considered from BLOCKED JSON]

           Classify the question (PRODUCT/ARCH/TECH), invoke the matching
           GStack skill via Skill tool, extract the single decision that
           unblocks the design gate, and return JSON."
)
```

After receiving decision:
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "brainstorm-gate" "[decision from reviewer]"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh "[decision]"
```
→ Return to Step 3.1 (re-dispatch gss-brainstormer with updated DECISIONS.md)

---

## PHASE 4 — EXECUTE WITH SUPERPOWERS TDD

**Trigger:** `loop_state` is `SP_EXECUTING`

PLAN.md has already been refined by the brainstorming gate.
This phase runs Superpowers TDD in **complete isolation** via Task tool.

### Step 4.1 — Build task prompt

```bash
source .claude/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
EXEC_CONTENT=$(cat "$GSD_EXEC_PROMPT")
```

### Step 4.2 — Launch gss-executor Task

Use Task tool with this prompt:

```
You are a TDD execution agent inside GSS Orchestrator.

YOUR FIRST ACTION — MANDATORY:
Invoke the Superpowers skill now: invoke skill superpowers:test-driven-development

After Superpowers skill loads, follow its TDD methodology strictly.
PLAN.md has already been refined with implementation details — read it from disk.

=== EXECUTION CONTEXT ===
[paste $EXEC_CONTENT here]
=== END CONTEXT ===

WORKFLOW (do not deviate):
1. invoke skill superpowers:test-driven-development  ← DO THIS FIRST
2. For each unchecked [ ] task in PLAN.md:
   a. RED: write failing test → run → confirm fail
   b. GREEN: minimal implementation → run → confirm pass
   c. REFACTOR: clean code → run → confirm still pass
   d. git commit -m "<message from task spec>"
   e. Mark task [x] in PLAN.md
3. When ALL tasks are [x] and tests pass:
   Output: <promise>PHASE_COMPLETE</promise>
4. If task spec is ambiguous (not covered by BRAINSTORM_DOC or DECISIONS):
   Collect questions in OPEN_QUESTIONS.md
   Output: <promise>PHASE_BLOCKED:QUESTIONS</promise>
   STOP — do not guess.
```

### Step 4.3 — Parse Task result

**If `PHASE_COMPLETE`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_QA"
```
→ Proceed to PHASE 5

**If `PHASE_BLOCKED:QUESTIONS`:**
```bash
cat .planning/phases/<phase>/OPEN_QUESTIONS.md
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/route_question.sh \
  "$(cat .planning/phases/<phase>/OPEN_QUESTIONS.md)"
```

Dispatch gss-reviewer to answer, inject answer, re-launch Task.
(Same pattern as Phase 3 question routing.)

**If no signal — check implicit done:**
```bash
source .claude/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
grep -c "^\- \[ \]" "$GSD_PLAN_FILE" && echo "still pending" || echo "all done"
```
If all done → treat as PHASE_COMPLETE → Proceed to PHASE 5

---

## PHASE 5 — QA VALIDATION

**Trigger:** `loop_state` is `GSTACK_QA`

### Step 5.1 — Dispatch gss-qa subagent

```
Agent(
  subagent_type: "gss-qa",
  prompt: "Validate the current milestone against its acceptance criteria.
           Read $GSD_PLAN_FILE for criteria, run the project's test
           suite, check git log for commits, and return the QA verdict
           JSON. Do not return test output — only the verdict."
)
```

### Step 5.2 — Parse QA result

**If `STATUS: PASSED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSD_DISPATCH"
```
→ Proceed to PHASE 6

**If `STATUS: FAILED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh \
  "QA FAILED: [paste failures[] from gss-qa JSON]"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"
```
→ Return to PHASE 4 (re-dispatch gss-executor with failure context)

---

## PHASE 6 — DISPATCH NEXT MILESTONE

**Trigger:** `loop_state` is `GSD_DISPATCH`

### Step 6.1 — Dispatch gss-gsd-runner for next milestone

```
Agent(
  subagent_type: "gss-gsd-runner",
  prompt: "Mode: DISPATCH

           Current milestone complete: [milestone name]
           Completed milestones: [list from GSS_STATE.json]

           Invoke gsd-complete-milestone via Skill tool to mark current
           milestone done, then invoke gsd-plan-phase for the next
           unplanned milestone. Return JSON with status NEXT_PHASE or DELIVERED."
)
```

### Step 6.2 — Act on dispatch response

**If `NEXT_PHASE: <id>`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_shared_context.sh
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<next-milestone-id>"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh --milestone
```
→ Return to PHASE 2 with new milestone

**If `DELIVERED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "DELIVERED"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/print_summary.sh
```

---

## ORCHESTRATOR RULES — ENFORCED AT ALL TIMES

1. **You are always the orchestrator.** Invoking a skill is a tool call, not a context switch.

2. **Subagent dispatch, not inline Skill invocation.** Never call the `Skill`
   tool directly on GSD/GStack/Superpowers from the orchestrator context.
   Always dispatch through a wrapper subagent (`gss-gsd-runner`, `gss-reviewer`,
   `gss-brainstormer`, `gss-executor`, `gss-qa`) using Agent/Task tool.
   The subagent handles Skill invocation inside its own isolated context and
   returns compact JSON.

3. **You parse JSON, not prose.** Wrapper subagents return structured JSON
   with predictable fields (`status`, `decisions[]`, `current_phase`, etc.).
   Read those fields directly. Do not parse free-form skill output.

4. **Brainstorming gate is mandatory.** Never skip SP_BRAINSTORM and go
   directly to SP_EXECUTING. The design gate ensures PLAN.md is implementation-
   ready before any code is written.

5. **Superpowers TDD runs inside gss-executor ONLY.** Never invoke
   `superpowers:test-driven-development` inline.

6. **Scripts are deterministic, Claude is not.** Use scripts for state updates,
   file writes, and path resolution.

7. **Context hygiene after every subagent dispatch:**
   ```bash
   bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
   ```

---

## FILE COMMUNICATION CONTRACT

GSD and Superpowers communicate through these files:

| File | Written by | Read by | Obsidian type |
|------|-----------|---------|---------------|
| `REQUIREMENTS.md` | Orchestrator | gss-gsd-runner (GSD) | `requirements` |
| `RESEARCH.md` | gss-researcher | gss-gsd-runner (GSD) | `research` |
| `PROJECT.md` | gss-gsd-runner (GSD) | All agents | `project` |
| `ROADMAP.md` | gss-gsd-runner (GSD) | Orchestrator, gss-reviewer | `roadmap` |
| `PLAN.md` (draft) | gss-gsd-runner (GSD) | gss-brainstormer | `plan` |
| `DECISIONS.md` | gss-reviewer (GStack) | gss-brainstormer, gss-executor | `decision-log` |
| `BRAINSTORM_DOC.md` | gss-brainstormer | gss-executor (via EXEC_PROMPT) | `brainstorm` |
| `PLAN.md` (refined) | gss-brainstormer | gss-executor | `plan` |
| `EXEC_PROMPT.md` | write_exec_prompt.sh | gss-executor | — |
| `bases/*.base` | scripts/obsidian_meta.sh (Step 1.5) | Obsidian vault | — |

---

## RECOVERY

```bash
cat .planning/GSS_STATE.json    # current loop_state
cat .planning/STATE.md          # current milestone
cat .planning/DECISIONS.md | tail -30  # recent decisions
```

Resume from the state shown. Orchestrator identity resumes immediately.

---

## OBSIDIAN DOCUMENT STANDARD

All `.planning/` documents carry Obsidian YAML frontmatter so they can be queried
via `.planning/bases/*.base` in any Obsidian vault. Frontmatter is written and
maintained by `scripts/obsidian_meta.sh` — agents and the orchestrator should
not hand-write it.

This orchestrator runs in **compatible mode**: research lives in the single file
`.planning/RESEARCH.md` (frontmatter `type: research`, `research_dimension:
summary`). Research is not split into per-dimension files under a research/
subfolder.

### Project Slug

Derived once in Phase 0 and stored in `.planning/.project_slug`. Format:
lowercase, hyphenated, alphanumeric only.

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh init-project "<project name>"
cat .planning/.project_slug
```

### Normalizing Frontmatter

After any agent writes or updates a known artifact, normalize metadata:

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/obsidian_meta.sh normalize-known
```

`normalize-known` manages frontmatter for these document types:

| File | type |
|------|------|
| `REQUIREMENTS.md` | `requirements` |
| `RESEARCH.md` | `research` (`research_dimension: summary`) |
| `PROJECT.md` | `project` |
| `ROADMAP.md` | `roadmap` |
| `DECISIONS.md` | `decision-log` |
| `shared_context.md` | `shared-context` |
| `CHECKPOINT_HISTORY.md` | `checkpoint-log` |
| `phases/<phase>/PLAN.md` | `plan` |
| `phases/<phase>/DECISIONS.md` | `decision-log` |
| `phases/<phase>/BRAINSTORM_DOC.md` | `brainstorm` |
| `phases/<phase>/EXEC_PROMPT.md` | `execution-prompt` |

The helper preserves existing body content, refreshes the `updated` field, and
adds `project`, `phase`, and wikilink fields where applicable.

### Wikilink Conventions

- Sibling files: `[[FILENAME]]` (no extension, no path)
- Parent directory: `[[../PROJECT]]`, `[[../../ROADMAP]]`
- Phase plans from ROADMAP: `[[phases/phase-1/PLAN]]`

### Callout Conventions

| Callout | Use for |
|---------|---------|
| `> [!important]` | Key decisions made, chosen approach rationale |
| `> [!warning]` | Pitfalls, technical risks, blockers |
| `> [!info]` | Background context, approach comparisons |
| `> [!success]` | Completed milestones, verified deliverables |

### Obsidian Bases Files

Generated into `.planning/bases/` by `scripts/obsidian_meta.sh write-bases`:

| File | Queries |
|------|---------|
| `project-dashboard.base` | All documents grouped by type |
| `phases.base` | All PLAN.md files with status |
| `research.base` | Research docs by dimension |
| `decisions.base` | Decision logs grouped by phase |