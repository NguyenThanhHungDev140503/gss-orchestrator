# GSS Orchestrator (Codex) — Phase 6: Dispatch Next Milestone

*This file is loaded by SKILL.codex.md when `loop_state` is `GSD_DISPATCH`.*

---

## PHASE 6 — DISPATCH NEXT MILESTONE

**Trigger:** `loop_state` is `GSD_DISPATCH`

Spawn one dispatch subagent. Its **initial message must begin with**:
```text
$gsd-complete-milestone
$gsd-progress --next --force

Complete the current milestone and advance to the next.

Completed milestone: [milestone name]
Completed milestones so far: [list from GSS_STATE.json]

Roadmap:
[paste ROADMAP.md]

After GSD completion/progress finishes, run the deterministic sync script for
completed milestone before returning NEXT_PHASE or DELIVERED:
```bash
bash $(cat .planning/.gss_home)/scripts/mark_milestone_done.sh "[milestone name]"
```

Return only one of:
NEXT_PHASE: [milestone-id]
DELIVERED
```

**If `NEXT_PHASE: <id>`:**
```bash
bash $(cat .planning/.gss_home)/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash $(cat .planning/.gss_home)/scripts/update_shared_context.sh
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW" "<id>"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh --milestone
```
→ Return to PHASE 2

**If `DELIVERED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "DELIVERED"
bash $(cat .planning/.gss_home)/scripts/print_summary.sh
```
