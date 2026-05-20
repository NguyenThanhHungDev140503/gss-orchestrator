---
name: gsd-gstack-sp-orchestrator
description: >
  Full development orchestrator. Coordinates GSD, GStack, and Superpowers plugins
  through a structured loop: analyze requirements → plan phases → review decisions →
  execute with TDD → QA validate → dispatch next phase.
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
IDLE → RESEARCH → PLANNING → GSTACK_REVIEW → SP_EXECUTING → GSTACK_QA → GSD_DISPATCH
                                        ↕
                                   GSTACK_QA (blocking Qs from Superpowers)
```

---

## PHASE 0 — RESEARCH (trước khi GSD planning)

**Trigger:** `loop_state` is `IDLE`

**Mục đích:** Thu thập technical context từ internet TRƯỜC khi GSD tạo plan.
GSD runner sẽ nhận research findings làm input — không cần GSD dispatch research agents nội bộ.

Điều này giải quyết giới hạn subagent nesting: research chạy ở depth 1
(orchestrator → gss-researcher), không cần depth 2 (orchestrator → gsd-runner → research agent).

### Step 0.1 — Lưu requirements

```bash
mkdir -p .planning
cat > .planning/REQUIREMENTS.md << 'REQEOF'
[paste user's full requirements / SRS here]
REQEOF
```

### Step 0.2 — Dispatch gss-researcher (Task tool)

Use Task tool to invoke gss-researcher subagent:

```
Task(
  subagent: gss-researcher,
  prompt: "Research technical context for this project.
           Requirements are at .planning/REQUIREMENTS.md.
           Use WebSearch and WebFetch directly.
           Write findings to .planning/RESEARCH.md.
           Return RESEARCH_COMPLETE when done."
)
```

gss-researcher dùng WebSearch và WebFetch trực tiếp — không spawn subagent.
Sau khi Task complete, `.planning/RESEARCH.md` đã có sẵn.

### Step 0.3 — Update state

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "PLANNING"
```

**→ Proceed to PHASE 1**

---

## PHASE 1 — PLANNING (GSD với research context)

**Trigger:** `loop_state` is `PLANNING`

GSD không cần dispatch research agents nữa — research đã xong ở Phase 0.
Inject research findings vào GSD invocation:

### Step 1.1 — Đọc research findings

**Trigger (original):** `loop_state` is `IDLE` (now handled by Phase 0)

### Step 1.2 — Dispatch gss-gsd-runner subagent

Use the **Agent/Task tool** to dispatch `gss-gsd-runner` (NOT the Skill tool).
The runner loads GSD via Skill tool inside its own context, follows the full
workflow, and returns a structured JSON result. The orchestrator never sees
GSD prose.

```
Agent(
  subagent_type: "gss-gsd-runner",
  prompt: "Mode: PLANNING

           Requirements (from .planning/REQUIREMENTS.md):
           [paste requirements]

           Research findings (from .planning/RESEARCH.md):
           [paste research summary]

           Run the full GSD planning workflow. Invoke the appropriate
           GSD skill via the Skill tool, follow it to completion, and
           return PLANNING_COMPLETE JSON when .planning/ROADMAP.md and
           the first phase PLAN.md exist on disk."
)
```

Wait for the subagent to return JSON. Parse `current_phase` and `plan_path`.
If `status` is `FAILED`, surface the reason to the user and stop.

### Step 1.2b — Verify GSD output (YOU do this after subagent returns)

After GSD finishes its complete flow, control returns to YOU:
```bash
ls .planning/
cat .planning/STATE.md
cat .planning/ROADMAP.md
```

Extract current phase from STATE.md.
If `.planning/` was not created → re-invoke GSD, do not proceed.

### Step 1.3 — Update state (YOU run this script)

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<phase-from-STATE.md>"
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

           Invoke the GStack CEO review skill (plan-ceo-review) via the
           Skill tool, follow its full workflow, then return the JSON
           result with extracted decisions only."
)
```

Wait for JSON. The subagent has already logged decisions to DECISIONS.md.

### Step 2.3 — Extract CEO decisions from JSON (no script call needed)

Read `decisions[]` from the returned JSON. The subagent already appended them
to DECISIONS.md. No need to call `log_decision.sh` here.

### Step 2.4 — Dispatch gss-reviewer for Engineering review

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: ENGINEERING

           Plan to review:
           [paste plan content]

           CEO decisions already made:
           [paste CEO decisions JSON from previous step]

           Invoke the GStack engineering review skill (plan-eng-review)
           via the Skill tool, follow its full workflow, then return
           the JSON result with extracted decisions only."
)
```

