# GSS Orchestrator (Codex) — Phase 5 + 5.5: QA & Design QA

*This file is loaded by SKILL.codex.md when `loop_state` is `GSTACK_QA` or `GSTACK_DESIGN_QA`.*

---

## PHASE 5 — QA VALIDATION

**Trigger:** `loop_state` is `GSTACK_QA`

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
grep -A10 -i "acceptance criteria" "$GSD_PLAN_FILE" | head -15
```

Spawn one GStack QA review subagent. Its **initial message must begin with**:
```text
$qa
Validate this completed milestone against PLAN.md acceptance criteria.

Read:
- PLAN.md
- DECISIONS.md
- BRAINSTORM_DOC.md
- shared_context.md

Then:
1. Use the GStack QA role to decide what validation is required
2. Run or request the relevant test commands/checks
3. Check whether all unchecked tasks are done
4. Compare acceptance criteria against observed coverage

Return only:
QA_STATUS: PASSED or FAILED
ISSUES: [list issues if failed, or "none"]
QA_DONE
```

After `QA_DONE`:

**If `QA_STATUS: PASSED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_QA"
```
→ PHASE 5.5

**If `QA_STATUS: FAILED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh "QA FAILED: [issues]. Run systematic debugging before fixing."
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_DEBUGGING"
```
→ PHASE 5.7

---

## PHASE 5.5 — GSTACK DESIGN QA

**Trigger:** `loop_state` is `GSTACK_DESIGN_QA`

Spawn one design QA subagent. Its **initial message must begin with**:
```text
$design-review
Run post-implementation visual/design QA for this completed milestone.

Read:
- PLAN.md
- DECISIONS.md
- BRAINSTORM_DOC.md
- .planning/DESIGN.md and .planning/phases/<phase>/DESIGN.md if present
- implementation artifacts and relevant screenshots/test evidence

Write the compact report to .planning/phases/<phase>/DESIGN_QA.md.
Use scripts/obsidian_meta.sh to normalize metadata; do not hand-write YAML.

Return only:
DESIGN_QA_STATUS: PASSED or FAILED or SKIPPED
ISSUES: [list issues if failed, or "none"]
DESIGN_QA_DONE
```

After `DESIGN_QA_DONE`:

**If `DESIGN_QA_STATUS: PASSED` or `SKIPPED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DOCS"
```
→ PHASE 5.6

**If `DESIGN_QA_STATUS: FAILED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DESIGN QA FAILED: [issues]. Run systematic debugging before fixing."
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_DEBUGGING"
```
→ PHASE 5.7
