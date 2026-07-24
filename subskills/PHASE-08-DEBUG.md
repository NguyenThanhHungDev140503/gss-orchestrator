# GSS Orchestrator — Phase 5.7: Superpowers Systematic Debugging

*This file is loaded by SKILL.md when `loop_state` is `SP_DEBUGGING`.*

---

## PHASE 5.7 — SUPERPOWERS SYSTEMATIC DEBUGGING

**Trigger:** `loop_state` is `SP_DEBUGGING`

Failures from functional QA, design QA, or docs do not go straight back to
implementation. The orchestrator first dispatches a root-cause specialist so
the next executor run fixes the cause, not the symptom.

### Step 5.7.1 — Dispatch gss-debugger

```
Agent(
  subagent_type: "gss-debugger",
  prompt: "Investigate the latest validation failure before implementation retry.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - $GSD_BRAINSTORM_DOC
           - $GSD_DESIGN_QA_REPORT if present
           - $GSD_DOCS_REPORT if present
           - $GSD_LOG_DIR
           - current EXEC_PROMPT.md injected failure context

           Invoke superpowers:systematic-debugging via the Skill tool and follow
           its full workflow. Do not modify implementation code.
           Write the compact root-cause report to
           .planning/phases/<phase>/DEBUG_REPORT.md and inject the fix handoff
           into EXEC_PROMPT.md using scripts/inject_answer.sh.
           Normalize metadata with scripts/obsidian_meta.sh.

           Return DEBUG JSON only."
)
```

### Step 5.7.2 — Parse debug result

**If `status: ROOT_CAUSE_FOUND`:**
```bash
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_EXECUTING"
```
→ Return to PHASE 4 with DEBUG_REPORT.md context

**If `status: NEEDS_MORE_EVIDENCE`:**
Surface the requested evidence to the user or the appropriate GStack reviewer.
Do not return to implementation until root cause is known.
