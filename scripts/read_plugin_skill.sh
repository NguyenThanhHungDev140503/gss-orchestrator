#!/usr/bin/env bash
# scripts/read_plugin_skill.sh
# Đọc SKILL.md của một plugin đã cài, dùng để inject vào Task tool prompt.
#
# Usage:
#   bash scripts/read_plugin_skill.sh gsd
#   bash scripts/read_plugin_skill.sh gstack
#   bash scripts/read_plugin_skill.sh superpowers

PLUGIN="${1:-}"
[ -z "$PLUGIN" ] && echo "Usage: read_plugin_skill.sh <plugin-name>" && exit 1

# Tìm SKILL.md theo tên plugin
find_skill() {
  local name="$1"
  # ~/.claude/plugins/<name>*
  local f
  f=$(find ~/.claude/plugins -maxdepth 3 -ipath "*${name}*/SKILL.md" 2>/dev/null | head -1)
  [ -n "$f" ] && echo "$f" && return
  # ~/.claude/skills/<name>*
  f=$(find ~/.claude/skills -maxdepth 3 -ipath "*${name}*/SKILL.md" 2>/dev/null | head -1)
  [ -n "$f" ] && echo "$f" && return
  echo ""
}

SKILL_PATH=$(find_skill "$PLUGIN")

if [ -z "$SKILL_PATH" ]; then
  echo "ERROR: SKILL.md not found for plugin: $PLUGIN"
  echo "Checked: ~/.claude/plugins/ and ~/.claude/skills/"
  exit 1
fi

cat "$SKILL_PATH"
