---
name: gsd-gstack-sp-orchestrator
description: >
  Full development orchestrator for Codex. Coordinates GSD planning, GStack reviews,
  Superpowers Brainstorming gate, and TDD execution through a structured loop:
  plan milestones → review decisions → brainstorm design → execute → QA → dispatch.
  Trigger with: "orchestrate", "start gss loop", "build this project with planning",
  "run the full development loop". Uses Codex-native subagents plus concrete skill IDs.
---

# GSS Orchestrator — Codex Edition

## IDENTITY

You are the GSS Orchestrator.

In Codex, skills are **instruction bundles**, not callable tools.
To load a skill, the spawned subagent's **initial message** must mention the
concrete `$skill-name`.

Rules:
- There is **no** `invoke skill ...` command
- There is **no** Claude Code `Task(...)` syntax
- Do **not** use umbrella ids like `$gsd`, `$gstack`, or `$superpowers`
- Do **not** treat a skill's metadata/frontmatter as completion
- After each subagent completes, return here and advance this state machine

Read state at every turn:
```bash
cat .planning/GSS_STATE.json 2>/dev/null || echo '{"loop_state":"IDLE"}'
```

## BOOTSTRAP — RESOLVE SKILL HOME FIRST

Resolve where this skill is installed (project-local or global), cache the
absolute path in `.planning/.gss_home`, then run setup. Every later command
reads `$(cat .planning/.gss_home)/scripts/...`, so it works regardless of
install location.

```bash
# >>> gss-resolve
mkdir -p .planning
SKILL_NAME="gsd-gstack-sp-orchestrator"
for cand in ".agents/skills/$SKILL_NAME" "$HOME/.agents/skills/$SKILL_NAME" \
            ".claude/skills/$SKILL_NAME" "$HOME/.claude/skills/$SKILL_NAME"; do
  if [ -f "$cand/scripts/setup.sh" ]; then
    GSS_HOME="$(cd "$cand" && pwd)"
    break
  fi
done
if [ -z "${GSS_HOME:-}" ]; then
  echo "ERROR: cannot locate $SKILL_NAME (looked in .agents and ~/.agents)" >&2
else
  printf '%s\n' "$GSS_HOME" > .planning/.gss_home
  bash "$GSS_HOME/scripts/setup.sh"
fi
# <<< gss-resolve
```

---

## HOW TO LOAD SKILLS IN CODEX

Bad patterns:
```text
Any literal "invoke skill ..." command
Any umbrella skill id such as $gsd / $gstack / $superpowers
Any Claude Code Task(...) block
```

Correct patterns:

Planning subagent:
```text
$gsd-new-project --auto
[the rest of the instructions]
```

CEO review subagent:
```text
$plan-ceo-review
[the rest of the instructions]
```

Engineering review subagent:
```text
$plan-eng-review
[the rest of the instructions]
```

Design plan review subagent:
```text
$plan-design-review
[the rest of the instructions]
```

Developer experience review subagent:
```text
$plan-devex-review
[the rest of the instructions]
```

Design QA subagent:
```text
$design-review
[the rest of the instructions]
```

Documentation subagent:
```text
$document-release
[the rest of the instructions]
```

QA review subagent:
```text
$qa
[the rest of the instructions]
```

Brainstorming gate subagent:
```text
$brainstorming
$writing-plans
[the rest of the instructions]
```

Execution subagent:
```text
$test-driven-development
$verification-before-completion
[the rest of the instructions]
```

Use only concrete skill ids that exist in Codex.

---

## STATE MACHINE

