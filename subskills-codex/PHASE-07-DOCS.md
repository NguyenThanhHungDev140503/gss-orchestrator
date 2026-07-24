# GSS Orchestrator (Codex) — Phase 5.6: GStack Documentation

*This file is loaded by SKILL.codex.md when `loop_state` is `GSTACK_DOCS`.*

---

## PHASE 5.6 — GSTACK DOCUMENTATION

**Trigger:** `loop_state` is `GSTACK_DOCS`

Spawn one documentation subagent. Its **initial message must begin with**:
```text
$document-release
Update release documentation for the completed milestone after functional QA and
design QA have passed.

Read:
- PLAN.md
- DECISIONS.md
- BRAINSTORM_DOC.md
- DEVEX_REVIEW.md if present
- DESIGN_QA.md
- changed files from git

Use $document-generate only for missing feature/module/user docs.
Use $make-pdf only when this milestone explicitly requires a PDF.

Write the compact report to .planning/phases/<phase>/DOCS_REPORT.md.
Use scripts/obsidian_meta.sh to normalize metadata; do not hand-write YAML.

Return only:
DOCS_STATUS: DOCS_DONE or NEEDS_CLARIFICATION
DOCS_UPDATED: [list]
DOCS_CREATED: [list]
DOCS_DONE
```

After `DOCS_DONE`:

**If `DOCS_STATUS: DOCS_DONE`:**
```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh write-bases
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSD_DISPATCH"
```
→ PHASE 6

**If `DOCS_STATUS: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DOCS NEED CLARIFICATION: [open questions]. Run systematic debugging before fixing."
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_DEBUGGING"
```
→ PHASE 5.7
