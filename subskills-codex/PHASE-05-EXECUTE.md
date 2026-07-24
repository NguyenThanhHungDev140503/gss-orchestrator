# GSS Orchestrator (Codex) — Phase 4: Execute (Headless TDD)

*This file is loaded by SKILL.codex.md when `loop_state` is `SP_EXECUTING`.*

---

## PHASE 4 — EXECUTE (HEADLESS TDD)

**Trigger:** `loop_state` is `SP_EXECUTING`

Build the Codex execution prompt:
```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
bash $(cat .planning/.gss_home)/scripts/write_exec_prompt_codex.sh
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
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_QA"
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
bash $(cat .planning/.gss_home)/scripts/route_question.sh "<question>"
```

Route by role (CEO or ENG), spawn GStack subagent, receive `QA_ANSWER_DONE`:
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "sp-blocked" "[role + decision]"
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh "[decision]"
```
→ Re-spawn execution subagent (return to Phase 4)
