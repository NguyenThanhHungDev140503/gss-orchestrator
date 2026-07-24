# GSS Orchestrator (Codex) — Phase 2: GStack Review

*This file is loaded by SKILL.codex.md when `loop_state` is `GSTACK_REVIEW`.*

---

## PHASE 2 — GSTACK REVIEW

**Trigger:** `loop_state` is `GSTACK_REVIEW`

Read milestone plan:
```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
cat "$GSD_PLAN_FILE" 2>/dev/null || cat .planning/ROADMAP.md
```

### CEO Review

Spawn one review subagent. Its **initial message must begin with**:
```text
$plan-ceo-review
Review this milestone plan. Focus on user value, scope, acceptance criteria, risk.

Plan to review:
[paste plan content]

Return only:
DECISIONS_START
1. ...
2. ...
DECISIONS_END
CEO_DONE
```

After `CEO_DONE`, log decisions:
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "ceo-review" "[extracted numbered decisions]"
```

### Engineering Review

Spawn one review subagent. Its **initial message must begin with**:
```text
$plan-eng-review
Review this milestone plan for architecture, dependencies, constraints, testability.

Plan to review:
[paste plan content]

CEO decisions already made:
[paste logged CEO decisions]

Return only:
DECISIONS_START
1. ...
2. ...
DECISIONS_END
ENG_DONE
```

After `ENG_DONE`:
```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "eng-review" "[extracted numbered decisions]"

DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" = "true" ]; then
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DX_REVIEW"
else
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
fi

bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```
