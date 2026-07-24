# GSS Orchestrator — Phase 1: Planning

*This file is loaded by SKILL.md when `loop_state` is `PLANNING`.*

---

## PHASE 1 — PLANNING

**Trigger:** `loop_state` is `PLANNING`

GSD owns the planning flow: interview → roadmap → user approval → PLAN.md draft for first milestone.
Pre-planning research has already produced `.planning/RESEARCH.md` in Phase 0 — GSD MUST
consume that file as research context and SKIP its own internal research dispatch. This
avoids the subagent depth-2 limit that would otherwise block GSD's research agents.
For brownfield projects, GSD MUST also consume discovery artifacts and produce a
**delta roadmap** from current state to target state.

### Step 1.1 — Verify Phase 0 outputs

```bash
PROJECT_MODE=$(jq -r '.project_mode // "new_project"' .planning/GSS_STATE.json)
ls -la .planning/REQUIREMENTS.md .planning/RESEARCH.md
if [ "$PROJECT_MODE" != "new_project" ]; then
  ls -la .planning/CURRENT_STATE.md .planning/CODEBASE_MAP.md .planning/BASELINE.md .planning/DOCS_INGEST.md .planning/INTEGRATION_RISKS.md
fi
```

Required files must exist. If research is missing, return to PHASE 0. If brownfield
discovery files are missing, return to PHASE 0B. Do not dispatch GSD without the
right context for the project mode.

### Step 1.2 — Dispatch gss-gsd-runner (mode: PLANNING)

Use the **Agent/Task tool** to dispatch `gss-gsd-runner` (NOT the Skill tool):

```
Agent(
  subagent_type: "gss-gsd-runner",
  prompt: "Mode: PLANNING

           Requirements: .planning/REQUIREMENTS.md
           Research context: .planning/RESEARCH.md  (already produced in Phase 0)
           Project mode: $(jq -r '.project_mode // \"new_project\"' .planning/GSS_STATE.json)
           Brownfield context if project_mode is not new_project:
           - .planning/CURRENT_STATE.md
           - .planning/CODEBASE_MAP.md
           - .planning/BASELINE.md
           - .planning/DOCS_INGEST.md
           - .planning/INTEGRATION_RISKS.md
           Project slug: $(cat .planning/.project_slug 2>/dev/null || echo 'unknown')

           Run the GSD planning workflow using the supplied research.
           SKIP GSD's internal research dispatch — RESEARCH.md is on disk
           and will be passed as research context to GSD's planning skill.
           If project_mode=new_project, create a roadmap for the full new system.
           If project_mode is existing_project or existing_project_with_planning,
           create a delta roadmap from CURRENT_STATE/CODEBASE_MAP/BASELINE to the
           target in REQUIREMENTS.md. Preserve existing architecture unless a
           requirement or GStack decision explicitly changes it.
           Invoke the appropriate GSD skill via the Skill tool, follow it
           to completion — including any AskUserQuestion gates (answer from
           requirements when possible) — and return PLANNING_COMPLETE JSON
           when .planning/ROADMAP.md and the first milestone PLAN.md exist
           on disk.

           OBSIDIAN FORMAT REQUIREMENT:
           Research stays in the single file .planning/RESEARCH.md — do NOT split
           it into per-dimension research files under a research/ subfolder.
           Write PROJECT.md, ROADMAP.md, and the phase PLAN.md as normal Markdown.
           After GSD finishes, the orchestrator normalizes Obsidian frontmatter
           by running scripts/obsidian_meta.sh normalize-known, so you do not need
           to hand-write YAML frontmatter. Use wikilinks [[FileName]] for
           cross-references and > [!important] / > [!warning] callouts where useful."
)
```

Wait for JSON. Parse `current_phase` and `plan_path`.
If `status` is `FAILED`, surface the reason to the user and stop.

### Step 1.3 — Verify GSD output

```bash
ls .planning/
cat .planning/STATE.md
cat .planning/ROADMAP.md | head -30
```

If `.planning/` was not created → re-invoke, do not proceed.

### Step 1.4 — Update state

```bash
DEVEX_SURFACE=$(echo '<planning_json_result>' | jq -r '.devex_surface // false')
DEVEX_RATIONALE=$(echo '<planning_json_result>' | jq -r '.devex_rationale // ""')
PROJECT_MODE=$(echo '<planning_json_result>' | jq -r '.project_mode // "new_project"')
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW" "<phase-from-STATE.md>" "$DEVEX_SURFACE" "$DEVEX_RATIONALE" "$PROJECT_MODE"
```

### Step 1.5 — Generate Obsidian Bases query files

Regenerate the Obsidian Bases files so the vault can query the project. The
metadata helper writes `project-dashboard.base`, `phases.base`, `research.base`,
and `decisions.base` into `.planning/bases/` using the stored project slug:

```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh write-bases
```

**→ Proceed to PHASE 2**
