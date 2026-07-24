# GSS Orchestrator — Phase 6: Dispatch Next Milestone

*This file is loaded by SKILL.md when `loop_state` is `GSD_DISPATCH`.*

---

## PHASE 6 — DISPATCH NEXT MILESTONE

**Trigger:** `loop_state` is `GSD_DISPATCH`

### Step 6.1 — Dispatch gss-gsd-runner for next milestone

```
Agent(
  subagent_type: "gss-gsd-runner",
  prompt: "Mode: DISPATCH

           Current milestone complete: [milestone name]
           Completed milestones: [list from GSS_STATE.json]

           Invoke gsd-complete-milestone via Skill tool to mark current
           milestone done, then invoke gsd-plan-phase for the next
           unplanned milestone. Return JSON with status NEXT_PHASE or DELIVERED."
)
```

### Step 6.2 — Act on dispatch response

**If `NEXT_PHASE: <id>`:**
```bash
bash $(cat .planning/.gss_home)/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash $(cat .planning/.gss_home)/scripts/update_shared_context.sh
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW" "<next-milestone-id>"
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh --milestone
```
→ Return to PHASE 2 with new milestone

**If `DELIVERED`:**
```bash
bash $(cat .planning/.gss_home)/scripts/mark_milestone_done.sh "<completed-milestone-id>"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "DELIVERED"
bash $(cat .planning/.gss_home)/scripts/print_summary.sh
```
