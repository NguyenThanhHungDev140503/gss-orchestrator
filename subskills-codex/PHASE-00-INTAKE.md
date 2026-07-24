# GSS Orchestrator (Codex) — Phase 0A + 0B: Project Intake & Discovery

*This file is loaded by SKILL.codex.md when `loop_state` is `IDLE` or `PROJECT_DISCOVERY`.*

---

## PHASE 0A — PROJECT INTAKE

**Trigger:** `loop_state` is `IDLE`

Save requirements and classify project mode before research. This branch keeps
greenfield projects fast while making existing projects plan from current
reality.

Save requirements and initialize Obsidian metadata:
```bash
mkdir -p .planning
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh init-project "<project-name>"
cat > .planning/REQUIREMENTS.md << 'EOF'
[paste user's requirements here]
EOF
bash $(cat .planning/.gss_home)/scripts/obsidian_meta.sh normalize-known
```

Classify project mode:
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

Spawn one discovery subagent. Its **initial message must begin with**:
```text
You are gss-discoverer.

Read repository files, existing docs, manifests, tests, and existing .planning
artifacts if present. Run obvious baseline verification commands and capture
pass/fail summaries only. Do not implement code.

Project mode: [project_mode from .planning/GSS_STATE.json]
Requirements: .planning/REQUIREMENTS.md

Write:
- .planning/CURRENT_STATE.md
- .planning/CODEBASE_MAP.md
- .planning/BASELINE.md
- .planning/DOCS_INGEST.md
- .planning/INTEGRATION_RISKS.md

Use scripts/obsidian_meta.sh to normalize metadata; do not hand-write YAML.

When finished, output only:
DISCOVERY_COMPLETE
[3-line summary of current state, baseline, and main integration risk]
```

After `DISCOVERY_COMPLETE`:
```bash
ls -la .planning/CURRENT_STATE.md .planning/CODEBASE_MAP.md .planning/BASELINE.md .planning/DOCS_INGEST.md .planning/INTEGRATION_RISKS.md
bash $(cat .planning/.gss_home)/scripts/update_state.sh "RESEARCH"
```

→ PHASE 0