### Step 2.5 — Write EXEC_PROMPT and advance state

```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "eng-review" "[extracted engineering decisions]"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/write_exec_prompt.sh

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
```

**→ Proceed to PHASE 3**

---

## PHASE 3 — EXECUTE WITH SUPERPOWERS

**Trigger:** `loop_state` is `SP_EXECUTING`

This phase runs Superpowers in **complete isolation** via Task tool.
Superpowers MUST be explicitly invoked inside the task.

### Step 3.1 — Build task prompt

```bash
source .claude/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
EXEC_CONTENT=$(cat "$GSD_EXEC_PROMPT")
```

### Step 3.2 — Launch Task with mandatory Superpowers invocation

Use Task tool with this prompt:

```
You are a TDD execution agent inside GSS Orchestrator.

YOUR FIRST ACTION — MANDATORY:
Invoke the Superpowers skill now: invoke skill superpowers

After Superpowers skill loads, use its brainstorming capability to analyze
each task before coding. Follow Superpowers' TDD methodology strictly.

=== EXECUTION CONTEXT ===
[paste $EXEC_CONTENT here]
=== END CONTEXT ===

WORKFLOW (do not deviate):
1. invoke skill superpowers  ← DO THIS FIRST
2. For each unchecked [ ] task in PLAN.md:
   a. Superpowers brainstorm: clarify requirements, surface questions
   b. If questions arise: write them to OPEN_QUESTIONS.md, then output:
      <promise>PHASE_BLOCKED:QUESTIONS</promise>
      STOP — do not guess, do not continue.
   c. RED: write failing test → run → confirm fail
   d. GREEN: minimal implementation → run → confirm pass
   e. REFACTOR: clean code → run → confirm still pass
   f. git commit -m "<message from task spec>"
   g. Mark task [x] in PLAN.md
3. When ALL tasks are [x] and tests pass:
   Output: <promise>PHASE_COMPLETE</promise>
```

### Step 3.3 — Parse Task result (YOU do this)

After Task tool returns, check result:

**If `PHASE_COMPLETE`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_QA"
```
→ Proceed to PHASE 4

**If `PHASE_BLOCKED:QUESTIONS`:**
```bash
cat .planning/phases/<phase>/OPEN_QUESTIONS.md
```
→ Proceed to PHASE 3b

**If no signal (implicit done — all tasks [x]):**
```bash
source .claude/skills/gsd-gstack-sp-orchestrator/scripts/resolve_gsd_paths.sh
grep -c "^\- \[ \]" "$GSD_PLAN_FILE" && echo "still pending" || echo "all done"
```
If all done → treat as PHASE_COMPLETE → Proceed to PHASE 4

**If Task tool unavailable:** Run fallback:
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/run_phase.sh
# Check exit code: 0=done, 1=blocked, 2=max-iter
```

### Phase 3b — Route Superpowers questions to GStack

When `PHASE_BLOCKED:QUESTIONS`:

**Step 3b.1 — Classify and route each question**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/route_question.sh \
  "$(cat .planning/phases/<phase>/OPEN_QUESTIONS.md)"
```

**Step 3b.2 — Dispatch gss-reviewer to answer questions**

Use **Agent/Task tool** (NOT Skill tool):

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: QUESTION_ROUTING

           Questions from Superpowers brainstorming:
           [paste OPEN_QUESTIONS.md content]

           Routing hint (from route_question.sh):
           [paste classification output]

           For each question, classify (PRODUCT/ARCH/TECH/QA/INFRA),
           invoke the matching GStack skill via Skill tool, follow it
           to completion, then return JSON with the unblocking decision."
)
```

