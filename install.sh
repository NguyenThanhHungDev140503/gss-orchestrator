#!/usr/bin/env bash
# install.sh — GSS Orchestrator installer
# Usage: bash install.sh
#        bash install.sh --global
#        bash install.sh --project
#        bash install.sh --global --no-agents

set -e

# ── Colors ────────────────────────────────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

SKILL_NAME="gsd-gstack-sp-orchestrator"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$SCRIPT_DIR"
REQUIRED_AGENTS=(
  gss-researcher.md
  gss-gsd-runner.md
  gss-reviewer.md
  gss-devex-reviewer.md
  gss-designer.md
  gss-docs.md
  gss-debugger.md
  gss-executor.md
  gss-qa.md
  gss-brainstormer.md
)

# ── Parse flags ───────────────────────────────────────────────────────────
SCOPE=""        # global | project
INSTALL_AGENTS=true

for arg in "$@"; do
  case "$arg" in
    --global)    SCOPE="global" ;;
    --project)   SCOPE="project" ;;
    --no-agents) INSTALL_AGENTS=false ;;
  esac
done

# ── Header ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   GSS Orchestrator — Installer               ║${NC}"
echo -e "${BOLD}║   GSD + GStack + Superpowers                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Kiểm tra SKILL.md tồn tại ─────────────────────────────────────────────
if [ ! -f "$SKILL_SRC/SKILL.md" ]; then
  echo -e "${RED}ERROR: SKILL.md not found at $SKILL_SRC${NC}"
  echo "Run this script from inside the skill folder."
  exit 1
fi

if [ "$INSTALL_AGENTS" = true ]; then
  if [ ! -d "$SKILL_SRC/agents" ]; then
    echo -e "${RED}ERROR: agents/ not found at $SKILL_SRC${NC}"
    echo "The installer needs wrapper subagents, including gss-devex-reviewer.md."
    exit 1
  fi

  for required_agent in "${REQUIRED_AGENTS[@]}"; do
    if [ ! -f "$SKILL_SRC/agents/$required_agent" ]; then
      echo -e "${RED}ERROR: required subagent missing: $required_agent${NC}"
      exit 1
    fi
  done
fi

# ── Chọn scope nếu chưa truyền flag ───────────────────────────────────────
if [ -z "$SCOPE" ]; then
  echo -e "${CYAN}Where do you want to install the skill?${NC}"
  echo ""
  echo -e "  ${BOLD}[1] Global${NC} ${DIM}— dùng cho tất cả projects${NC}"
  echo -e "       Path: ${DIM}~/.claude/skills/$SKILL_NAME/${NC}"
  echo ""
  echo -e "  ${BOLD}[2] Project${NC} ${DIM}— chỉ project hiện tại${NC}"
  echo -e "       Path: ${DIM}.claude/skills/$SKILL_NAME/${NC}"
  echo ""
  read -rp "  Chọn [1/2]: " CHOICE

  case "$CHOICE" in
    1) SCOPE="global" ;;
    2) SCOPE="project" ;;
    *)
      echo -e "${RED}Invalid choice. Exiting.${NC}"
      exit 1
      ;;
  esac
fi

# ── Resolve install path ──────────────────────────────────────────────────
if [ "$SCOPE" = "global" ]; then
  SKILLS_DIR="$HOME/.claude/skills"
  AGENTS_DIR="$HOME/.claude/agents"
  SCOPE_LABEL="Global (~/.claude/)"
else
  # Project scope — phải đang ở trong project dir
  if [ ! -d ".git" ] && [ ! -f "package.json" ] && [ ! -f "pyproject.toml" ] \
     && [ ! -f "go.mod" ] && [ ! -f "CLAUDE.md" ]; then
    echo -e "${YELLOW}⚠ Không tìm thấy project root (không có .git, package.json, v.v.)${NC}"
    read -rp "  Vẫn cài vào thư mục hiện tại? [y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0
  fi
  SKILLS_DIR="$(pwd)/.claude/skills"
  AGENTS_DIR="$(pwd)/.claude/agents"
  SCOPE_LABEL="Project ($(pwd)/.claude/)"
fi

SKILL_DEST="$SKILLS_DIR/$SKILL_NAME"

# ── Confirm + overwrite warning ───────────────────────────────────────────
echo ""
echo -e "  Scope  : ${BOLD}$SCOPE_LABEL${NC}"
echo -e "  Skill  : ${DIM}$SKILL_DEST${NC}"
[ "$INSTALL_AGENTS" = true ] && \
  echo -e "  Agents : ${DIM}$AGENTS_DIR${NC}"

if [ -d "$SKILL_DEST" ]; then
  echo ""
  echo -e "  ${YELLOW}⚠ Skill đã tồn tại tại $SKILL_DEST${NC}"
  echo -e "  ${YELLOW}  Các file trùng sẽ bị ghi đè.${NC}"
fi

echo ""
read -rp "  Tiếp tục cài đặt? [Y/n]: " PROCEED
[[ "${PROCEED:-Y}" =~ ^[Nn]$ ]] && echo "Cancelled." && exit 0

