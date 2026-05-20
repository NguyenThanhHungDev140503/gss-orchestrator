#!/usr/bin/env bash
# install_hermes.sh — GSS Orchestrator installer cho Hermes Agent
# Usage:
#   bash install_hermes.sh              ← interactive
#   bash install_hermes.sh --global     ← cài vào ~/.hermes/skills/devops/
#   bash install_hermes.sh --external   ← thêm vào external_dirs trong config.yaml

set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

SKILL_NAME="gsd-gstack-sp-orchestrator"
HERMES_CATEGORY="devops"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$SCRIPT_DIR"

# ── Parse flags ───────────────────────────────────────────────────────────
MODE=""
for arg in "$@"; do
  case "$arg" in
    --global)   MODE="global" ;;
    --external) MODE="external" ;;
  esac
done

# ── Header ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   GSS Orchestrator — Hermes Agent Installer  ║${NC}"
echo -e "${BOLD}║   GSD + GStack + Superpowers                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Kiểm tra Hermes đã cài chưa ──────────────────────────────────────────
if ! command -v hermes &>/dev/null; then
  echo -e "${RED}✗ Hermes Agent not found.${NC}"
  echo ""
  echo "Install Hermes first:"
  echo "  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
  exit 1
fi

HERMES_VER=$(hermes --version 2>/dev/null || echo "unknown")
echo -e "  ${GREEN}✓${NC} Hermes Agent found: $HERMES_VER"

# ── Detect Hermes home ────────────────────────────────────────────────────
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_SKILLS_DIR="$HERMES_HOME/skills"
HERMES_CONFIG="$HERMES_HOME/config.yaml"

if [ ! -d "$HERMES_HOME" ]; then
  echo -e "${RED}✗ ~/.hermes not found. Run 'hermes init' first.${NC}"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} Hermes home: $HERMES_HOME"

# ── Kiểm tra SKILL.md ─────────────────────────────────────────────────────
if [ ! -f "$SKILL_SRC/SKILL.md" ]; then
  echo -e "${RED}ERROR: SKILL.md not found at $SKILL_SRC${NC}"
  echo "Run this script from inside the skill folder."
  exit 1
fi

# ── Compatibility notice ──────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}━━ Compatibility Notice ━━${NC}"
echo ""
echo "  GSS Orchestrator phụ thuộc vào GSD, GStack, Superpowers —"
echo "  đây là Claude Code plugins, KHÔNG phải Hermes native tools."
echo ""
echo "  Trong Hermes Agent, skill này hoạt động ở chế độ:"
echo -e "  ${BOLD}Script-first${NC} — orchestration logic chạy qua bash scripts,"
echo "  không cần plugin slash commands."
echo ""
echo "  Thay thế tương đương trong Hermes:"
echo "  - GSD planning   → scripts/gss-plan-hermes.sh (được tạo khi cài)"
echo "  - GStack review  → Hermes memory + skill_manage tự cải thiện"
echo "  - Superpowers    → scripts/run_phase.sh (claude -p hoặc hermes -p)"
echo ""
read -rp "  Tiếp tục cài đặt? [Y/n]: " PROCEED
[[ "${PROCEED:-Y}" =~ ^[Nn]$ ]] && echo "Cancelled." && exit 0

# ── Chọn mode nếu chưa có flag ────────────────────────────────────────────
if [ -z "$MODE" ]; then
  echo ""
  echo -e "${CYAN}Chọn cách cài đặt:${NC}"
  echo ""
  echo -e "  ${BOLD}[1] Global install${NC}"
  echo -e "       ${DIM}~/.hermes/skills/devops/$SKILL_NAME/${NC}"
  echo -e "       Hermes tự động load — dùng được ngay"
  echo ""
  echo -e "  ${BOLD}[2] External directory${NC}"
  echo -e "       ${DIM}Thêm path hiện tại vào skills.external_dirs trong config.yaml${NC}"
  echo -e "       Dùng khi muốn edit skill trực tiếp tại source"
  echo ""
  read -rp "  Chọn [1/2]: " CHOICE
  case "$CHOICE" in
    1) MODE="global" ;;
    2) MODE="external" ;;
    *)
      echo -e "${RED}Invalid choice.${NC}" && exit 1 ;;
  esac
fi

# ── MODE: Global install ──────────────────────────────────────────────────
if [ "$MODE" = "global" ]; then
  DEST="$HERMES_SKILLS_DIR/$HERMES_CATEGORY/$SKILL_NAME"
  echo ""
  echo -e "${CYAN}Installing to $DEST ...${NC}"

  if [ -d "$DEST" ]; then
    echo -e "  ${YELLOW}⚠ Skill đã tồn tại — sẽ ghi đè${NC}"
  fi

  mkdir -p "$DEST"

  # Copy core files
  cp -f "$SKILL_SRC/SKILL.md" "$DEST/"

  # Adapt SKILL.md cho Hermes: thay path Claude Code bằng ${HERMES_SKILL_DIR}
  python3 - << PYEOF
