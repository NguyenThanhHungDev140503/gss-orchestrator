# GSS Orchestrator (Codex) — Phase 3: Superpowers Brainstorming Gate

*This file is loaded by SKILL.codex.md when `loop_state` is `SP_BRAINSTORM`.*

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
bash $(cat .planning/.gss_home)/scripts/write_exec_prompt_codex.sh
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_EXECUTING"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
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
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "brainstorm-gate" "[role + decision]"
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh "[decision]"
```
→ Re-spawn brainstorming subagent (return to top of Phase 3)
