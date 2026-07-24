# GSS Orchestrator — Phase 2.3: GStack DX Review

*This file is loaded by SKILL.md when `loop_state` is `GSTACK_DX_REVIEW`.*

---

## PHASE 2.3 — GSTACK_DX_REVIEW

**Trigger:** `loop_state` is `GSTACK_DX_REVIEW`

### Step 2.3.1 — Conditional skip check

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" != "true" ]; then
  echo "No developer-facing surface detected — skipping DX review"
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
  bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
fi
```

If `DEVEX` is not `true`, do not dispatch `gss-devex-reviewer`; re-enter the
loop at PHASE 2.5 (`GSTACK_DESIGN_PLAN`) immediately.

### Step 2.3.2 — Dispatch gss-devex-reviewer

Use **Agent/Task tool**:

```bash
DEVEX_RATIONALE=$(jq -r '.devex_rationale // ""' .planning/GSS_STATE.json)
```

```
Agent(
  subagent_type: "gss-devex-reviewer",
  prompt: "Mode: DEVEX_REVIEW

           Review the current milestone plan for developer experience gaps.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - .planning/REQUIREMENTS.md
           - .planning/RESEARCH.md
           - .planning/shared_context.md

           devex_rationale: $DEVEX_RATIONALE

           Invoke plan-devex-review via the Skill tool and follow its full
           workflow. Write compact DX findings to $GSD_DEVEX_REVIEW.
           Normalize metadata with scripts/obsidian_meta.sh.
           Return DEVEX_REVIEW JSON only."
)
```

Wait for JSON.

### Step 2.3.3 — Parse result

**If `status: APPROVED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "dx-review" "[extracted DX decisions]"
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```
→ Proceed to PHASE 2.5

**If `status: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DX REVIEW NEEDS CLARIFICATION: [open_questions]"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW"
```
→ Return to PHASE 2 with DX question in context
