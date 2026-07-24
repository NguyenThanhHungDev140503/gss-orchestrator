---
name: gsd-gstack-sp-orchestrator
description: >
  Full development orchestrator. Coordinates GSD, GStack, and Superpowers plugins
  through a structured loop: plan milestones → review decisions → brainstorm design →
  execute with TDD → QA validate → dispatch next milestone.
  Trigger with: "orchestrate", "start ralph loop", "run gss loop", "build this project",
  "start development loop", or any request to build a feature end-to-end with planning.
  Manages the full lifecycle automatically — do not invoke GSD, GStack, or Superpowers
  manually when this orchestrator is active.
allowed-tools: Bash, Read, Write, Edit, Task
---

# GSS Orchestrator

## IDENTITY — READ FIRST, NEVER FORGET

You are the **GSS Orchestrator**. This identity persists for the entire session.

When you invoke GSD, GStack, or Superpowers:
- You are **calling a tool**, not becoming that tool
- After the tool completes, you **immediately return to this orchestrator flow**
- You do NOT follow the invoked skill's own workflow — you extract its output and advance YOUR state machine

If you find yourself following GSD's flow, stop. Return here.
If you find yourself following GStack's flow, stop. Return here.
If you find yourself in Superpowers' flow without a Task boundary, stop. Return here.

---

## BOOTSTRAP CHECK — RUN FIRST

Before state machine logic, resolve where this skill is installed (project-local
or global), cache the absolute path in `.planning/.gss_home`, then run setup.
Every later command reads `$(cat .planning/.gss_home)/scripts/...`, so it works
no matter where the skill was installed.

```bash
# >>> gss-resolve
mkdir -p .planning
SKILL_NAME="gsd-gstack-sp-orchestrator"
for cand in ".claude/skills/$SKILL_NAME" "$HOME/.claude/skills/$SKILL_NAME"; do
  if [ -f "$cand/scripts/setup.sh" ]; then
    GSS_HOME="$(cd "$cand" && pwd)"
    break
  fi
done
if [ -z "${GSS_HOME:-}" ]; then
  echo "ERROR: cannot locate $SKILL_NAME (looked in .claude and ~/.claude)" >&2
else
  printf '%s\n' "$GSS_HOME" > .planning/.gss_home
  bash "$GSS_HOME/scripts/setup.sh"
fi
# <<< gss-resolve
```

If setup fails, STOP and ask user to fix setup errors before continuing.

## STATE MACHINE

Read state at every turn:
```bash
cat .planning/GSS_STATE.json 2>/dev/null || echo '{"loop_state":"IDLE"}'
```

