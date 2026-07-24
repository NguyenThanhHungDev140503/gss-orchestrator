# GSS Orchestrator — Phase 3: Superpowers Brainstorming Gate

*This file is loaded by SKILL.md when `loop_state` is `SP_BRAINSTORM`.*

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
           Write BRAINSTORM_DOC.md and refine PLAN.md as normal Markdown, then
           run scripts/obsidian_meta.sh normalize-known so the helper manages
           brainstorm and plan frontmatter. Do not hand-write YAML.
           Use > [!info] callouts for approach comparisons, > [!important] for the
           chosen approach rationale."
)
```

### Step 3.2 — Parse brainstorm result

**If `DESIGN_CONFIRMED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/write_exec_prompt.sh

bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_EXECUTING"

bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
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
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "brainstorm-gate" "[decision from reviewer]"

bash $(cat .planning/.gss_home)/scripts/inject_answer.sh "[decision]"
```
→ Return to Step 3.1 (re-dispatch gss-brainstormer with updated DECISIONS.md)
