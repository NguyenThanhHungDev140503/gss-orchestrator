#!/usr/bin/env bash
# install_codex.sh — GSS Orchestrator installer for OpenAI Codex
# Cài skill vào đúng directory structure của Codex (.agents/skills/)
# Tạo agents/openai.yaml cho từng subagent
# Tạo AGENTS.md với authority declaration
#
# Usage:
#   bash install_codex.sh              ← interactive
#   bash install_codex.sh --global     ← cài vào ~/.agents/skills/
#   bash install_codex.sh --project    ← cài vào .agents/skills/ của project hiện tại

set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

SKILL_NAME="gsd-gstack-sp-orchestrator"
SKILL_VERSION="1.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$SCRIPT_DIR"

# ── Parse flags ───────────────────────────────────────────────────────────
SCOPE=""
for arg in "$@"; do
  case "$arg" in
    --global)  SCOPE="global" ;;
    --project) SCOPE="project" ;;
  esac
done

# ── Header ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   GSS Orchestrator — Codex Installer         ║${NC}"
echo -e "${BOLD}║   GSD + GStack + Superpowers for Codex       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Kiểm tra Codex đã cài chưa ───────────────────────────────────────────
echo -e "${CYAN}Checking Codex installation...${NC}"
if command -v codex &>/dev/null; then
  CODEX_VER=$(codex --version 2>/dev/null || echo "unknown")
  echo -e "  ${GREEN}✓${NC} Codex found: $CODEX_VER"
else
  echo -e "  ${YELLOW}⚠${NC} Codex CLI not found in PATH"
  echo -e "  Install: ${DIM}npm i -g @openai/codex${NC}"
  echo -e "  or:      ${DIM}brew install --cask codex${NC}"
  echo ""
  read -rp "  Continue anyway? [y/N]: " CONT
  [[ "${CONT:-N}" =~ ^[Yy]$ ]] || exit 0
fi

# ── Kiểm tra SKILL.md ─────────────────────────────────────────────────────
if [ ! -f "$SKILL_SRC/SKILL.md" ]; then
  echo -e "${RED}ERROR: SKILL.md not found at $SKILL_SRC${NC}"
  echo "Run this script from inside the skill folder."
  exit 1
fi

# ── Chọn scope ────────────────────────────────────────────────────────────
if [ -z "$SCOPE" ]; then
  echo ""
  echo -e "${CYAN}Where do you want to install the skill?${NC}"
  echo ""
  echo -e "  ${BOLD}[1] Global${NC} ${DIM}— dùng cho tất cả projects${NC}"
  echo -e "       Path: ${DIM}~/.agents/skills/$SKILL_NAME/${NC}"
  echo -e "       ${DIM}(also symlinked from ~/.codex/skills/)${NC}"
  echo ""
  echo -e "  ${BOLD}[2] Project${NC} ${DIM}— chỉ project hiện tại${NC}"
  echo -e "       Path: ${DIM}.agents/skills/$SKILL_NAME/${NC}"
  echo -e "       ${DIM}(checked into version control)${NC}"
  echo ""
  read -rp "  Chọn [1/2]: " CHOICE
  case "$CHOICE" in
    1) SCOPE="global" ;;
    2) SCOPE="project" ;;
    *)
      echo -e "${RED}Invalid choice.${NC}"
      exit 1
      ;;
  esac
fi

# ── Resolve paths ─────────────────────────────────────────────────────────
if [ "$SCOPE" = "global" ]; then
  SKILLS_DIR="$HOME/.agents/skills"
  AGENTS_YML_BASE="$HOME/.agents/skills/$SKILL_NAME"
  SCOPE_LABEL="Global (~/.agents/skills/)"
else
  # Project scope — warn nếu không có project root
  if [ ! -d ".git" ] && [ ! -f "AGENTS.md" ] && [ ! -f "package.json" ] \
     && [ ! -f "pyproject.toml" ] && [ ! -f "go.mod" ]; then
    echo -e "${YELLOW}⚠ No project root detected (no .git, AGENTS.md, package.json...)${NC}"
    read -rp "  Install in current directory anyway? [y/N]: " CONFIRM
    [[ "${CONFIRM:-N}" =~ ^[Yy]$ ]] || exit 0
  fi
  SKILLS_DIR="$(pwd)/.agents/skills"
  AGENTS_YML_BASE="$(pwd)/.agents/skills/$SKILL_NAME"
  SCOPE_LABEL="Project ($(pwd)/.agents/skills/)"
fi

SKILL_DEST="$SKILLS_DIR/$SKILL_NAME"

