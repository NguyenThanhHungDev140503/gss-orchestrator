# Brownfield Orchestrator Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an existing-project branch to GSS Orchestrator for both Claude Code and Codex.

**Architecture:** Introduce `PROJECT_INTAKE` and `PROJECT_DISCOVERY` states before research/planning. Existing projects get discovery artifacts first, then GSD produces a delta roadmap instead of a greenfield roadmap.

**Tech Stack:** Markdown skill contracts, Bash helper scripts, shell contract tests.

---

### Task 1: Contract Coverage

**Files:**
- Modify: `tests/codex_contract_test.sh`
- Modify: `tests/obsidian_contract_test.sh`
- Modify: `tests/resolve_gsd_paths_contract_test.sh`

- [x] Add assertions for `PROJECT_INTAKE`, `PROJECT_DISCOVERY`, `project_mode`, discovery artifacts, and `gss-discoverer`.
- [x] Run the focused tests and confirm they fail before implementation.

### Task 2: Brownfield Artifacts

**Files:**
- Create: `agents/gss-discoverer.md`
- Modify: `scripts/resolve_gsd_paths.sh`
- Modify: `scripts/obsidian_meta.sh`
- Modify: `scripts/setup.sh`

- [x] Add discovery artifact path exports.
- [x] Add Obsidian metadata types for current-state, codebase-map, baseline, docs-ingest, and integration-risks.
- [x] Ensure setup copies the new subagent.

### Task 3: Orchestrator Docs

**Files:**
- Modify: `SKILL.md`
- Modify: `SKILL.codex.md`
- Modify: `README.md`
- Modify: `agents/gss-gsd-runner.md`

- [x] Add `PROJECT_INTAKE` and `PROJECT_DISCOVERY` to both skill variants.
- [x] Update Phase 0/1 to use greenfield or brownfield planning.
- [x] Document delta roadmap behavior and discovery artifacts.

### Task 4: Verification

**Files:**
- Modify as needed based on failures.

- [x] Run all contract tests.
- [x] Fix regressions.
- [x] Report installed-skill sync requirement for `~/.agents` / `~/.claude`.
