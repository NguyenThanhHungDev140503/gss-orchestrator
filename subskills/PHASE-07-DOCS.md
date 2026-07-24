# GSS Orchestrator — Phase 5.6: GStack Documentation

*This file is loaded by SKILL.md when `loop_state` is `GSTACK_DOCS`.*

---

## PHASE 5.6 — GSTACK DOCUMENTATION

**Trigger:** `loop_state` is `GSTACK_DOCS`

### Step 5.6.1 — Dispatch gss-docs

```
Agent(
  subagent_type: "gss-docs",
  prompt: "Mode: RELEASE_DOCS

           Update documentation for the completed milestone after functional QA
           and design QA have passed.

           Read:
           - $GSD_PLAN_FILE
           - $GSD_DECISIONS_FILE
           - $GSD_BRAINSTORM_DOC
           - $GSD_DESIGN_QA_REPORT
           - changed files from git

           Invoke document-release via the Skill tool and follow its full
           workflow. Use document-generate only for missing docs. Use make-pdf
           only when the milestone explicitly requires a PDF.

           Write the compact report to .planning/phases/<phase>/DOCS_REPORT.md.
           Normalize metadata with scripts/obsidian_meta.sh.

           Return RELEASE_DOCS JSON only."
)
```

### Step 5.6.2 — Parse docs result

**If `status: DOCS_DONE`:**
```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh write-bases
bash $(cat .planning/.gss_home)/scripts/update_state.sh "GSD_DISPATCH"
```
→ Proceed to PHASE 6

**If `status: NEEDS_CLARIFICATION`:**
```bash
bash $(cat .planning/.gss_home)/scripts/inject_answer.sh \
  "DOCS NEED CLARIFICATION: [open_questions]. Run systematic debugging before fixing."
bash $(cat .planning/.gss_home)/scripts/update_state.sh "SP_DEBUGGING"
```
→ Proceed to PHASE 5.7
