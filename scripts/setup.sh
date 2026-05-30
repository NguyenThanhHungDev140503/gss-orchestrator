#!/usr/bin/env bash
# scripts/setup.sh
# Kiểm tra prerequisites và khởi tạo .planning/ structure cho GSS Orchestrator.
# Chạy một lần trước khi bắt đầu loop.
#
# Usage:
#   bash .claude/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh
#   bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/setup.sh  (Codex)

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OBSIDIAN_META="$SKILL_DIR/scripts/obsidian_meta.sh"

sync_agents() {
  local src="$SKILL_DIR/agents"
  local dest=".claude/agents"
  [ ! -d "$src" ] && return
  mkdir -p "$dest"
  for f in "$src"/gss-*.md; do
    [ -f "$f" ] || continue
    cp -f "$f" "$dest/"
    echo -e "  ${GREEN}✓${NC} $(basename "$f")"
  done
}

echo "=== GSS Orchestrator Setup ==="
echo ""

# ── 1. Kiểm tra jq ────────────────────────────────────────────────────────
echo "Checking dependencies..."
if command -v jq &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} jq $(jq --version)"
else
  echo -e "  ${YELLOW}⚠${NC} jq not found — installing..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq -q && echo -e "  ${GREEN}✓${NC} jq installed"
  elif command -v brew &>/dev/null; then
    brew install jq && echo -e "  ${GREEN}✓${NC} jq installed"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq -q && echo -e "  ${GREEN}✓${NC} jq installed"
  else
    echo -e "  ${RED}✗${NC} Install jq manually: https://jqlang.github.io/jq/"
    exit 1
  fi
fi

# ── 2. Kiểm tra git repo ─────────────────────────────────────────────────
echo ""
echo "Checking git repository..."
if git rev-parse --git-dir &>/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} git repo detected"
else
  echo -e "  ${YELLOW}⚠${NC} Not a git repository"
  echo ""
  echo "  Claude Code subagents require a git repo to avoid worktree errors."
  echo "  Fix with:"
  echo "    git init && git add -A && git commit -m 'init'"
  echo ""
  read -rp "  Initialize git repo now? [Y/n]: " GIT_INIT
  if [[ "${GIT_INIT:-Y}" =~ ^[Yy]$ ]]; then
    git init
    git add -A
    git commit -m "chore: init repo for GSS Orchestrator" --allow-empty
    echo -e "  ${GREEN}✓${NC} git repo initialized"
  else
    echo -e "  ${YELLOW}⚠${NC} Continuing without git — subagents may fail"
    echo "     Workaround: add to .claude/settings.json:"
    echo '     { "env": { "CLAUDE_CODE_FORK_SUBAGENT": "0" } }'
  fi
fi

# ── 3. Kiểm tra plugins/skills đã cài ────────────────────────────────────
echo ""
echo "Checking required plugins..."

MISSING=()

# Tìm plugin trong cả Claude Code và Codex paths
find_plugin() {
  local name="$1"
  local found
  # Claude Code: ~/.claude/plugins/ và ~/.claude/skills/
  found=$(find ~/.claude/plugins ~/.claude/skills -maxdepth 3 \
    -iname "${name}*" -type d 2>/dev/null | head -1)
  [ -n "$found" ] && echo "$found" && return
  # Codex: ~/.agents/skills/ và ~/.codex/skills/
  found=$(find ~/.agents/skills ~/.codex/skills -maxdepth 3 \
    -iname "${name}*" -type d 2>/dev/null | head -1)
  [ -n "$found" ] && echo "$found" && return
  # Tìm qua SKILL.md
  found=$(find ~/.claude ~/.agents ~/.codex -maxdepth 5 \
    -name "SKILL.md" 2>/dev/null \
    | xargs grep -li "^name: ${name}" 2>/dev/null | head -1)
  [ -n "$found" ] && dirname "$found" && return
  echo ""
}

check_plugin() {
  local label="$1" name="$2" hint="$3"
  local path
  path=$(find_plugin "$name")
  if [ -n "$path" ]; then
    echo -e "  ${GREEN}✓${NC} $label"
  else
    echo -e "  ${RED}✗${NC} $label — not found"
    [ -n "$hint" ] && echo "     Hint: $hint"
    MISSING+=("$label")
  fi
}

check_plugin "GSD"         "gsd"         "/plugin marketplace add jnuyens/gsd-plugin && /plugin install gsd@gsd-plugin"
check_plugin "GStack"      "gstack"      "/plugin marketplace add garrytan/gstack && /plugin install gstack@gstack"
check_plugin "Superpowers" "superpowers" "/plugin install superpowers@claude-plugins-official"

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${RED}Missing: ${MISSING[*]}${NC}"
  echo "  Install missing plugins in a Claude Code / Codex session, then re-run setup."
  exit 1
fi

# ── 3. Cấu hình Worktree hooks cho Claude Code ─────────────────────────────
echo ""
echo "Configuring .claude/settings.json hooks..."

mkdir -p .claude
SETTINGS_FILE=".claude/settings.json"
TMP_FILE="$(mktemp)"