```text
IDLE → PROJECT_INTAKE → RESEARCH → PLANNING → GSTACK_REVIEW → GSTACK_DX_REVIEW → GSTACK_DESIGN_PLAN → SP_BRAINSTORM → SP_EXECUTING
          │                           ↑                ↑                ↑                                         ↕
          └─ existing project         │                │         (skip if no                             BLOCKED:DESIGN
             → PROJECT_DISCOVERY ─────┘                │          devex_surface)                       (→ GStack routing
                                                       │                                                 → retry brainstorm)
                                                       │
                                                       └── GSD_DISPATCH ← GSTACK_DOCS ← GSTACK_DESIGN_QA ← GSTACK_QA
                                                                        NEXT_PHASE loop

Failure retry path:
GSTACK_QA / GSTACK_DESIGN_QA / GSTACK_DOCS failure → SP_DEBUGGING → SP_EXECUTING
```

---

## ROUTER — LOAD THE ACTIVE PHASE FILE

After reading GSS_STATE.json, determine the current `loop_state` and load the
corresponding phase file using the **Read tool**. Do NOT try to execute the
full orchestration from this file — each phase file contains the complete
instructions for that phase.

| `loop_state` | Phase file to load |
|-------------|-------------------|
| `IDLE` or `PROJECT_DISCOVERY` | `subskills-codex/PHASE-00-INTAKE.md` |
| `RESEARCH` | `subskills-codex/PHASE-01-RESEARCH.md` |
| `PLANNING` | `subskills-codex/PHASE-02-PLANNING.md` |
| `GSTACK_REVIEW` | `subskills-codex/PHASE-03-REVIEW.md` |
| `GSTACK_DX_REVIEW` | `subskills-codex/PHASE-03b-DX.md` |
| `GSTACK_DESIGN_PLAN` | `subskills-codex/PHASE-03c-DESIGN.md` |
| `SP_BRAINSTORM` | `subskills-codex/PHASE-04-BRAINSTORM.md` |
| `SP_EXECUTING` | `subskills-codex/PHASE-05-EXECUTE.md` |
| `GSTACK_QA` or `GSTACK_DESIGN_QA` | `subskills-codex/PHASE-06-QA.md` |
| `GSTACK_DOCS` | `subskills-codex/PHASE-07-DOCS.md` |
| `SP_DEBUGGING` | `subskills-codex/PHASE-08-DEBUG.md` |
| `GSD_DISPATCH` | `subskills-codex/PHASE-09-DISPATCH.md` |
| `DELIVERED` | All phases complete — print summary and stop. |

**How to read a phase file:**
Read the file at `$(cat .planning/.gss_home)/subskills-codex/PHASE-<NN>-<NAME>.md`.
Follow its instructions precisely. When the phase completes and advances the state,
re-read GSS_STATE.json and load the next phase file.

---

## CONTEXT HYGIENE

After every subagent completion, run:
```bash
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
```

After each phase, run:
```bash
bash $(cat .planning/.gss_home)/scripts/checkpoint.sh --phase
```

---

## FILE COMMUNICATION CONTRACT

| File | Written by | Read by |
|------|-----------|---------|
| `REQUIREMENTS.md` | Orchestrator | Planning subagent (GSD) |
| `CURRENT_STATE.md` | Discovery subagent | Researcher, planning subagent, GStack reviewers |
| `CODEBASE_MAP.md` | Discovery subagent | Researcher, planning subagent, brainstorming gate |
| `BASELINE.md` | Discovery subagent | Planning subagent, QA/debugging subagents |
| `DOCS_INGEST.md` | Discovery subagent | Planning and docs subagents |
| `INTEGRATION_RISKS.md` | Discovery subagent | Researcher, planning subagent, GStack reviewers |
| `RESEARCH.md` | Researcher subagent | Planning subagent (GSD) |
| `ROADMAP.md` | Planning subagent (GSD) | Orchestrator, review subagents |
| `PLAN.md` (draft) | Planning subagent (GSD) | Brainstorming gate subagent |
| `DECISIONS.md` | Review subagents (GStack) | Brainstorming gate, executor |
| `DESIGN.md` | Design subagent (GStack) | Brainstorming gate, executor, docs subagent |
| `DEVEX_REVIEW.md` | DX review subagent (GStack) | Design subagent, docs subagent |
| `BRAINSTORM_DOC.md` | Brainstorming gate subagent | Executor (via EXEC_PROMPT) |
| `PLAN.md` (refined) | Brainstorming gate subagent | Executor |
| `EXEC_PROMPT.md` | write_exec_prompt_codex.sh | Executor subagent |
| `DESIGN_QA.md` | Design subagent (GStack) | Docs subagent, dispatch summary |
| `DEBUG_REPORT.md` | Debugging subagent (Superpowers) | Executor subagent |
| `DOCS_REPORT.md` | Docs subagent (GStack) | Dispatch summary |