# ── Install skill ─────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Installing skill...${NC}"

mkdir -p "$SKILL_DEST"

# Copy tất cả files, ghi đè nếu trùng (-f)
cp -rf "$SKILL_SRC/SKILL.md"     "$SKILL_DEST/"
cp -rf "$SKILL_SRC/scripts"      "$SKILL_DEST/" 2>/dev/null || true
cp -rf "$SKILL_SRC/references"   "$SKILL_DEST/" 2>/dev/null || true
cp -rf "$SKILL_SRC/agents"       "$SKILL_DEST/" 2>/dev/null || true

# Cấp quyền execute cho tất cả scripts
find "$SKILL_DEST/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo -e "  ${GREEN}✓${NC} Skill installed → $SKILL_DEST"

# Verify SKILL.md
[ -f "$SKILL_DEST/SKILL.md" ] \
  && echo -e "  ${GREEN}✓${NC} SKILL.md present" \
  || echo -e "  ${RED}✗${NC} SKILL.md missing — something went wrong"

# Count scripts
SCRIPT_COUNT=$(find "$SKILL_DEST/scripts" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
echo -e "  ${GREEN}✓${NC} $SCRIPT_COUNT scripts installed"

# ── Install subagent files ────────────────────────────────────────────────
if [ "$INSTALL_AGENTS" = true ] && [ -d "$SKILL_SRC/agents" ]; then
  echo ""
  echo -e "${CYAN}Installing subagents...${NC}"
  mkdir -p "$AGENTS_DIR"

  AGENT_COUNT=0
  for agent_file in "$SKILL_SRC/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file")
    dest="$AGENTS_DIR/$agent_name"

    if [ -f "$dest" ]; then
      cp -f "$agent_file" "$dest"
      echo -e "  ${YELLOW}↺${NC} Overwritten → $dest"
    else
      cp -f "$agent_file" "$dest"
      echo -e "  ${GREEN}✓${NC} Installed  → $dest"
    fi
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done

  echo -e "  ${GREEN}✓${NC} $AGENT_COUNT subagent(s) installed"
fi

# ── Deploy CLAUDE.md (authority declaration) ─────────────────────────────
echo ""
echo -e "${CYAN}Setting up CLAUDE.md authority...${NC}"

TEMPLATE="$SKILL_DEST/references/CLAUDE.md.template"
CLAUDE_MD="$(pwd)/CLAUDE.md"

if [ -f "$TEMPLATE" ]; then
  if [ -f "$CLAUDE_MD" ]; then
    # CLAUDE.md đã tồn tại — append GSS block nếu chưa có
    if grep -q "GSS Orchestrator" "$CLAUDE_MD" 2>/dev/null; then
      echo -e "  ${YELLOW}↺${NC} CLAUDE.md already has GSS block — skipped"
    else
      echo "" >> "$CLAUDE_MD"
      echo "---" >> "$CLAUDE_MD"
      cat "$TEMPLATE" >> "$CLAUDE_MD"
      echo -e "  ${GREEN}✓${NC} GSS block appended to existing CLAUDE.md"
    fi
  else
    cp "$TEMPLATE" "$CLAUDE_MD"
    echo -e "  ${GREEN}✓${NC} CLAUDE.md created"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} Template not found — CLAUDE.md not modified"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Installation complete ✅                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Skill path : ${DIM}$SKILL_DEST${NC}"
[ "$INSTALL_AGENTS" = true ] && \
  echo -e "  Agents path: ${DIM}$AGENTS_DIR${NC}"
echo ""
# ── Deploy agents vào project ─────────────────────────────────────────────
echo ""
echo -e "${CYAN}Deploy subagents to your project...${NC}"
echo ""

if [ "$SCOPE" = "global" ]; then
  # Global install: agents ở ~/.claude/agents/ — Claude Code tự load cho mọi project
  echo -e "  ${GREEN}✓${NC} Agents installed globally → $AGENTS_DIR"
  echo -e "  ${DIM}Claude Code loads these automatically for all projects.${NC}"
else
  # Project-scoped install: copy thẳng vào project hiện tại
  PROJECT_AGENTS="$(pwd)/.claude/agents"
  mkdir -p "$PROJECT_AGENTS"
  AGENT_COUNT=0
  for agent_file in "$SKILL_SRC/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    cp -f "$agent_file" "$PROJECT_AGENTS/"
    echo -e "  ${GREEN}✓${NC} $(basename "$agent_file") → $PROJECT_AGENTS/"
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done
  echo -e "  ${GREEN}✓${NC} $AGENT_COUNT agent(s) deployed to project"
fi

echo -e "${CYAN}Next steps:${NC}"
echo ""
echo -e "  1. Open Claude Code in your project:"
echo -e "     ${DIM}cd /your/project && claude${NC}"
echo ""
echo -e "  2. Run setup:"
echo -e "     ${DIM}bash $SKILL_DEST/scripts/setup.sh${NC}"
echo ""
echo -e "  3. Trigger the skill:"
echo -e "     ${DIM}orchestrate this project for me${NC}"
echo ""
