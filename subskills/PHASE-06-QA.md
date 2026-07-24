# GSS Orchestrator — Phase 5 + 5.5: QA & Design QA

*This file is loaded by SKILL.md when `loop_state` is `GSTACK_QA` or `GSTACK_DESIGN_QA`.*

---

## PHASE 5 — QA VALIDATION

**Trigger:** `loop_state` is `GSTACK_QA`

### Step 5.1 — Dispatch gss-reviewer for GStack QA

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: QA

           Validate the completed milestone against PLAN.md acceptance criteria.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - $GSD_PHASE_DIR/BRAINSTORM_DOC.md
           - .planning/shared_context.md

           Invoke the GStack QA skill via the Skill tool, follow its full
           validation workflow, run or request the relevant tests/checks, then
           return the JSON result with pass/fail verdict and extracted issues only.
           Do not return full test output."
)
```

### Step 5.2 — Parse QA result

**If GStack QA returns `status: PASSED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_QA"
```
→ Proceed to PHASE 5.5

**If GStack QA returns `status: FAILED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "QA FAILED: [paste issues[] from GStack QA JSON]. Run systematic debugging before fixing."
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_DEBUGGING"
```
→ Proceed to PHASE 5.7 (systematic debugging before retry)

---

## PHASE 5.5 — GSTACK DESIGN QA

**Trigger:** `loop_state` is `GSTACK_DESIGN_QA`

### Step 5.5.1 — Dispatch gss-designer for visual/design QA

```
Agent(
  subagent_type: "gss-designer",
  prompt: "Mode: DESIGN_QA

           Run post-implementation visual/design QA for the completed milestone.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - $GSD_BRAINSTORM_DOC
           - $GSD_PROJECT_DESIGN and $GSD_PHASE_DESIGN if present
           - implementation artifacts and relevant screenshots/test evidence

           Invoke design-review via the Skill tool and follow its full workflow.
           Write the compact report to .planning/phases/<phase>/DESIGN_QA.md.
           Normalize metadata with scripts/obsidian_meta.sh.

           Return DESIGN_QA JSON only."
)
```

### Step 5.5.2 — Parse design QA result

**If `status: PASSED` or `SKIPPED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DOCS"
```
→ Proceed to PHASE 5.6

**If `status: FAILED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DESIGN QA FAILED: [paste issues[] from gss-designer JSON]. Run systematic debugging before fixing."
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_DEBUGGING"
```
→ Proceed to PHASE 5.7