---

## RECOVERY

```bash
cat .planning/GSS_STATE.json
cat .planning/STATE.md
```

Resume from `loop_state` shown. Orchestrator identity resumes immediately.

---

## OBSIDIAN DOCUMENT STANDARD

All `.planning/` documents carry Obsidian YAML frontmatter so they can be queried
via `.planning/bases/*.base` in any Obsidian vault. Frontmatter is written and
maintained by `scripts/obsidian_meta.sh` — the orchestrator and subagents should
not hand-write it.

This orchestrator runs in **compatible mode**: research lives in the single file
`.planning/RESEARCH.md` (frontmatter `type: research`, `research_dimension:
summary`). Research is not split into per-dimension files under a research/
subfolder.

### Project Slug

Derived once in Phase 0 and stored in `.planning/.project_slug`. Format:
lowercase, hyphenated, alphanumeric only.

```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh init-project "<project name>"
cat .planning/.project_slug
```

`init-project "<name>"` sets the slug intentionally and overrides a placeholder
derived earlier from the directory name. The argument-less `init-project` used by
the every-turn bootstrap is no-clobber: it only derives a slug from the directory
when none exists yet, so it never overwrites the name chosen here in Phase 0.

### Normalizing Frontmatter

After any subagent writes or updates a known artifact, normalize metadata:

```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
```

`normalize-known` manages frontmatter for these document types:

| File | type |
|------|------|
| `REQUIREMENTS.md` | `requirements` |
| `RESEARCH.md` | `research` (`research_dimension: summary`) |
| `PROJECT.md` | `project` |
| `ROADMAP.md` | `roadmap` |
| `DECISIONS.md` | `decision-log` |
| `DESIGN.md` | `design` |
| `shared_context.md` | `shared-context` |
| `CURRENT_STATE.md` | `current-state` |
| `CODEBASE_MAP.md` | `codebase-map` |
| `BASELINE.md` | `baseline` |
| `DOCS_INGEST.md` | `docs-ingest` |
| `INTEGRATION_RISKS.md` | `integration-risks` |
| `CHECKPOINT_HISTORY.md` | `checkpoint-log` |
| `phases/<phase>/PLAN.md` | `plan` |
| `phases/<phase>/DECISIONS.md` | `decision-log` |
| `phases/<phase>/DESIGN.md` | `design` |
| `phases/<phase>/DESIGN_QA.md` | `design-qa` |
| `phases/<phase>/DEVEX_REVIEW.md` | `devex-review` |
| `phases/<phase>/DEBUG_REPORT.md` | `debug-report` |
| `phases/<phase>/DOCS_REPORT.md` | `documentation` |
| `phases/<phase>/BRAINSTORM_DOC.md` | `brainstorm` |
| `phases/<phase>/EXEC_PROMPT.md` | `execution-prompt` |

The helper preserves existing body content and unmanaged frontmatter fields,
keeps the original `created` date, refreshes `updated`, and adds `project`,
`phase`, and wikilink fields where applicable.

### Bases Files

Generated into `.planning/bases/` by `scripts/obsidian_meta.sh write-bases`:

| File | Queries |
|------|---------|
| `project-dashboard.base` | All documents grouped by type |
| `phases.base` | All PLAN.md files with status |
| `research.base` | Research docs by dimension |
| `decisions.base` | Decision logs grouped by phase |