# ── Confirm ───────────────────────────────────────────────────────────────
echo ""
echo -e "  Scope : ${BOLD}$SCOPE_LABEL${NC}"
echo -e "  Skill : ${DIM}$SKILL_DEST${NC}"

if [ -d "$SKILL_DEST" ]; then
  echo -e "  ${YELLOW}⚠ Already exists — files will be overwritten after backup${NC}"
fi

echo ""
read -rp "  Continue? [Y/n]: " PROCEED
[[ "${PROCEED:-Y}" =~ ^[Nn]$ ]] && echo "Cancelled." && exit 0

# ── Copy skill files ──────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Installing skill...${NC}"

if [ -d "$SKILL_DEST" ]; then
  BACKUP_ROOT="$SKILLS_DIR/.backups/$SKILL_NAME"
  BACKUP_DEST="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_ROOT"
  cp -a "$SKILL_DEST" "$BACKUP_DEST"
  echo -e "  ${GREEN}✓${NC} Previous install backed up → $BACKUP_DEST"
fi

mkdir -p "$SKILL_DEST"
# Codex dùng SKILL.codex.md — không dùng SKILL.md của Claude Code
if [ -f "$SKILL_SRC/SKILL.codex.md" ]; then
  cp -f "$SKILL_SRC/SKILL.codex.md" "$SKILL_DEST/SKILL.md"
  echo -e "  ${GREEN}✓${NC} Using Codex-native SKILL.md (from SKILL.codex.md)"
else
  cp -f "$SKILL_SRC/SKILL.md" "$SKILL_DEST/"
fi
cp -rf "$SKILL_SRC/scripts"    "$SKILL_DEST/" 2>/dev/null || true
cp -rf "$SKILL_SRC/references" "$SKILL_DEST/" 2>/dev/null || true
printf "%s\n" "$SKILL_VERSION" > "$SKILL_DEST/VERSION"

# Không copy agents/ của Claude Code — Codex dùng openai.yaml khác
find "$SKILL_DEST/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo -e "  ${GREEN}✓${NC} SKILL.md installed"
echo -e "  ${GREEN}✓${NC} VERSION $SKILL_VERSION"
SCRIPT_COUNT=$(find "$SKILL_DEST/scripts" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
echo -e "  ${GREEN}✓${NC} $SCRIPT_COUNT scripts installed"

# ── Tạo agents/openai.yaml cho skill chính ────────────────────────────────
# Codex dùng file này để config invocation policy và dependencies
echo ""
echo -e "${CYAN}Creating Codex agent configuration...${NC}"

mkdir -p "$SKILL_DEST/agents"
cat > "$SKILL_DEST/agents/openai.yaml" << EOF
display_name: "GSS Orchestrator"
description: >
  Full development orchestrator: GSD planning → GStack review →
  Superpowers TDD execution → QA validation → phase dispatch.
allow_implicit_invocation: true
dependencies:
  skills:
    - gsd-new-project
    - gsd-progress
    - plan-ceo-review
    - plan-eng-review
    - test-driven-development
    - verification-before-completion
policy:
  require_confirmation_before_scripts: false
  allow_file_modification: true
EOF
echo -e "  ${GREEN}✓${NC} agents/openai.yaml created"

# ── Global: tạo symlink ~/.codex/skills/ → ~/.agents/skills/ ─────────────
if [ "$SCOPE" = "global" ]; then
  CODEX_SKILLS_DIR="$HOME/.codex/skills"
  if [ ! -d "$CODEX_SKILLS_DIR" ] && [ ! -L "$CODEX_SKILLS_DIR" ]; then
    mkdir -p "$CODEX_SKILLS_DIR"
  fi

  CODEX_SKILL_LINK="$CODEX_SKILLS_DIR/$SKILL_NAME"
  if [ -L "$CODEX_SKILL_LINK" ]; then
    rm "$CODEX_SKILL_LINK"
  fi
  ln -sf "$SKILL_DEST" "$CODEX_SKILL_LINK" 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} Symlinked → $CODEX_SKILL_LINK" || \
    echo -e "  ${YELLOW}⚠${NC} Could not create symlink (non-critical)"
fi

# ── AGENTS.md — Codex equivalent của CLAUDE.md ───────────────────────────
echo ""
echo -e "${CYAN}Setting up AGENTS.md authority...${NC}"

TEMPLATE="$SKILL_SRC/references/CLAUDE.md.template"
AGENTS_MD_TARGET=""

if [ "$SCOPE" = "global" ]; then
  AGENTS_MD_TARGET="$HOME/.codex/AGENTS.md"
else
  AGENTS_MD_TARGET="$(pwd)/AGENTS.md"
fi

GSS_BLOCK="
---
## GSS Orchestrator — Active

