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
  if [ -s "$SLUG_FILE" ]; then
    cat "$SLUG_FILE"
    return 0
  fi

  # Read-only resolution: compute from cwd without persisting a slug file.
  local slug
  slug="$(slugify "$(basename "$PWD")")"
  [ -z "$slug" ] && slug="project"
  printf '%s\n' "$slug"
}

# init-project has two intents:
#   * with a name  -> intentional set; overrides any existing (e.g. derived) slug
#   * without a name -> no-clobber bootstrap; only derive from the directory name
#     when no slug exists yet, so the every-turn bootstrap never overwrites a
#     real name chosen in Phase 0.
init_project() {
  mkdir -p "$PLANNING_DIR"
  local name="${1:-}"

  if [ -n "$name" ]; then
    write_slug "$name"
    return 0
  fi

  if [ -s "$SLUG_FILE" ]; then
    cat "$SLUG_FILE"
    return 0
  fi
  write_slug ""
}

has_frontmatter() {
  local file="$1"

  [ -f "$file" ] || return 1
  frontmatter_end_line "$file" >/dev/null
}

frontmatter_end_line() {
  local file="$1"

  [ -f "$file" ] || return 1
  awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR == 1 { next }
    $0 == "---" {
      print NR
      found = 1
      exit
    }
    END {
      if (!found) exit 1
    }
  ' "$file"
}

frontmatter_for() {
  local file="$1"
  local type="$2"
  local phase="${3:-}"
  local slug="$4"
  local created="$5"
  local updated="$6"
  local extras="${7:-}"
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
created: $created
updated: $updated
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

  if [ -n "$extras" ] && [ -s "$extras" ]; then
    cat "$extras"
  fi

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

  local slug today_date created updated tmp extras
  slug="$(project_slug)"
  today_date="$(today)"
  tmp="$(mktemp)"
  extras="$(mktemp)"

  if has_frontmatter "$file"; then
    local end_line
    end_line="$(frontmatter_end_line "$file")"

    # Preserve the original created date when present.
    created="$(sed -n "2,${end_line}p" "$file" | sed -n 's/^created:[[:space:]]*//p' | head -1)"
    [ -z "$created" ] && created="$today_date"

    # Preserve unmanaged frontmatter so re-normalize is non-destructive.
    # Drop helper-managed keys and the list items they own (tags/related).
    sed -n "2,$((end_line - 1))p" "$file" | awk '
      BEGIN { skipping = 0 }
      /^[A-Za-z0-9_]+:/ {
        key = $0
        sub(/:.*/, "", key)
        managed = (key == "title" || key == "type" || key == "project_slug"           || key == "tags" || key == "created" || key == "updated"           || key == "research_dimension" || key == "phase" || key == "project"           || key == "plan" || key == "decisions" || key == "related")
        if (managed) { skipping = 1; next }
        skipping = 0
        print
        next
      }
      /^[[:space:]]*-/ { if (skipping) next; print; next }
      /^[[:space:]]/ { if (skipping) next; print; next }
      { skipping = 0; print }
    ' > "$extras"

    updated="$today_date"
    frontmatter_for "$file" "$type" "$phase" "$slug" "$created" "$updated" "$extras" > "$tmp"
    printf '\n' >> "$tmp"
    tail -n +"$((end_line + 1))" "$file" >> "$tmp"
  elif [ "$(sed -n '1p' "$file")" = "---" ]; then
    echo "WARN: malformed frontmatter in $file; left unchanged" >&2
    rm -f "$tmp" "$extras"
    return 0
  else
    created="$today_date"
    updated="$today_date"
    frontmatter_for "$file" "$type" "$phase" "$slug" "$created" "$updated" "" > "$tmp"
    printf '\n' >> "$tmp"
    cat "$file" >> "$tmp"
  fi

  rm -f "$extras"
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
    init_project "${2:-}"
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
