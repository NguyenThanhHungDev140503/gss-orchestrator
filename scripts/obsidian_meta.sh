#!/usr/bin/env bash
set -euo pipefail

PLANNING_DIR="${GSS_PLANNING_DIR:-.planning}"
SLUG_FILE="$PLANNING_DIR/.project_slug"

today() {
  date +%Y-%m-%d
}

slugify() {
  local raw="${1:-}"
  if [ -z "$raw" ]; then
    raw="$(basename "$PWD")"
  fi

  printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' _' '--' \
    | sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//'
}

write_slug() {
  mkdir -p "$PLANNING_DIR"

  local slug
  slug="$(slugify "${1:-}")"
  if [ -z "$slug" ]; then
    slug="project"
  fi

  printf '%s\n' "$slug" > "$SLUG_FILE"
  printf '%s\n' "$slug"
}

project_slug() {
  mkdir -p "$PLANNING_DIR"

  if [ -s "$SLUG_FILE" ]; then
    cat "$SLUG_FILE"
    return 0
  fi

  write_slug "$(basename "$PWD")"
}

has_frontmatter() {
  local file="$1"

  [ -f "$file" ] || return 1
  [ "$(sed -n '1p' "$file")" = "---" ] || return 1
  sed -n '2,80p' "$file" | grep -qx -- "---"
}

frontmatter_for() {
  local file="$1"
  local type="$2"
  local phase="${3:-}"
  local slug="$4"
  local date="$5"
  local title
  title="$(basename "$file" .md)"

  cat <<EOF
---
title: "$title"
type: $type
project_slug: $slug
tags:
  - gsd
  - $type
  - project/$slug
created: $date
updated: $date
EOF

  if [ "$type" = "research" ]; then
    echo "research_dimension: summary"
  fi

  if [ -n "$phase" ]; then
    cat <<EOF
phase: $phase
project: "[[../../PROJECT]]"
EOF
  elif [ "$file" != "$PLANNING_DIR/PROJECT.md" ]; then
    echo 'project: "[[PROJECT]]"'
  fi

  case "$type" in
    decision-log)
      if [ -n "$phase" ]; then
        echo 'plan: "[[PLAN]]"'
      fi
      ;;
    brainstorm)
      echo 'plan: "[[PLAN]]"'
      echo 'decisions: "[[DECISIONS]]"'
      ;;
    roadmap)
      echo 'related:'
      echo '  - "[[REQUIREMENTS]]"'
      echo '  - "[[PROJECT]]"'
      ;;
    requirements)
      echo 'related:'
      echo '  - "[[ROADMAP]]"'
      echo '  - "[[PROJECT]]"'
      ;;
  esac

  echo "---"
}

ensure_frontmatter() {
  local file="${1:-}"
  local type="${2:-}"
  local phase="${3:-}"

  if [ -z "$file" ] || [ -z "$type" ]; then
    echo "Usage: obsidian_meta.sh ensure-frontmatter <path> <type> [phase]" >&2
    exit 1
  fi

  [ -f "$file" ] || return 0

  local slug date tmp
  slug="$(project_slug)"
  date="$(today)"
  tmp="$(mktemp)"

  if has_frontmatter "$file"; then
    awk -v updated="$date" '
      BEGIN { in_fm=0; done=0 }
      NR==1 && $0=="---" { in_fm=1; print; next }
      in_fm && $0=="---" {
        if (!done) print "updated: " updated
        in_fm=0
        print
        next
      }
      in_fm && $0 ~ /^updated:/ {
        print "updated: " updated
        done=1
        next
      }
      { print }
    ' "$file" > "$tmp"
  elif [ "$(sed -n '1p' "$file")" = "---" ]; then
    echo "WARN: malformed frontmatter in $file; left unchanged" >&2
    rm -f "$tmp"
    return 0
  else
    frontmatter_for "$file" "$type" "$phase" "$slug" "$date" > "$tmp"
    printf '\n' >> "$tmp"
    cat "$file" >> "$tmp"
  fi

  mv "$tmp" "$file"
}

normalize_known() {
  ensure_frontmatter "$PLANNING_DIR/REQUIREMENTS.md" requirements
  ensure_frontmatter "$PLANNING_DIR/RESEARCH.md" research
  ensure_frontmatter "$PLANNING_DIR/PROJECT.md" project
  ensure_frontmatter "$PLANNING_DIR/ROADMAP.md" roadmap
  ensure_frontmatter "$PLANNING_DIR/DECISIONS.md" decision-log
  ensure_frontmatter "$PLANNING_DIR/shared_context.md" shared-context
  ensure_frontmatter "$PLANNING_DIR/CHECKPOINT_HISTORY.md" checkpoint-log

  local phase_dir phase
  for phase_dir in "$PLANNING_DIR"/phases/*; do
    [ -d "$phase_dir" ] || continue
    phase="$(basename "$phase_dir")"
    ensure_frontmatter "$phase_dir/PLAN.md" plan "$phase"
    ensure_frontmatter "$phase_dir/DECISIONS.md" decision-log "$phase"
    ensure_frontmatter "$phase_dir/BRAINSTORM_DOC.md" brainstorm "$phase"
    ensure_frontmatter "$phase_dir/EXEC_PROMPT.md" execution-prompt "$phase"
  done
}

write_bases() {
  local slug
  slug="$(project_slug)"
  mkdir -p "$PLANNING_DIR/bases"

  cat > "$PLANNING_DIR/bases/project-dashboard.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - file.hasTag("project/$slug")

properties:
  type:
    displayName: "Type"
  status:
    displayName: "Status"
  phase:
    displayName: "Phase"

views:
  - type: table
    name: "All Documents"
    order:
      - file.name
      - type
      - status
      - file.mtime
    groupBy:
      property: type
      direction: ASC
EOF

  cat > "$PLANNING_DIR/bases/phases.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - type == "plan"
    - file.hasTag("project/$slug")

views:
  - type: table
    name: "All Phases"
    order:
      - file.name
      - phase
      - status
      - file.mtime
EOF

  cat > "$PLANNING_DIR/bases/research.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - type == "research"
    - file.hasTag("project/$slug")

views:
  - type: table
    name: "Research Docs"
    order:
      - file.name
      - research_dimension
      - file.mtime
EOF

  cat > "$PLANNING_DIR/bases/decisions.base" <<EOF
filters:
  and:
    - file.hasTag("gsd")
    - type == "decision-log"
    - file.hasTag("project/$slug")

views:
  - type: table
    name: "All Decisions"
    order:
      - file.name
      - phase
      - file.mtime
EOF
}

cmd="${1:-}"
case "$cmd" in
  init-project)
    write_slug "${2:-}"
    ;;
  ensure-frontmatter)
    ensure_frontmatter "${2:-}" "${3:-}" "${4:-}"
    ;;
  normalize-known)
    normalize_known
    ;;
  write-bases)
    write_bases
    ;;
  *)
    echo "Usage: obsidian_meta.sh init-project [name] | ensure-frontmatter <path> <type> [phase] | normalize-known | write-bases" >&2
    exit 1
    ;;
esac