**Step 3b.3 — Inject answers and retry (YOU do this)**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/log_decision.sh \
  "sp-questions" "[extracted answers]"

bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh \
  "[extracted answers]"

# Clear questions file
> .planning/phases/<phase>/OPEN_QUESTIONS.md
```
→ Return to Step 3.2 (re-launch Task with updated EXEC_PROMPT)

---

## PHASE 4 — QA VALIDATION

**Trigger:** `loop_state` is `GSTACK_QA`

### Step 4.1 — Dispatch gss-qa subagent

Use **Agent/Task tool**. The `gss-qa` subagent runs the test suite, reads
acceptance criteria, and returns a compact verdict JSON.

```
Agent(
  subagent_type: "gss-qa",
  prompt: "Validate the current phase against its acceptance criteria.
           Read $GSD_PLAN_FILE for criteria, run the project's test
           suite, check git log for commits, and return the QA verdict
           JSON. Do not return test output — only the verdict."
)
```

Wait for JSON. Do NOT use the Skill tool here — `gss-qa` already encapsulates
the QA workflow and only emits PASSED/FAILED JSON.

### Step 4.2 — Parse QA result (YOU do this)

**If `STATUS: PASSED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSD_DISPATCH"
```
→ Proceed to PHASE 5

**If `STATUS: FAILED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/inject_answer.sh \
  "QA FAILED: [paste failures[] from gss-qa JSON]"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "SP_EXECUTING"
```
→ Return to PHASE 3 (re-dispatch gss-executor)

---

## PHASE 5 — DISPATCH

**Trigger:** `loop_state` is `GSD_DISPATCH`

### Step 5.1 — Dispatch gss-gsd-runner for next phase

Use **Agent/Task tool** (NOT Skill tool):

```
Agent(
  subagent_type: "gss-gsd-runner",
  prompt: "Mode: DISPATCH

           Current phase complete: [phase name]
           Completed phases: [list from GSS_STATE.json]

           Read .planning/ROADMAP.md and .planning/STATE.md, determine
           the next unplanned phase, invoke gsd-plan-phase via Skill
           tool to create its PLAN.md, then return JSON with status
           NEXT_PHASE / DELIVERED."
)
```

Wait for JSON.

### Step 5.2 — Act on GSD response (YOU do this)

**If `NEXT_PHASE: <id>`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_shared_context.sh
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "GSTACK_REVIEW" "<next-phase-id>"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh --milestone
```
→ Return to PHASE 2 with new phase

**If `DELIVERED`:**
```bash
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/update_state.sh "DELIVERED"
bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/print_summary.sh
```

---

## ORCHESTRATOR RULES — ENFORCED AT ALL TIMES

1. **You are always the orchestrator.** Invoking a skill is a tool call, not a context switch.

2. **Subagent dispatch, not inline Skill invocation.** Never call the `Skill`
   tool directly on GSD/GStack/Superpowers from the orchestrator context.
   Always dispatch through a wrapper subagent (`gss-gsd-runner`,
   `gss-reviewer`, `gss-executor`, `gss-qa`, `gss-researcher`) using
   Agent/Task tool. The subagent handles Skill invocation inside its own
   isolated context and returns compact JSON.

3. **You parse JSON, not prose.** Wrapper subagents return structured JSON
   with predictable fields (`status`, `decisions[]`, `current_phase`, etc.).
   Read those fields directly. Do not parse free-form skill output.

4. **Superpowers runs inside gss-executor ONLY.** Never invoke Superpowers
   inline. The `gss-executor` subagent is the sole execution boundary.

5. **Scripts are deterministic, Claude is not.** Use scripts for state
   updates, file writes, and path resolution. Subagents update DECISIONS.md
   themselves; the orchestrator only updates `GSS_STATE.json` and triggers
   checkpoints.

6. **Context hygiene after every subagent dispatch:**
   ```bash
   bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh
   ```

---

## RECOVERY

```bash
cat .planning/GSS_STATE.json    # current loop_state
cat .planning/STATE.md          # current phase
cat .planning/DECISIONS.md | tail -30  # recent decisions
```

Resume from the state shown. Orchestrator identity resumes immediately.
