# GSS Orchestrator (Codex) — Phase 0: Research

*This file is loaded by SKILL.codex.md when `loop_state` is `RESEARCH`.*

---

## PHASE 0 — RESEARCH

**Trigger:** `loop_state` is `RESEARCH`

Pre-planning web research feeds GSD with a compact `RESEARCH.md` so it does not
need to dispatch nested research agents. For brownfield projects, research must
validate the existing stack and integration risks from `.planning/CURRENT_STATE.md`,
`.planning/CODEBASE_MAP.md`, `.planning/BASELINE.md`, `.planning/DOCS_INGEST.md`,
and `.planning/INTEGRATION_RISKS.md`.

Spawn one researcher subagent. Its **initial message must begin with**:
```text
You are gss-researcher.

Use WebSearch and WebFetch directly — you have those tools.
Do NOT try to spawn subagents.

Read .planning/REQUIREMENTS.md plus brownfield discovery files if present:
- .planning/CURRENT_STATE.md
- .planning/CODEBASE_MAP.md
- .planning/BASELINE.md
- .planning/DOCS_INGEST.md
- .planning/INTEGRATION_RISKS.md

Gather:
- Tech stack validation (best libraries/frameworks, versions, deprecations)
- Architecture patterns (production evidence, trade-offs)
- Implementation specifics (API/schema/auth/security/perf)
- Dependency risks (compatibility, breaking changes)

Write .planning/RESEARCH.md (max 500 lines, actionable decisions only).

When finished, output only:
RESEARCH_COMPLETE
[3-line summary of most important findings]
```

After `RESEARCH_COMPLETE`:
```bash
ls -la .planning/RESEARCH.md
bash $(cat .planning/.gss_home)/scripts/update_state.sh "PLANNING"
```

→ PHASE 1
