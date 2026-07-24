# GSS Orchestrator (Codex) — Phase 2.3: GStack DX Review

*This file is loaded by SKILL.codex.md when `loop_state` is `GSTACK_DX_REVIEW`.*

---

## PHASE 2.3 — GSTACK_DX_REVIEW

**Trigger:** `loop_state` is `GSTACK_DX_REVIEW`

Skip path:
```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" != "true" ]; then
  echo "No developer-facing surface detected — skipping DX review"
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
  bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
fi
```

If `DEVEX` is not `true`, do not spawn the DX review subagent; re-enter the loop
at PHASE 2.5 (`GSTACK_DESIGN_PLAN`) immediately.

If `DEVEX=true`, read the persisted rationale:
```bash
DEVEX_RATIONALE=$(jq -r '.devex_rationale // ""' .planning/GSS_STATE.json)
```

Then spawn one DX review subagent. Its **initial message must begin with**:
```text
$plan-devex-review
Review this milestone plan for developer experience gaps: getting-started
friction, API/CLI ergonomics, error messages, integration docs, and TTHW.

Read:
- PLAN.md
- DECISIONS.md
- REQUIREMENTS.md
- RESEARCH.md
- shared_context.md

devex_rationale: [paste DEVEX_RATIONALE from .planning/GSS_STATE.json]

Write compact DX findings to .planning/phases/<phase>/DEVEX_REVIEW.md.
Use scripts/obsidian_meta.sh to normalize metadata; do not hand-write YAML.

Return only:
DX_DECISIONS_START
1. ...
2. ...
DX_DECISIONS_END
DX_GAPS: [list]
TTHW_ESTIMATE: [estimate or unknown]
DX_STATUS: APPROVED or NEEDS_CLARIFICATION
DX_DONE
```

After `DX_DONE`:

**If `DX_STATUS: APPROVED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "dx-review" "[extracted numbered DX decisions]"
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```
→ PHASE 2.5

**If `DX_STATUS: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DX REVIEW NEEDS CLARIFICATION: [open questions]"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW"
```
→ Return to PHASE 2 with DX clarification in context
