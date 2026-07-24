# GSS Orchestrator — Phase 4 + 4b: Execute with Superpowers TDD

*This file is loaded by SKILL.md when `loop_state` is `SP_EXECUTING`.*

---

## PHASE 4 — EXECUTE WITH SUPERPOWERS TDD

**Trigger:** `loop_state` is `SP_EXECUTING`

PLAN.md has already been refined by the brainstorming gate.
This phase runs Superpowers TDD in **complete isolation** via Task tool.

### Step 4.1 — Build task prompt

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
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
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_QA"
```
→ Proceed to PHASE 5

**If `PHASE_BLOCKED:QUESTIONS`:**
```bash
cat .planning/phases/<phase>/OPEN_QUESTIONS.md
bash $(cat .planning/.gss_home)/scripts/route_question.sh \
  "$(cat .planning/phases/<phase>/OPEN_QUESTIONS.md)"
```

Dispatch gss-reviewer to answer, inject answer, re-launch Task.
(Same pattern as Phase 3 question routing.)

**If no signal — check implicit done:**
```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
grep -c "^\- \[ \]" "$GSD_PLAN_FILE" && echo "still pending" || echo "all done"
```
If all done → treat as PHASE_COMPLETE → Proceed to PHASE 5
