# GSS Orchestrator (Codex) — Phase 1: Planning

*This file is loaded by SKILL.codex.md when `loop_state` is `PLANNING`.*

---

## PHASE 1 — PLANNING

**Trigger:** `loop_state` is `PLANNING`

GSD handles interview, roadmap, and PLAN.md draft.
Pre-planning research has already produced `.planning/RESEARCH.md` in Phase 0 —
GSD MUST consume that file as research context and SKIP its own internal research
dispatch.
For brownfield projects, GSD MUST also consume discovery artifacts and produce a
**delta roadmap** from current state to target state.

Verify Phase 0 outputs exist:
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

Spawn one planning subagent. Its **initial message must begin with**:
```text
$gsd-new-project --auto
Initialize planning artifacts for this project.

Requirements: .planning/REQUIREMENTS.md
Research context: .planning/RESEARCH.md  (already produced in Phase 0)
Project mode: [paste .planning/GSS_STATE.json project_mode]
Brownfield context if project_mode is not new_project:
- .planning/CURRENT_STATE.md
- .planning/CODEBASE_MAP.md
- .planning/BASELINE.md
- .planning/DOCS_INGEST.md
- .planning/INTEGRATION_RISKS.md

Run the GSD workflow using the supplied research.
SKIP GSD's internal research dispatch — RESEARCH.md is on disk and is the
authoritative research context for this milestone.
If project_mode=new_project, create a roadmap for the full new system.
If project_mode is existing_project or existing_project_with_planning, create a
delta roadmap from CURRENT_STATE/CODEBASE_MAP/BASELINE to the target in
REQUIREMENTS.md. Preserve existing architecture unless a requirement or GStack
decision explicitly changes it.
Answer any AskUserQuestion gates using the requirements when possible.
When finished, output only:
PLANNING_DONE: [current milestone name]
DEVEX_SURFACE: true or false
DEVEX_RATIONALE: [one sentence]
```

After subagent outputs `PLANNING_DONE`:
```bash
cat .planning/STATE.md
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh write-bases
DEVEX_SURFACE="<true-or-false-from-planning-output>"
DEVEX_RATIONALE="<one-sentence-rationale-from-planning-output>"
PROJECT_MODE="<new_project-or-existing_project-or-existing_project_with_planning>"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSTACK_REVIEW" "<milestone>" "$DEVEX_SURFACE" "$DEVEX_RATIONALE" "$PROJECT_MODE"
```

Research stays in the single file `.planning/RESEARCH.md` (compatible mode); it
is not split into per-dimension files. Frontmatter and `.planning/bases/*.base`
are managed by `scripts/obsidian_meta.sh`.
