# GSS Orchestrator (Codex) — Phase 5.7: Superpowers Systematic Debugging

*This file is loaded by SKILL.codex.md when `loop_state` is `SP_DEBUGGING`.*

---

## PHASE 5.7 — SUPERPOWERS SYSTEMATIC DEBUGGING

**Trigger:** `loop_state` is `SP_DEBUGGING`

Validation failures do not go straight back to implementation. First, run a
root-cause pass so the executor fixes the cause, not the symptom.

Spawn one debugging subagent. Its **initial message must begin with**:
```text
$systematic-debugging
Investigate the latest validation failure before implementation retry.

Read:
- PLAN.md
- DECISIONS.md
- BRAINSTORM_DOC.md
- DESIGN_QA.md if present
- DOCS_REPORT.md if present
- DEBUG_REPORT.md if present
- logs under .planning/phases/<phase>/logs
- current EXEC_PROMPT.md injected failure context

Follow the systematic-debugging workflow: reproduce or inspect the failure,
compare against working patterns, identify root cause, and prepare a fix handoff.
Do not modify implementation code.

Write .planning/phases/<phase>/DEBUG_REPORT.md.
Use scripts/obsidian_meta.sh to normalize metadata; do not hand-write YAML.
Inject the concise root-cause handoff into EXEC_PROMPT.md with inject_answer.sh.

Return only:
DEBUG_STATUS: ROOT_CAUSE_FOUND or NEEDS_MORE_EVIDENCE
ROOT_CAUSE: [specific cause]
FAILING_TEST: [specific behavior executor should test]
MINIMAL_FIX: [specific direction]
DEBUG_DONE
```

After `DEBUG_DONE`:

**If `DEBUG_STATUS: ROOT_CAUSE_FOUND`:**
```bash
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_EXECUTING"
```
→ PHASE 4

**If `DEBUG_STATUS: NEEDS_MORE_EVIDENCE`:**
Surface the requested evidence to the user or the appropriate GStack reviewer.
Do not return to execution until root cause is known.
