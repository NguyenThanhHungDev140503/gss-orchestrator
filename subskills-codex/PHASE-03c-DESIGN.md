# GSS Orchestrator (Codex) — Phase 2.5: GStack Design Plan Review

*This file is loaded by SKILL.codex.md when `loop_state` is `GSTACK_DESIGN_PLAN`.*

---

## PHASE 2.5 — GSTACK DESIGN PLAN REVIEW

**Trigger:** `loop_state` is `GSTACK_DESIGN_PLAN`

Spawn one design subagent. Its **initial message must begin with**:
```text
$plan-design-review
Review this milestone plan for UI/UX, interaction design, visual hierarchy,
accessibility, product-design risk, and fit with existing design direction.

Plan to review:
[paste plan content]

Existing decisions:
[paste logged CEO/engineering decisions]

Developer experience review:
[paste DEVEX_REVIEW.md if present]

Use $design-consultation if no design direction exists.
Use $design-shotgun if multiple visual directions are needed.
Use $design-html if a concrete HTML design artifact is required.

Write compact design notes to .planning/phases/<phase>/DESIGN.md when needed.
Use scripts/obsidian_meta.sh to normalize metadata; do not hand-write YAML.

Return only:
DESIGN_DECISIONS_START
1. ...
2. ...
DESIGN_DECISIONS_END
DESIGN_PLAN_STATUS: APPROVED or NEEDS_CLARIFICATION
DESIGN_PLAN_DONE
```

After `DESIGN_PLAN_DONE`:

**If `DESIGN_PLAN_STATUS: APPROVED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "design-plan" "[extracted numbered design decisions]"
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_BRAINSTORM"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```
→ PHASE 3

**If `DESIGN_PLAN_STATUS: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DESIGN PLAN NEEDS CLARIFICATION: [open questions]"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW"
```
→ Return to PHASE 2 with design clarification in context
