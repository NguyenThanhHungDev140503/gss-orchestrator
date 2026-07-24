# GSS Orchestrator — Phase 2.5: GStack Design Plan Review

*This file is loaded by SKILL.md when `loop_state` is `GSTACK_DESIGN_PLAN`.*

---

## PHASE 2.5 — GSTACK DESIGN PLAN REVIEW

**Trigger:** `loop_state` is `GSTACK_DESIGN_PLAN`

This phase gives the GStack Designer / Design Reviewer role a chance to review
the milestone before Superpowers turns the plan into execution detail.

### Step 2.5.1 — Dispatch gss-designer for design plan review

Use **Agent/Task tool**:

```
Agent(
  subagent_type: "gss-designer",
  prompt: "Mode: DESIGN_PLAN

           Review the current milestone plan for UI/UX, interaction, visual
           hierarchy, accessibility, and product-design risk.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - $GSD_DEVEX_REVIEW if present
           - .planning/RESEARCH.md
           - .planning/shared_context.md
           - .planning/DESIGN.md if present

           Invoke plan-design-review via the Skill tool and follow its full
           workflow. If the project has no design direction, use
           design-consultation. If multiple directions are needed, use
           design-shotgun. If a concrete HTML artifact is needed, use
           design-html.

           Write compact design notes to .planning/phases/<phase>/DESIGN.md
           when needed. Normalize metadata with scripts/obsidian_meta.sh.
           Return DESIGN_PLAN JSON only."
)
```

### Step 2.5.2 — Parse design plan result

**If `status: APPROVED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "design-plan" "[extracted design decisions]"
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_BRAINSTORM"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```
→ Proceed to PHASE 3

**If `status: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DESIGN PLAN NEEDS CLARIFICATION: [open_questions]"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW"
```
→ Return to PHASE 2 with the design question in context
