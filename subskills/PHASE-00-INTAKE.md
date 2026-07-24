# GSS Orchestrator — Phase 0A + 0B: Project Intake & Discovery

*This file is loaded by SKILL.md when `loop_state` is `IDLE` or `PROJECT_DISCOVERY`.*

---

## PHASE 0A — PROJECT INTAKE

**Trigger:** `loop_state` is `IDLE`

Save requirements and classify the project before research. This keeps
greenfield projects fast while preventing existing projects from being planned
as if they started from zero.

### Step 0A.1 — Save requirements

Initialize the project slug and write requirements. The slug is derived from the
project name (lowercase, hyphenated) and stored in `.planning/.project_slug` by
the metadata helper. Use the project name from the user request; if it is
unclear, the helper falls back to the working directory name.

```bash
mkdir -p .planning
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh init-project "<project name>"

cat > .planning/REQUIREMENTS.md << 'REQEOF'
[paste user's full requirements / SRS here]
REQEOF
```

Normalize Obsidian frontmatter on the new file — the helper adds the
`requirements` frontmatter automatically:

```bash
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
```

### Step 0A.2 — Classify project mode

Set `PROJECT_MODE` to one of:
- `new_project` — no meaningful source/docs exist yet.
- `existing_project` — source/docs exist but no `.planning/ROADMAP.md`.
- `existing_project_with_planning` — source/docs and prior `.planning/` artifacts exist.

```bash
if [ -f .planning/ROADMAP.md ]; then
  PROJECT_MODE="existing_project_with_planning"
elif find . -maxdepth 2 -type f \( -name package.json -o -name pyproject.toml -o -name go.mod -o -name Cargo.toml -o -name README.md \) \
  -not -path "./.planning/*" | head -1 | grep -q .; then
  PROJECT_MODE="existing_project"
else
  PROJECT_MODE="new_project"
fi

NEXT_STATE="$([ "$PROJECT_MODE" = "new_project" ] && echo RESEARCH || echo PROJECT_DISCOVERY)"
bash $(cat .planning/.gss_home)/scripts/update_state.sh "$NEXT_STATE" "" "" "" "$PROJECT_MODE"
```

**If `PROJECT_MODE=new_project`** → PHASE 0.
**If `PROJECT_MODE=existing_project` or `existing_project_with_planning`** → PHASE 0B.

---

## PHASE 0B — PROJECT DISCOVERY

**Trigger:** `loop_state` is `PROJECT_DISCOVERY`

Existing projects need a factual map before research/planning. Discovery writes
brownfield artifacts so Phase 1 creates a **delta roadmap**, not a greenfield
roadmap.

Use the **Agent/Task tool** to dispatch `gss-discoverer`:

```
Agent(
  subagent_type: "gss-discoverer",
  prompt: "Run existing-project discovery for GSS Orchestrator.

           Project mode: $(jq -r '.project_mode // \"existing_project\"' .planning/GSS_STATE.json)
           Requirements: .planning/REQUIREMENTS.md

           Read repository files, existing docs, manifests, tests, and existing
           .planning artifacts if present. Run obvious baseline verification
           commands and capture pass/fail summaries only.

           Write:
           - .planning/CURRENT_STATE.md
           - .planning/CODEBASE_MAP.md
           - .planning/BASELINE.md
           - .planning/DOCS_INGEST.md
           - .planning/INTEGRATION_RISKS.md

           Normalize metadata with scripts/obsidian_meta.sh.
           Return DISCOVERY_COMPLETE JSON only. Do not implement code."
)
```

After `DISCOVERY_COMPLETE`:
```bash
ls -la .planning/CURRENT_STATE.md .planning/CODEBASE_MAP.md .planning/BASELINE.md .planning/DOCS_INGEST.md .planning/INTEGRATION_RISKS.md
bash $(cat .planning/.gss_home)/scripts/update_state.sh "RESEARCH"
```

→ PHASE 0