content = open("$DEST/SKILL.md").read()

# Thay Claude Code skill path references bằng Hermes token
content = content.replace(
    ".claude/skills/gsd-gstack-sp-orchestrator/scripts/",
    "\${HERMES_SKILL_DIR}/scripts/"
)
content = content.replace(
    ".claude/skills/gsd-gstack-sp-orchestrator/references/",
    "\${HERMES_SKILL_DIR}/references/"
)

# Thêm Hermes-specific header note
hermes_note = """
> **Hermes Agent Mode:** GSD/GStack/Superpowers slash commands không available.
> Dùng bash scripts trong \${HERMES_SKILL_DIR}/scripts/ thay thế.
> Xem \${HERMES_SKILL_DIR}/references/hermes-compat.md để biết mapping.

"""
content = content.replace("# GSD + GStack + Superpowers Orchestrator\n", 
    "# GSD + GStack + Superpowers Orchestrator\n" + hermes_note)

open("$DEST/SKILL.md", "w").write(content)
print("SKILL.md adapted for Hermes")
PYEOF

  # Copy scripts
  if [ -d "$SKILL_SRC/scripts" ]; then
    cp -rf "$SKILL_SRC/scripts" "$DEST/"
    find "$DEST/scripts" -name "*.sh" -exec chmod +x {} \;
    echo -e "  ${GREEN}✓${NC} Scripts installed"
  fi

  # Copy references
  if [ -d "$SKILL_SRC/references" ]; then
    cp -rf "$SKILL_SRC/references" "$DEST/"
    echo -e "  ${GREEN}✓${NC} References installed"
  fi

  # Tạo hermes-compat.md — mapping Claude Code concepts sang Hermes
  mkdir -p "$DEST/references"
  cat > "$DEST/references/hermes-compat.md" << 'COMPAT'
# Hermes Compatibility Map

## Claude Code → Hermes equivalent

| Claude Code | Hermes equivalent |
|---|---|
| `/gsd-new-project` | `bash ${HERMES_SKILL_DIR}/scripts/gss-plan-hermes.sh` |
| `/plan-ceo-review` | Describe requirements, Hermes tự analyze và save vào memory |
| `/plan-eng-review` | `bash ${HERMES_SKILL_DIR}/scripts/write_exec_prompt.sh` |
| `/gstack:engineer` | Hỏi Hermes trực tiếp, answer được log vào DECISIONS.md |
| `/gstack:qa` | `bash ${HERMES_SKILL_DIR}/scripts/run_qa.sh --fallback` |
| `/gsd-complete-milestone` | `bash ${HERMES_SKILL_DIR}/scripts/update_state.sh "DONE"` |
| Task tool (subagent) | `bash ${HERMES_SKILL_DIR}/scripts/run_phase.sh --fallback` |

## Subagents trong Hermes

Hermes không có `.claude/agents/` concept. Thay vào đó:
- `gss-executor` logic → `run_phase.sh --fallback` (claude -p subprocess)
- `gss-reviewer` logic → Hermes tự analyze + summarize_gstack.sh
- `gss-qa` logic → `run_qa.sh --fallback`

## Memory integration

Sau khi GStack review (dù là Hermes native hay script), Hermes
tự động ghi nhớ decisions vào memory nếu được trigger:

```
"Hermes, remember this decision for the current project:
 [paste DECISIONS.md entry]"
```

Hermes sẽ persist vào long-term memory và reference lại trong
các sessions tiếp theo — không cần DECISIONS.md thủ công.

## External dirs

Skill này có thể được share across profiles qua:
```yaml
# ~/.hermes/config.yaml
skills:
  external_dirs:
    - ~/.hermes/skills/devops/gsd-gstack-sp-orchestrator
```
COMPAT

  echo -e "  ${GREEN}✓${NC} Hermes compatibility guide created"

  # Tạo gss-plan-hermes.sh — thay thế GSD planning cho Hermes
  cat > "$DEST/scripts/gss-plan-hermes.sh" << 'PLAN_SCRIPT'
#!/usr/bin/env bash
# gss-plan-hermes.sh — GSD planning thay thế cho Hermes Agent
# Không cần /gsd-new-project slash command

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/resolve_gsd_paths.sh" 2>/dev/null || true

echo ""
echo "━━ GSS Planning (Hermes Mode) ━━"
echo ""
echo "Hermes không dùng /gsd-new-project."
echo "Thay vào đó, tạo cấu trúc planning thủ công:"
echo ""

mkdir -p .planning/phases .planning/archive

# Tạo STATE.md nếu chưa có
if [ ! -f ".planning/STATE.md" ]; then
  cat > ".planning/STATE.md" << STATE
# GSS State

Current Phase: 
Status: planning
Started: $(date -u +"%Y-%m-%d %H:%M UTC")
STATE
  echo "✓ .planning/STATE.md created"
fi

# Tạo ROADMAP.md nếu chưa có
if [ ! -f ".planning/ROADMAP.md" ]; then
  cat > ".planning/ROADMAP.md" << ROADMAP
