#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/update_state.sh"

fail() { echo "$1" >&2; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.planning"
cat > "$tmpdir/.planning/GSS_STATE.json" <<'EOF'
{"loop_state":"PLANNING","current_milestone":"01-auth"}
EOF

(
  cd "$tmpdir"
  bash "$SCRIPT" "GSTACK_REVIEW" "01-auth" "true" "Project exposes a REST API and CLI" "existing_project"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "true" ] || fail "Expected devex_surface=true, got '$val'"
  rationale=$(jq -r '.devex_rationale' .planning/GSS_STATE.json)
  [ "$rationale" = "Project exposes a REST API and CLI" ] || fail "Expected devex_rationale preserved, got '$rationale'"
  mode=$(jq -r '.project_mode' .planning/GSS_STATE.json)
  [ "$mode" = "existing_project" ] || fail "Expected project_mode=existing_project, got '$mode'"
)

(
  cd "$tmpdir"
  bash "$SCRIPT" "GSTACK_DX_REVIEW" "" "false"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "false" ] || fail "Expected devex_surface=false, got '$val'"
)

(
  cd "$tmpdir"
  bash "$SCRIPT" "SP_BRAINSTORM"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "false" ] || fail "Expected devex_surface preserved as false, got '$val'"
  rationale=$(jq -r '.devex_rationale' .planning/GSS_STATE.json)
  [ "$rationale" = "Project exposes a REST API and CLI" ] || fail "Expected devex_rationale preserved, got '$rationale'"
  mode=$(jq -r '.project_mode' .planning/GSS_STATE.json)
  [ "$mode" = "existing_project" ] || fail "Expected project_mode preserved, got '$mode'"
)

(
  cd "$tmpdir"
  fakebin="$tmpdir/fakebin"
  mkdir -p "$fakebin"
  for cmd in cp date grep mkdir mktemp mv sed; do
    ln -s "$(command -v "$cmd")" "$fakebin/$cmd"
  done
  PATH="$fakebin" "$BASH" "$SCRIPT" "GSTACK_DOCS"
  val=$(jq -r '.devex_surface' .planning/GSS_STATE.json)
  [ "$val" = "false" ] || fail "Expected fallback path to preserve devex_surface=false, got '$val'"
  rationale=$(jq -r '.devex_rationale' .planning/GSS_STATE.json)
  [ "$rationale" = "Project exposes a REST API and CLI" ] || fail "Expected fallback path to preserve devex_rationale, got '$rationale'"
  mode=$(jq -r '.project_mode' .planning/GSS_STATE.json)
  [ "$mode" = "existing_project" ] || fail "Expected fallback path to preserve project_mode, got '$mode'"
)

echo "update_state devex contract ok"