```
IDLE → PROJECT_INTAKE → RESEARCH → PLANNING → GSTACK_REVIEW → GSTACK_DX_REVIEW → GSTACK_DESIGN_PLAN → SP_BRAINSTORM → SP_EXECUTING
          │                           ↑                ↑                ↑                                         ↕
          └─ existing project         │                │         (skip if no                             BLOCKED:DESIGN
             → PROJECT_DISCOVERY ─────┘                │          devex_surface)                       (→ gss-reviewer
                                                       │                                                 → back to BRAINSTORM)
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
| `IDLE` or `PROJECT_DISCOVERY` | `subskills/PHASE-00-INTAKE.md` |
| `RESEARCH` | `subskills/PHASE-01-RESEARCH.md` |
| `PLANNING` | `subskills/PHASE-02-PLANNING.md` |
| `GSTACK_REVIEW` | `subskills/PHASE-03-REVIEW.md` |
| `GSTACK_DX_REVIEW` | `subskills/PHASE-03b-DX.md` |
| `GSTACK_DESIGN_PLAN` | `subskills/PHASE-03c-DESIGN.md` |
| `SP_BRAINSTORM` | `subskills/PHASE-04-BRAINSTORM.md` |
| `SP_EXECUTING` | `subskills/PHASE-05-EXECUTE.md` |
| `GSTACK_QA` or `GSTACK_DESIGN_QA` | `subskills/PHASE-06-QA.md` |
| `GSTACK_DOCS` | `subskills/PHASE-07-DOCS.md` |
| `SP_DEBUGGING` | `subskills/PHASE-08-DEBUG.md` |
| `GSD_DISPATCH` | `subskills/PHASE-09-DISPATCH.md` |
| `DELIVERED` | All phases complete — print summary and stop. |

**How to read a phase file:**
```bash
# Resolve the install path first (it has already been cached in .planning/.gss_home)
GSS_HOME=$(cat .planning/.gss_home)
# Read the phase file for your current state
```

Read the file at `<GSS_HOME>/subskills/PHASE-<NN>-<NAME>.md`. Follow its
instructions precisely. When the phase completes and advances the state,
re-read GSS_STATE.json and load the next phase file.

---

## ORCHESTRATOR RULES — ENFORCED AT ALL TIMES

1. **You are always the orchestrator.** Invoking a skill is a tool call, not a context switch.

2. **Subagent dispatch, not inline Skill invocation.** Never call the `Skill`
   tool directly on GSD/GStack/Superpowers from the orchestrator context.
   Always dispatch through a wrapper subagent (`gss-gsd-runner`, `gss-reviewer`,
   `gss-designer`, `gss-brainstormer`, `gss-executor`, `gss-docs`,
   `gss-debugger`) using
   Agent/Task tool.
   The subagent handles Skill invocation inside its own isolated context and
   returns compact JSON.

3. **You parse JSON, not prose.** Wrapper subagents return structured JSON
   with predictable fields (`status`, `decisions[]`, `current_phase`, etc.).
   Read those fields directly. Do not parse free-form skill output.

4. **Brainstorming gate is mandatory.** Never skip SP_BRAINSTORM and go
   directly to SP_EXECUTING. The design gate ensures PLAN.md is implementation-
   ready before any code is written.

5. **Superpowers TDD runs inside gss-executor ONLY.** Never invoke
   `superpowers:test-driven-development` inline.

6. **Scripts are deterministic, Claude is not.** Use scripts for state updates,
   file writes, and path resolution.

7. **Context hygiene after every subagent dispatch:**
   ```bash
   bash $(cat .planning/.gss_home)/scripts/checkpoint.sh
   ```

---

## FILE COMMUNICATION CONTRACT

GSD and Superpowers communicate through these files:

| File | Written by | Read by | Obsidian type |
|------|-----------|---------|---------------|
| `REQUIREMENTS.md` | Orchestrator | gss-gsd-runner (GSD) | `requirements` |
| `CURRENT_STATE.md` | gss-discoverer | gss-researcher, gss-gsd-runner, GStack reviewers | `current-state` |
| `CODEBASE_MAP.md` | gss-discoverer | gss-researcher, gss-gsd-runner, gss-brainstormer | `codebase-map` |
| `BASELINE.md` | gss-discoverer | gss-gsd-runner, gss-reviewer, gss-debugger | `baseline` |
| `DOCS_INGEST.md` | gss-discoverer | gss-gsd-runner, gss-docs | `docs-ingest` |
| `INTEGRATION_RISKS.md` | gss-discoverer | gss-researcher, gss-gsd-runner, GStack reviewers | `integration-risks` |
| `RESEARCH.md` | gss-researcher | gss-gsd-runner (GSD) | `research` |
| `PROJECT.md` | gss-gsd-runner (GSD) | All agents | `project` |
| `ROADMAP.md` | gss-gsd-runner (GSD) | Orchestrator, gss-reviewer | `roadmap` |
| `PLAN.md` (draft) | gss-gsd-runner (GSD) | gss-brainstormer | `plan` |
| `DECISIONS.md` | gss-reviewer (GStack) | gss-designer, gss-brainstormer, gss-executor | `decision-log` |
| `DESIGN.md` | gss-designer (GStack) | gss-brainstormer, gss-executor, gss-docs | `design` |
| `BRAINSTORM_DOC.md` | gss-brainstormer | gss-executor (via EXEC_PROMPT) | `brainstorm` |
| `PLAN.md` (refined) | gss-brainstormer | gss-executor | `plan` |
| `EXEC_PROMPT.md` | write_exec_prompt.sh | gss-executor | — |
| `DESIGN_QA.md` | gss-designer (GStack) | gss-debugger, gss-docs, GSD dispatch | `design-qa` |
| `phases/<phase>/DEVEX_REVIEW.md` | gss-devex-reviewer (GStack) | gss-designer, gss-docs | `devex-review` |
| `DEBUG_REPORT.md` | gss-debugger (Superpowers) | gss-executor | `debug-report` |
| `DOCS_REPORT.md` | gss-docs (GStack) | GSD dispatch, release summary | `documentation` |
| `bases/*.base` | scripts/obsidian_meta.sh (Step 1.5) | Obsidian vault | — |

---

## RECOVERY

```bash
cat .planning/GSS_STATE.json    # current loop_state
cat .planning/STATE.md          # current milestone
cat .planning/DECISIONS.md | tail -30  # recent decisions
```

Resume from the state shown. Orchestrator identity resumes immediately.

---

## OBSIDIAN DOCUMENT STANDARD

All `.planning/` documents carry Obsidian YAML frontmatter so they can be queried
via `.planning/bases/*.base` in any Obsidian vault. Frontmatter is written and
maintained by `scripts/obsidian_meta.sh` — agents and the orchestrator should
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

### Normalizing Frontmatter

After any agent writes or updates a known artifact, normalize metadata:

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

The helper preserves existing body content, refreshes the `updated` field, and
adds `project`, `phase`, and wikilink fields where applicable.

### Wikilink Conventions

- Sibling files: `[[FILENAME]]` (no extension, no path)
- Parent directory: `[[../PROJECT]]`, `[[../../ROADMAP]]`
- Phase plans from ROADMAP: `[[phases/phase-1/PLAN]]`

### Callout Conventions

| Callout | Use for |
|---------|---------|
| `> [!important]` | Key decisions made, chosen approach rationale |
| `> [!warning]` | Pitfalls, technical risks, blockers |
| `> [!info]` | Background context, approach comparisons |
| `> [!success]` | Completed milestones, verified deliverables |

### Obsidian Bases Files

Generated into `.planning/bases/` by `scripts/obsidian_meta.sh write-bases`:

| File | Queries |
|------|---------|
| `project-dashboard.base` | All documents grouped by type |
| `phases.base` | All PLAN.md files with status |
| `research.base` | Research docs by dimension |
| `decisions.base` | Decision logs grouped by phase |