This project uses GSS Orchestrator (GSD + GStack + Superpowers).

### Authority Rules
When GSS is active (\`.planning/GSS_STATE.json\` exists and loop_state ≠ DELIVERED):
- Check \`.planning/GSS_STATE.json\` before any development task
- Follow orchestrator flow — do NOT auto-trigger GSD or Superpowers independently
- GSD, GStack, Superpowers are tools called BY the orchestrator, not autonomous directors

### Skill location
$([ "$SCOPE" = "global" ] && echo "~/.agents/skills/gsd-gstack-sp-orchestrator/" || echo ".agents/skills/gsd-gstack-sp-orchestrator/")

### Quick commands
\`\`\`bash
cat .planning/GSS_STATE.json          # check current state
bash .agents/skills/gsd-gstack-sp-orchestrator/scripts/checkpoint.sh  # save state
\`\`\`
---"

if [ -f "$AGENTS_MD_TARGET" ]; then
  if grep -q "GSS Orchestrator" "$AGENTS_MD_TARGET" 2>/dev/null; then
    echo -e "  ${YELLOW}↺${NC} AGENTS.md already has GSS block — skipped"
  else
    echo "$GSS_BLOCK" >> "$AGENTS_MD_TARGET"
    echo -e "  ${GREEN}✓${NC} GSS block appended to $AGENTS_MD_TARGET"
  fi
else
  cat > "$AGENTS_MD_TARGET" << AGENTS
# AGENTS.md
$GSS_BLOCK
AGENTS
  echo -e "  ${GREEN}✓${NC} AGENTS.md created at $AGENTS_MD_TARGET"
fi

# ── Tạo plugin manifest (optional — để distribute sau) ───────────────────
echo ""
echo -e "${CYAN}Creating plugin manifest...${NC}"
mkdir -p "$SKILL_DEST/.codex-plugin"
PLUGIN_JSON="$SKILL_DEST/.codex-plugin/plugin.json"
cat > "$PLUGIN_JSON" << EOF
{
  "name": "$SKILL_NAME",
  "version": "$SKILL_VERSION",
  "description": "GSS Orchestrator: GSD + GStack + Superpowers development loop",
  "skills": "../",
  "publisher": "gss-orchestrator",
  "license": "MIT"
}
EOF
[ -f "$PLUGIN_JSON.bak" ] \
  && echo -e "  ${YELLOW}↺${NC} .codex-plugin/plugin.json overwritten" \
  || echo -e "  ${GREEN}✓${NC} .codex-plugin/plugin.json created"
rm -f "$PLUGIN_JSON.bak"

# ── Tạo marketplace entry nếu project scope ──────────────────────────────
if [ "$SCOPE" = "project" ]; then
  MARKETPLACE="$(pwd)/.agents/plugins/marketplace.json"
  mkdir -p "$(dirname "$MARKETPLACE")"
  if [ ! -f "$MARKETPLACE" ]; then
    cat > "$MARKETPLACE" << EOF
{
  "name": "local",
  "plugins": [
    {
      "name": "$SKILL_NAME",
      "source": {
        "path": "./.agents/skills/$SKILL_NAME"
      },
      "interface": {
        "displayName": "GSS Orchestrator"
      }
    }
  ]
}
EOF
    echo -e "  ${GREEN}✓${NC} .agents/plugins/marketplace.json created"
  else
    echo -e "  ${YELLOW}↺${NC} marketplace.json exists — skipped"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Installation complete ✅                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Skill   : ${DIM}$SKILL_DEST${NC}"
echo -e "  AGENTS  : ${DIM}$AGENTS_MD_TARGET${NC}"
if [ "$SCOPE" = "global" ]; then
  echo -e "  Symlink : ${DIM}$HOME/.codex/skills/$SKILL_NAME${NC}"
fi
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo ""
echo -e "  1. Restart Codex to load the new skill:"
echo -e "     ${DIM}codex${NC}"
echo ""
echo -e "  2. Verify skill loaded:"
echo -e "     ${DIM}\$gsd-gstack-sp-orchestrator${NC}"
echo -e "     ${DIM}or type: /skills${NC}"
echo ""
echo -e "  3. Run setup check:"
echo -e "     ${DIM}bash $SKILL_DEST/scripts/setup.sh${NC}"
echo ""
echo -e "  4. Trigger the orchestrator:"
echo -e "     ${DIM}orchestrate this project for me${NC}"
echo -e "     ${DIM}start gss loop${NC}"
echo ""
echo -e "${DIM}Note: Codex detects skill changes automatically."
echo -e "If skill doesn't appear, restart Codex.${NC}"