# Roadmap

## Phases

- [ ] Phase 01: [Describe first phase]
- [ ] Phase 02: [Describe second phase]

## Goal
[Describe project goal here]
ROADMAP
  echo "✓ .planning/ROADMAP.md created — edit this file to define your phases"
fi

echo ""
echo "Next:"
echo "  1. Edit .planning/ROADMAP.md — define your phases"
echo "  2. Edit .planning/STATE.md — set Current Phase"
echo "  3. Tell Hermes: 'Review this roadmap and give me an engineering plan'"
echo "  4. bash ${SCRIPT_DIR}/write_exec_prompt.sh"
echo "  5. bash ${SCRIPT_DIR}/run_phase.sh --fallback"
PLAN_SCRIPT

  chmod +x "$DEST/scripts/gss-plan-hermes.sh"
  echo -e "  ${GREEN}✓${NC} gss-plan-hermes.sh created"

  echo ""
  echo -e "${GREEN}✓ Skill installed to $DEST${NC}"

# ── MODE: External directory ──────────────────────────────────────────────
elif [ "$MODE" = "external" ]; then
  echo ""
  echo -e "${CYAN}Adding to external_dirs in config.yaml ...${NC}"

  if [ ! -f "$HERMES_CONFIG" ]; then
    echo -e "${RED}ERROR: $HERMES_CONFIG not found.${NC}"
    echo "Run 'hermes init' first."
    exit 1
  fi

  # Check nếu đã có trong external_dirs
  if grep -q "$SKILL_SRC" "$HERMES_CONFIG" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠ Path đã có trong config.yaml — skipped${NC}"
  else
    # Append external_dirs vào config.yaml
    if grep -q "^skills:" "$HERMES_CONFIG"; then
      # skills section đã có
      if grep -q "external_dirs:" "$HERMES_CONFIG"; then
        # external_dirs đã có — thêm entry
        python3 - << PYEOF
import re
content = open("$HERMES_CONFIG").read()
# Tìm external_dirs block và thêm dòng mới
content = re.sub(
    r'(external_dirs:\s*\n)',
    r'\1    - $SKILL_SRC\n',
    content
)
open("$HERMES_CONFIG", "w").write(content)
print("Entry added to existing external_dirs")
PYEOF
      else
        # external_dirs chưa có — thêm vào sau skills:
        python3 - << PYEOF
content = open("$HERMES_CONFIG").read()
content = content.replace(
    "skills:\n",
    "skills:\n  external_dirs:\n    - $SKILL_SRC\n"
)
open("$HERMES_CONFIG", "w").write(content)
print("external_dirs added to skills section")
PYEOF
      fi
    else
      # Không có skills section — append
      echo "" >> "$HERMES_CONFIG"
      cat >> "$HERMES_CONFIG" << YAML
skills:
  external_dirs:
    - $SKILL_SRC
YAML
      echo "  skills.external_dirs added to config.yaml"
    fi

    echo -e "  ${GREEN}✓${NC} Added to external_dirs: $SKILL_SRC"
    echo ""
    echo -e "  ${DIM}Note: External dirs are read-only. Hermes will not modify skills here.${NC}"
    echo -e "  ${DIM}Local precedence: nếu skill trùng tên, ~/.hermes/skills/ version thắng.${NC}"
  fi
fi

# ── Invalidate skill cache ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Reloading skill index...${NC}"
if hermes skills reload &>/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} Skill index reloaded"
else
  echo -e "  ${YELLOW}⚠${NC} Cannot reload automatically. Start a new Hermes session to pick up changes."
fi

# ── Summary ───────────────────────────────────────────────────────────────
DEST_FINAL="${DEST:-$SKILL_SRC}"
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Installation complete ✅ (Hermes Mode)     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Skill path : ${DIM}$DEST_FINAL${NC}"
echo -e "  Hermes home: ${DIM}$HERMES_HOME${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo ""
echo "  1. Start a new Hermes session:"
echo -e "     ${DIM}hermes${NC}"
echo ""
echo "  2. Verify skill loaded:"
echo -e "     ${DIM}/gsd-gstack-sp-orchestrator${NC}"
echo -e "     ${DIM}# hoặc: hermes skills list | grep gsd${NC}"
echo ""
echo "  3. Setup project planning:"
echo -e "     ${DIM}bash \${HERMES_SKILL_DIR}/scripts/gss-plan-hermes.sh${NC}"
echo -e "     ${DIM}# Tạo .planning/ structure phù hợp Hermes${NC}"
echo ""
echo "  4. Xem compatibility guide:"
echo -e "     ${DIM}cat $DEST_FINAL/references/hermes-compat.md${NC}"
echo ""
echo -e "${YELLOW}Lưu ý:${NC} GSD/GStack/Superpowers là Claude Code plugins."
echo "  Trong Hermes, dùng bash scripts + Hermes native memory thay thế."
echo "  Xem references/hermes-compat.md để biết mapping đầy đủ."
echo ""
