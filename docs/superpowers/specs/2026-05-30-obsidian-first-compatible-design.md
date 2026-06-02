# Obsidian-First Compatible Planning Design

Date: 2026-05-30
Status: proposed

## Purpose

Make `.planning/` artifacts queryable and navigable in Obsidian without changing
the current GSS runtime contract. The compatible-first version keeps existing
artifact names such as `RESEARCH.md`, `ROADMAP.md`, `PLAN.md`, and `DECISIONS.md`
as the source of truth, then adds deterministic metadata and Bases files around
them.

This design intentionally does not introduce new agents or replace the current
research flow with `research/STACK.md`, `research/FEATURES.md`, or similar
documents. Structured research can be a later migration after the metadata layer
is stable.

## Scope

In scope:

- Add a deterministic Obsidian metadata helper script.
- Generate `.planning/.project_slug`.
- Generate `.planning/bases/*.base` files from one script.
- Ensure known Markdown artifacts have valid YAML frontmatter.
- Preserve existing file paths and agent responsibilities.
- Update `SKILL.md`, `SKILL.codex.md`, agent docs, README, and tests to reflect
  the metadata contract.

Out of scope:

- Adding `gss-research-synthesizer` or `gss-roadmapper`.
- Splitting `.planning/RESEARCH.md` into multiple research dimension files.
- Making Obsidian a runtime dependency.
- Rewriting GSD, GStack, or Superpowers workflows.

## Architecture

Add `scripts/obsidian_meta.sh` as the single writer for Obsidian-specific
metadata. Agents and orchestrator instructions should call this helper instead
of embedding large YAML blocks or hand-maintaining `.base` files.

The helper owns these operations:

- `init-project <project-name>`: create `.planning/`, derive and store
  `.planning/.project_slug`, and initialize project-level metadata values.
- `ensure-frontmatter <path> <type> [phase]`: add frontmatter when missing and
  update the `updated` field when present.
- `write-bases`: create `.planning/bases/project-dashboard.base`,
  `.planning/bases/phases.base`, `.planning/bases/research.base`, and
  `.planning/bases/decisions.base`.
- `normalize-known`: apply frontmatter to known runtime files if they exist.

The script should be POSIX-friendly Bash and use `date`, `sed`, and `awk`.
`jq` may be used only where the repo already requires it. The script should not
require Obsidian to be installed.

## Artifact Schema

Compatible-first schemas:

- `.planning/REQUIREMENTS.md`: `type: requirements`
- `.planning/RESEARCH.md`: `type: research`, `research_dimension: summary`
- `.planning/PROJECT.md`: `type: project`
- `.planning/ROADMAP.md`: `type: roadmap`
- `.planning/DECISIONS.md`: `type: decision-log`
- `.planning/shared_context.md`: `type: shared-context`
- `.planning/CHECKPOINT_HISTORY.md`: `type: checkpoint-log`
- `.planning/phases/<phase>/PLAN.md`: `type: plan`, `phase: <phase>`
- `.planning/phases/<phase>/DECISIONS.md`: `type: decision-log`,
  `phase: <phase>`
- `.planning/phases/<phase>/BRAINSTORM_DOC.md`: `type: brainstorm`,
  `phase: <phase>`
- `.planning/phases/<phase>/EXEC_PROMPT.md`: optional `type: execution-prompt`

All schemas include:

- `project_slug`
- `tags`
- `created`
- `updated` where the artifact can change

Phase artifacts also include:

- `phase`
- `project: "[[../../PROJECT]]"` when a project file exists
- file-local links such as `plan: "[[PLAN]]"` where applicable

## Data Flow

Phase 0:

1. Orchestrator writes requirements.
2. Orchestrator calls `obsidian_meta.sh init-project "<project-name>"`.
3. Orchestrator calls `obsidian_meta.sh normalize-known`.
4. Researcher writes `.planning/RESEARCH.md`.
5. Orchestrator or researcher calls `normalize-known` again.

Phase 1:

1. GSD runner creates or updates `PROJECT.md`, `ROADMAP.md`, and phase `PLAN.md`.
2. GSD runner calls `normalize-known`.
3. Orchestrator calls `write-bases`.

Phase 2 and later:

1. Reviewer, brainstormer, executor, and checkpoint scripts write their normal
   artifacts.
2. Each script or wrapper calls `normalize-known` after writes.
3. `log_decision.sh` ensures decision files have frontmatter before appending.

## Error Handling

The helper should fail closed for invalid arguments but tolerate missing
artifacts during `normalize-known`.

Required behavior:

- If project name is empty, derive slug from `basename "$PWD"`.
- If a file has existing YAML frontmatter, preserve body content and update only
  metadata fields managed by the helper.
- If a file does not exist, `normalize-known` skips it without error.
- If `.planning/.project_slug` is missing, create it from the working directory
  name.
- If frontmatter is malformed, leave the file unchanged and print a warning.

## Tests

Add `tests/obsidian_contract_test.sh`.

It should verify:

- `obsidian_meta.sh init-project "Demo App"` writes slug `demo-app`.
- `write-bases` creates all four `.base` files.
- `normalize-known` adds frontmatter to `REQUIREMENTS.md`, `RESEARCH.md`, and
  phase `PLAN.md`.
- `log_decision.sh` preserves frontmatter and appends a decision body.
- `SKILL.md` does not reference nonexistent agents such as
  `gss-research-synthesizer` or `gss-roadmapper`.

Existing contract tests should continue to pass.

## Documentation Updates

Update `README.md` to describe:

- Obsidian-first compatible mode.
- New `.planning/.project_slug`.
- New `.planning/bases/` directory.
- The fact that `.planning/RESEARCH.md` remains the research source of truth.

Update `SKILL.md` and `SKILL.codex.md` to:

- Call the metadata helper instead of embedding full YAML examples.
- Keep current agent list and file contract.
- Remove references to nonexistent agents.
- State that `.base` files are generated by `scripts/obsidian_meta.sh`.

Update agent docs to:

- Preserve existing responsibilities.
- Call `normalize-known` after producing artifacts.
- Avoid hand-writing Obsidian Bases files.

## Trade-Offs

This approach gives Obsidian queryability without forcing a research model
migration. It does add a small metadata maintenance layer, but that layer is
centralized in one script and covered by contract tests.

The main compromise is that research remains a single `RESEARCH.md` document,
so Obsidian users cannot query individual research dimensions yet. That is
acceptable because the current repo and agents already depend on this file, and
changing it would increase rollout risk.

## Acceptance Criteria

- Running the new Obsidian contract test passes.
- Existing contract tests pass.
- `.planning/bases/*.base` files are generated by a script, not only described
  in documentation.
- Existing GSS runtime file paths continue to work.
- Runtime and orchestrator documentation do not reference agents that are not
  present in `agents/`.
- `git diff --check` reports no whitespace errors.
