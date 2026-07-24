# GSS Orchestrator — Phase 2: GStack Review

*This file is loaded by SKILL.md when `loop_state` is `GSTACK_REVIEW`.*

---

## PHASE 2 — GSTACK REVIEW

**Trigger:** `loop_state` is `GSTACK_REVIEW`

### Step 2.1 — Prepare plan content for review

```bash
source $(cat .planning/.gss_home)/scripts/resolve_gsd_paths.sh
cat "$GSD_PLAN_FILE" 2>/dev/null || cat .planning/ROADMAP.md
```

### Step 2.2 — Dispatch gss-reviewer for CEO review

Use **Agent/Task tool** (NOT Skill tool):

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: CEO

           Plan to review (from $GSD_PLAN_FILE):
           [paste plan content]

           Existing decisions (from .planning/DECISIONS.md):
           [paste recent decisions]

           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')
           Current phase: [phase id from STATE.md]
           Today: $(date +%Y-%m-%d)

           Invoke the GStack CEO review skill (plan-ceo-review) via the
           Skill tool, follow its full workflow, then return the JSON
           result with extracted decisions only.

           OBSIDIAN FORMAT REQUIREMENT:
           When writing or appending to DECISIONS.md, use log_decision.sh or
           scripts/obsidian_meta.sh ensure-frontmatter. Do not hand-write YAML.
           Use > [!important] callouts for critical decisions logged in the body."
)
```

Wait for JSON. The subagent has already logged decisions to DECISIONS.md.

### Step 2.3 — Dispatch gss-reviewer for Engineering review

```
Agent(
  subagent_type: "gss-reviewer",
  prompt: "Review type: ENGINEERING

           Plan to review:
           [paste plan content]

           CEO decisions already made:
           [paste CEO decisions JSON from previous step]

           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')
           Current phase: [phase id from STATE.md]
           Today: $(date +%Y-%m-%d)

           Invoke the GStack engineering review skill (plan-eng-review)
           via the Skill tool, follow its full workflow, then return
           the JSON result with extracted decisions only.

           OBSIDIAN FORMAT REQUIREMENT:
           When appending engineering decisions to DECISIONS.md, use
           log_decision.sh or scripts/obsidian_meta.sh ensure-frontmatter so the
           helper preserves frontmatter and updates the 'updated' field. Use
           > [!warning] callouts for technical risks and constraints identified
           in the review. Do not hand-write YAML."
)
```

### Step 2.4 — Advance to DX or design plan review

```bash
bash $(cat .planning/.gss_home)/scripts/log_decision.sh \
  "eng-review" "[extracted engineering decisions]"

DEVEX=$(jq -r '.devex_surface // false' .planning/GSS_STATE.json)
if [ "$DEVEX" = "true" ]; then
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DX_REVIEW"
else
  bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_DESIGN_PLAN"
fi

bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```

**→ Proceed to PHASE 2.3 or PHASE 2.5**
