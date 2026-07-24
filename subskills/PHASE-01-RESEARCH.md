# GSS Orchestrator — Phase 0: Research

*This file is loaded by SKILL.md when `loop_state` is `RESEARCH`.*

---

## PHASE 0 — RESEARCH

**Trigger:** `loop_state` is `RESEARCH`

Pre-planning web research feeds GSD with a compact `RESEARCH.md` so it does not
need to dispatch nested research agents (which hit subagent depth limits). For
brownfield projects, research must validate the existing stack and integration
risks from `.planning/CURRENT_STATE.md`, `.planning/CODEBASE_MAP.md`,
`.planning/BASELINE.md`, `.planning/DOCS_INGEST.md`, and
`.planning/INTEGRATION_RISKS.md`.

### Step 0.1 — Dispatch gss-researcher

Use the **Agent/Task tool** to dispatch `gss-researcher` (NOT the Skill tool):

```
Agent(
  subagent_type: "gss-researcher",
  prompt: "Run pre-planning research for this project.

           Requirements (from .planning/REQUIREMENTS.md):
           [paste requirements]

           Existing-project context, if present:
           - .planning/CURRENT_STATE.md
           - .planning/CODEBASE_MAP.md
           - .planning/BASELINE.md
           - .planning/DOCS_INGEST.md
           - .planning/INTEGRATION_RISKS.md

           Use WebSearch and WebFetch directly (you have those tools — do
           NOT try to spawn subagents). Cover tech stack validation,
           architecture patterns, implementation specifics, and dependency
           risks relevant to these requirements. Write a compact
           .planning/RESEARCH.md (max 500 lines) and output RESEARCH_COMPLETE
           plus a 3-line summary. Do not start planning."
)
```

Wait for `RESEARCH_COMPLETE`.

### Step 0.2 — Verify research output

```bash
ls -la .planning/RESEARCH.md
head -20 .planning/RESEARCH.md
```

If `.planning/RESEARCH.md` is missing or empty → re-dispatch, do not proceed.

### Step 0.3 — Update state

```bash
bash $(cat .planning/.gss_home)/scripts/update_state.sh "PLANNING"
```

**→ Proceed to PHASE 1**