if [ ! -f "$SETTINGS_FILE" ]; then
  cat > "$SETTINGS_FILE" << 'EOF'
{}
EOF
fi

jq '
  .hooks.WorktreeCreate = [
    {
      hooks: [
        {
          type: "command",
          command: "ts=$(date +%s); rnd=${RANDOM:-0}; p=.claude/worktrees/wt-${ts}-${rnd}; b=cc-wt-${ts}-${rnd}; mkdir -p .claude/worktrees && git worktree add -b \"$b\" \"$p\" >/dev/null && printf \"%s\" \"$p\""
        }
      ]
    }
  ]
  | .hooks.WorktreeRemove = [
    {
      hooks: [
        {
          type: "command",
          command: "payload=$(cat); p=$(printf \"%s\" \"$payload\" | jq -r '\''.. | objects | (.worktree_path? // .path? // .worktreePath? // .worktreeDir? // .target_path? // .targetPath?) // empty'\'' | head -n1); [ -n \"$p\" ] || p=$(git worktree list --porcelain | awk '\''/^worktree /{print $2}'\'' | grep '\''.claude/worktrees/'\'' | tail -n1); [ -n \"$p\" ] && git worktree remove \"$p\""
        }
      ]
    }
  ]
' "$SETTINGS_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$SETTINGS_FILE"
echo -e "  ${GREEN}✓${NC} .claude/settings.json hooks configured"

# ── 4. Tạo .planning/ structure ───────────────────────────────────────────
echo ""
echo "Setting up .planning/ ..."

# GSD tạo phases/ — không tạo milestones/ nữa
mkdir -p .planning/phases .planning/archive

# config.json — không còn ralph-loop
if [ ! -f ".planning/config.json" ]; then
  cat > .planning/config.json << 'EOF'
{
  "orchestrator": "gsd-gstack-sp-orchestrator",
  "strategy": "spec-first",
  "execute_engine": "superpowers-tdd",
  "superpowers": {
    "tdd_mode": true,
    "completion_signal": "PHASE_COMPLETE",
    "blocked_signal": "PHASE_BLOCKED",
    "default_max_iterations": 15,
    "qa_retry_max_iterations": 10
  },
  "verification": {
    "require_passing_tests": true,
    "require_gstack_qa": true
  },
  "context_keys_shared": [
    "db_schema",
    "api_contracts",
    "arch_decisions",
    "env_variables",
    "type_definitions"
  ]
}
EOF
  echo -e "  ${GREEN}✓${NC} .planning/config.json"
else
  echo -e "  ${YELLOW}↺${NC} .planning/config.json exists — skipped"
fi

if [ -x "$OBSIDIAN_META" ]; then
  bash "$OBSIDIAN_META" init-project "$(basename "$PWD")" >/dev/null
  bash "$OBSIDIAN_META" normalize-known >/dev/null
  bash "$OBSIDIAN_META" write-bases >/dev/null
  echo -e "  ${GREEN}✓${NC} Obsidian metadata initialized"
fi

# GSS_STATE.json
if [ ! -f ".planning/GSS_STATE.json" ]; then
  cat > .planning/GSS_STATE.json << EOF
{
  "loop_state": "IDLE",
  "current_phase": null,
  "milestones_done": [],
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  echo -e "  ${GREEN}✓${NC} .planning/GSS_STATE.json"
else
  echo -e "  ${YELLOW}↺${NC} .planning/GSS_STATE.json exists — skipped"
fi

# DECISIONS.md
if [ ! -f ".planning/DECISIONS.md" ]; then
  cp "$SKILL_DIR/references/decisions-template.md" .planning/DECISIONS.md
  echo -e "  ${GREEN}✓${NC} .planning/DECISIONS.md"
else
  echo -e "  ${YELLOW}↺${NC} .planning/DECISIONS.md exists — skipped"
fi

# shared_context.md
if [ ! -f ".planning/shared_context.md" ]; then
  cat > .planning/shared_context.md << 'EOF'
# Shared Context — GSS Orchestrator
## db_schema
_pending_
## api_contracts
_pending_
## arch_decisions
_pending_
## env_variables
_pending_
## type_definitions
_pending_
EOF
  echo -e "  ${GREEN}✓${NC} .planning/shared_context.md"
else
  echo -e "  ${YELLOW}↺${NC} .planning/shared_context.md exists — skipped"
fi

# ── 5. Browser automation dependencies ────────────────────────────────────
echo ""
echo "Setting up browser automation..."
if [ -f "$SKILL_DIR/scripts/install_browser_automation_deps.sh" ]; then
  bash "$SKILL_DIR/scripts/install_browser_automation_deps.sh"
else
  echo -e "  ${YELLOW}⚠${NC} install_browser_automation_deps.sh not found — skipped"
fi

# ── 6. Sync agent files ───────────────────────────────────────────────────
echo ""
echo "Syncing subagent files to .claude/agents/ ..."
sync_agents

# ── 7. Summary ────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}=== Setup complete ===${NC}"
echo ""
echo "Trigger the orchestrator in your agent session:"
echo "  \"orchestrate this project for me\""
echo "  \"start gss loop\""
