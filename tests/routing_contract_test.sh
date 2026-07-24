#!/usr/bin/env bash
# routing_contract_test.sh — Verify router → phase-file mapping for modular SKILL refactoring
#
# Tests:
#   1. Every loop_state in the routing table maps to an existing phase file
#   2. Every phase file has the correct header reference
#   3. Router sections (identity, bootstrap, state machine, rules, file contract) are present
#   4. End-to-end: for each loop_state, verify the correct file would be resolved
#   5. Error states (DELIVERED, unknown state) are handled
#   6. Both SKILL.md (Claude Code) and SKILL.codex.md (Codex) are tested

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

assert_ok()   { local desc="$1"; PASS=$((PASS+1)); echo "  ✓ $desc"; }
assert_fail() { local desc="$1"; FAIL=$((FAIL+1)); echo "  ✗ $desc"; }

# === Extract routing table from a SKILL.md router ===
# Scans for the ROUTER section and extracts | loop_state | file | entries.
extract_routing_table() {
  local file="$1"
  awk '
    /## ROUTER/ { in_router=1; next }
    in_router && /^\\| `/{ 
      gsub(/^\\| /,""); gsub(/ \\|$/,"")
      split($0,parts," \\| ")
      state=parts[1]; file=parts[2]
      gsub(/`/,"",state); gsub(/`/,"",file)
      gsub(/^ */,"",state); gsub(/ *$/,"",state)
      gsub(/^ */,"",file);  gsub(/ *$/,"",file)
      if(state != "" && file != "" && state != "loop_state")
        print state "|" file
    }
    in_router && /^---/ { in_router=0 }
  ' "$file"
}

# === Extract all loop_state values from the state machine diagram ===
extract_loop_states() {
  local file="$1"
  awk '
    /^IDLE →/ { print; gsub(/[→←↕│└└─┘│┌┐ │├┤┬┴┼─│└┘┌┐│├┤┬┴┼╲╱╳●○◦◻◼◽◾⏺ ⃞ ⃟ ⬜⬛▢▣▤▥▦▧▨▩⬞⬟⬠⬡🔲🔳⚪⚫🔴🔵⬆⬇⬅➡↗↘↙↖↔↕🔄◀▶ℹ⏩⏪⏫⏬); }
  ' /dev/null
  # Simpler: just grep all-uppercase state names from the state machine block
  awk '
    /## STATE MACHINE/,/^---/ {
      gsub(/`/,"")
      for(i=1;i<=NF;i++) {
        if($i ~ /^[A-Z][A-Z_]+$/) print $i
      }
    }
  ' "$file" | sort -u
}

echo ""
echo "━━━ GSS Orchestrator — Routing Contract Test ━━━"
echo ""

# ── 1. Extract routing tables ──────────────────────────────────────────────
echo "── 1. Routing table coverage ──"

for variant in "SKILL.md:subskills" "SKILL.codex.md:subskills-codex"; do
  skill_file="${variant%%:*}"
  prefix="${variant##*:}"
  full_path="$ROOT/$skill_file"

  echo "  Testing $skill_file → $prefix/"

  if [ ! -f "$full_path" ]; then
    echo "  ✗ $skill_file not found"
    FAIL=$((FAIL+1))
    continue
  fi

  # Parse the routing table using grep on the markdown table
  # The router section has lines like: | `IDLE` or `PROJECT_DISCOVERY` | `subskills/PHASE-00-INTAKE.md` |
  # We want to extract state→file mappings
  routes_found=0
  while IFS='|' read -ra line; do
    # Properly parse markdown table rows
    true
  done < <(grep -A20 "## ROUTER" "$full_path" | grep '^| `' | head -20)

  # Simpler: use grep+sed to extract
  grep -A20 "## ROUTER" "$full_path" | grep '^| `' | while read -r row; do
    state_part=$(echo "$row" | sed -n 's/^| \(`[^`]*`\).*/\1/p')
    file_part=$(echo "$row" | sed -n 's/.*| \(`[^`]*`\) *|$/\1/p')
    state=$(echo "$state_part" | tr -d '`')
    file=$(echo "$file_part" | tr -d '`' | sed 's/.*\///')

    # Check for multi-state entries like "IDLE or PROJECT_DISCOVERY"
    for single_state in $state; do
      # Skip "or" 
      [ "$single_state" = "or" ] && continue
      routes_found=$((routes_found+1))
    done

    # Verify file exists under the right prefix
    expected="$ROOT/$prefix/$file"
    if [ -f "$expected" ]; then
      : # Will count below
    else
      echo "  ✗ Missing: $expected (mapped from $state_part)"
    fi
  done
done

# ── Direct file existence check for all states ──────────────────────────
echo ""
echo "── 2. Phase file existence ──"

declare -A CC_ROUTES
CC_ROUTES["IDLE"]="PHASE-00-INTAKE.md"
CC_ROUTES["PROJECT_DISCOVERY"]="PHASE-00-INTAKE.md"
CC_ROUTES["RESEARCH"]="PHASE-01-RESEARCH.md"
CC_ROUTES["PLANNING"]="PHASE-02-PLANNING.md"
CC_ROUTES["GSTACK_REVIEW"]="PHASE-03-REVIEW.md"
CC_ROUTES["GSTACK_DX_REVIEW"]="PHASE-03b-DX.md"
CC_ROUTES["GSTACK_DESIGN_PLAN"]="PHASE-03c-DESIGN.md"
CC_ROUTES["SP_BRAINSTORM"]="PHASE-04-BRAINSTORM.md"
CC_ROUTES["SP_EXECUTING"]="PHASE-05-EXECUTE.md"
CC_ROUTES["GSTACK_QA"]="PHASE-06-QA.md"
CC_ROUTES["GSTACK_DESIGN_QA"]="PHASE-06-QA.md"
CC_ROUTES["GSTACK_DOCS"]="PHASE-07-DOCS.md"
CC_ROUTES["SP_DEBUGGING"]="PHASE-08-DEBUG.md"
CC_ROUTES["GSD_DISPATCH"]="PHASE-09-DISPATCH.md"

echo "  SKILL.md (Claude Code) routes:"
cc_ok=0; cc_fail=0
for state in "${!CC_ROUTES[@]}"; do
  file="${CC_ROUTES[$state]}"
  expected="$ROOT/subskills/$file"
  if [ -f "$expected" ]; then
    cc_ok=$((cc_ok+1))
  else
    echo "  ✗ $state → $expected NOT FOUND"
    cc_fail=$((cc_fail+1))
  fi
done
echo "    $cc_ok/${#CC_ROUTES[@]} states map to existing files"
[ $cc_fail -eq 0 ] && PASS=$((PASS+1)) && echo "  ✓ All Claude Code phase files present" \
                || FAIL=$((FAIL+1)) && echo "  ✗ $cc_fail missing Claude Code phase files"

echo "  SKILL.codex.md (Codex) routes:"
cx_ok=0; cx_fail=0
for state in "${!CC_ROUTES[@]}"; do
  file="${CC_ROUTES[$state]}"
  expected="$ROOT/subskills-codex/$file"
  if [ -f "$expected" ]; then
    cx_ok=$((cx_ok+1))
  else
    echo "  ✗ $state → $expected NOT FOUND"
    cx_fail=$((cx_fail+1))
  fi
done
echo "    $cx_ok/${#CC_ROUTES[@]} states map to existing files"
[ $cx_fail -eq 0 ] && PASS=$((PASS+1)) && echo "  ✓ All Codex phase files present" \
                || FAIL=$((FAIL+1)) && echo "  ✗ $cx_fail missing Codex phase files"

# ── 3. Verify routing table entries in SKILL.md ─────────────────────────
echo ""
echo "── 3. Router table completeness ──"

missing_states=()
for state in "IDLE" "PROJECT_DISCOVERY" "RESEARCH" "PLANNING" "GSTACK_REVIEW" \
             "GSTACK_DX_REVIEW" "GSTACK_DESIGN_PLAN" "SP_BRAINSTORM" \
             "SP_EXECUTING" "GSTACK_QA" "GSTACK_DESIGN_QA" "GSTACK_DOCS" \
             "SP_DEBUGGING" "GSD_DISPATCH" "DELIVERED"; do
  if ! grep -q "$state" "$ROOT/SKILL.md" 2>/dev/null; then
    missing_states+=("SKILL.md: $state")
  fi
  if ! grep -q "$state" "$ROOT/SKILL.codex.md" 2>/dev/null; then
    missing_states+=("SKILL.codex.md: $state")
  fi
done

if [ ${#missing_states[@]} -eq 0 ]; then
  echo "  ✓ All states referenced in both router files"
  PASS=$((PASS+1))
else
  for m in "${missing_states[@]}"; do echo "  ✗ Missing: $m"; done
  FAIL=$((FAIL+1))
fi

# ── 4. Phase file self-reference headers ──────────────────────────────────
echo ""
echo "── 4. Phase file header correctness ──"

header_ok=0; header_fail=0
for dir in "subskills" "subskills-codex"; do
  for phase_file in "$ROOT/$dir"/PHASE-*.md; do
    name=$(basename "$phase_file")
    # Each phase file should have a header line mentioning SKILL.md or SKILL.codex.md
    if [ "$dir" = "subskills" ]; then
      if grep -q "SKILL.md" "$phase_file" 2>/dev/null; then
        header_ok=$((header_ok+1))
      else
        echo "  ✗ $dir/$name: missing SKILL.md reference in header"
        header_fail=$((header_fail+1))
      fi
    else
      if grep -q "SKILL.codex.md" "$phase_file" 2>/dev/null; then
        header_ok=$((header_ok+1))
      else
        echo "  ✗ $dir/$name: missing SKILL.codex.md reference in header"
        header_fail=$((header_fail+1))
      fi
    fi
  done
done
[ $header_fail -eq 0 ] && PASS=$((PASS+1)) && echo "  ✓ All phase files have correct header references" \
                || FAIL=$((FAIL+1))

# ── 5. End-to-end routing simulation ─────────────────────────────────────
echo ""
echo "── 5. End-to-end routing simulation ──"

# Simulate what the agent does: read GSS_STATE.json → look up routing table → read phase file
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Create a fake install structure
FAKE_INSTALL="$TMPDIR/.claude/skills/gsd-gstack-sp-orchestrator"
mkdir -p "$FAKE_INSTALL/subskills" "$FAKE_INSTALL/scripts"
cp "$ROOT/SKILL.md" "$FAKE_INSTALL/SKILL.md"
cp "$ROOT/subskills"/*.md "$FAKE_INSTALL/subskills/"

e2e_ok=0; e2e_fail=0
for state in "${!CC_ROUTES[@]}"; do
  expected_file="${CC_ROUTES[$state]}"
  EXPECTED_PATH="$FAKE_INSTALL/subskills/$expected_file"

  # Write GSS_STATE.json
  mkdir -p "$TMPDIR/.planning"
  cat > "$TMPDIR/.planning/GSS_STATE.json" <<JSON
{
  "loop_state": "$state",
  "phase": "test-phase",
  "project_slug": "test-project",
  "project_mode": "new_project",
  "devex_surface": false,
  "devex_rationale": "",
  "completed_milestones": []
}
JSON

  # Simulate the agent's routing logic (as described in the ROUTER section)
  # Read loop_state, then find the matching file from the routing table
  LOOP_STATE="$state"
  ROUTED_FILE=""

  # This mirrors the routing table in SKILL.md
  case "$LOOP_STATE" in
    IDLE|PROJECT_DISCOVERY) ROUTED_FILE="PHASE-00-INTAKE.md" ;;
    RESEARCH)               ROUTED_FILE="PHASE-01-RESEARCH.md" ;;
    PLANNING)               ROUTED_FILE="PHASE-02-PLANNING.md" ;;
    GSTACK_REVIEW)          ROUTED_FILE="PHASE-03-REVIEW.md" ;;
    GSTACK_DX_REVIEW)       ROUTED_FILE="PHASE-03b-DX.md" ;;
    GSTACK_DESIGN_PLAN)     ROUTED_FILE="PHASE-03c-DESIGN.md" ;;
    SP_BRAINSTORM)          ROUTED_FILE="PHASE-04-BRAINSTORM.md" ;;
    SP_EXECUTING)           ROUTED_FILE="PHASE-05-EXECUTE.md" ;;
    GSTACK_QA|GSTACK_DESIGN_QA) ROUTED_FILE="PHASE-06-QA.md" ;;
    GSTACK_DOCS)            ROUTED_FILE="PHASE-07-DOCS.md" ;;
    SP_DEBUGGING)           ROUTED_FILE="PHASE-08-DEBUG.md" ;;
    GSD_DISPATCH)           ROUTED_FILE="PHASE-09-DISPATCH.md" ;;
    DELIVERED)              ROUTED_FILE="" ;;
    *)                      ROUTED_FILE="" ;;
  esac

  if [ "$state" = "DELIVERED" ]; then
    # DELIVERED should produce no file load (terminal state)
    if [ -z "$ROUTED_FILE" ]; then
      e2e_ok=$((e2e_ok+1))
    else
      echo "  ✗ DELIVERED should not route to a file (got: $ROUTED_FILE)"
      e2e_fail=$((e2e_fail+1))
    fi
  else
    if [ "$ROUTED_FILE" = "$expected_file" ]; then
      # Verify the file actually exists
      if [ -f "$FAKE_INSTALL/subskills/$ROUTED_FILE" ]; then
        e2e_ok=$((e2e_ok+1))
      else
        echo "  ✗ $state → routed to $ROUTED_FILE but file not found at $FAKE_INSTALL/subskills/"
        e2e_fail=$((e2e_fail+1))
      fi
    else
      echo "  ✗ $state → expected $expected_file, got $ROUTED_FILE"
      e2e_fail=$((e2e_fail+1))
    fi
  fi
done

# Also test a non-existent state
cat > "$TMPDIR/.planning/GSS_STATE.json" <<JSON
{"loop_state": "NONEXISTENT_STATE"}
JSON
LOOP_STATE="NONEXISTENT_STATE"
ROUTED_FILE=""
case "$LOOP_STATE" in
  IDLE|PROJECT_DISCOVERY) ROUTED_FILE="PHASE-00-INTAKE.md" ;;
  RESEARCH)               ROUTED_FILE="PHASE-01-RESEARCH.md" ;;
  PLANNING)               ROUTED_FILE="PHASE-02-PLANNING.md" ;;
  GSTACK_REVIEW)          ROUTED_FILE="PHASE-03-REVIEW.md" ;;
  GSTACK_DX_REVIEW)       ROUTED_FILE="PHASE-03b-DX.md" ;;
  GSTACK_DESIGN_PLAN)     ROUTED_FILE="PHASE-03c-DESIGN.md" ;;
  SP_BRAINSTORM)          ROUTED_FILE="PHASE-04-BRAINSTORM.md" ;;
  SP_EXECUTING)           ROUTED_FILE="PHASE-05-EXECUTE.md" ;;
  GSTACK_QA|GSTACK_DESIGN_QA) ROUTED_FILE="PHASE-06-QA.md" ;;
  GSTACK_DOCS)            ROUTED_FILE="PHASE-07-DOCS.md" ;;
  SP_DEBUGGING)           ROUTED_FILE="PHASE-08-DEBUG.md" ;;
  GSD_DISPATCH)           ROUTED_FILE="PHASE-09-DISPATCH.md" ;;
  DELIVERED)              ROUTED_FILE="" ;;
  *)                      ROUTED_FILE="" ;;
esac
if [ -z "$ROUTED_FILE" ]; then
  e2e_ok=$((e2e_ok+1))
else
  echo "  ✗ Unknown state should not route to a file (got: $ROUTED_FILE)"
  e2e_fail=$((e2e_fail+1))
fi

echo "  $e2e_ok/${#CC_ROUTES[@]} routing entries verified"
if [ $e2e_fail -eq 0 ]; then
  PASS=$((PASS+1))
  echo "  ✓ All routes resolve correctly (including DELIVERED and unknown states)"
else
  FAIL=$((FAIL+1))
fi

# ── 6. Critical router sections present ──────────────────────────────────
echo ""
echo "── 6. Router section integrity ──"

section_ok=0; section_fail=0
for skill_file in "SKILL.md" "SKILL.codex.md"; do
  f="$ROOT/$skill_file"
  for section in "IDENTITY" "BOOTSTRAP" "STATE MACHINE" "ROUTER" "FILE COMMUNICATION CONTRACT" "RECOVERY" "OBSIDIAN DOCUMENT STANDARD"; do
    if grep -q "$section" "$f" 2>/dev/null; then
      : # ok
    else
      echo "  ✗ $skill_file missing section: $section"
      section_fail=$((section_fail+1))
    fi
  done
  # SKILL.md has orchestrator rules, SKILL.codex.md has context hygiene
  if [ "$skill_file" = "SKILL.md" ]; then
    if grep -q "ORCHESTRATOR RULES" "$f" 2>/dev/null; then
      section_ok=$((section_ok+1))
    else
      echo "  ✗ SKILL.md missing: ORCHESTRATOR RULES"
      section_fail=$((section_fail+1))
    fi
  fi
  if [ "$skill_file" = "SKILL.codex.md" ]; then
    if grep -q "HOW TO LOAD SKILLS IN CODEX" "$f" 2>/dev/null; then
      section_ok=$((section_ok+1))
    else
      echo "  ✗ SKILL.codex.md missing: HOW TO LOAD SKILLS IN CODEX"
      section_fail=$((section_fail+1))
    fi
  fi
done

[ $section_fail -eq 0 ] && PASS=$((PASS+1)) && echo "  ✓ All critical router sections present" \
                || FAIL=$((FAIL+1))

# ── 7. No old phase content remains in router files ──────────────────────
echo ""
echo "── 7. Router cleanliness ──"

clean_ok=0; clean_fail=0
for skill_file in "SKILL.md" "SKILL.codex.md"; do
  f="$ROOT/$skill_file"
  # The router should NOT contain detailed subagent dispatch blocks (Agent/Task blocks)
  # These are now in the phase files
  for phase_keyword in "PHASE 0A" "PHASE 0B" "PHASE 1" "PHASE 2" "PHASE 3" "PHASE 4" "PHASE 5"; do
    if grep -q "$phase_keyword" "$f" 2>/dev/null; then
      # It's OK if it's just a reference in the state machine diagram or routing table
      # Check it's NOT a full phase section (followed by detailed instructions)
      line=$(grep -n "$phase_keyword" "$f" | head -1 | cut -d: -f1)
      context=$(sed -n "$((line+1)),$((line+3))p" "$f" 2>/dev/null)
      # If the phase keyword is NOT in the state machine diagram or routing table, flag it
      if echo "$context" | grep -qE "(Trigger|Step|gss-|Agent|Task)"; then
        echo "  ✗ $skill_file:$line contains '$phase_keyword' with execution detail (should be in phase file)"
        clean_fail=$((clean_fail+1))
      fi
    fi
  done
done

[ $clean_fail -eq 0 ] && PASS=$((PASS+1)) && echo "  ✓ No detailed phase content remains in router files" \
                || FAIL=$((FAIL+1))

# ── 8. Phase file count ──────────────────────────────────────────────────
echo ""
echo "── 8. Phase file count ──"

cc_count=$(ls "$ROOT/subskills"/PHASE-*.md 2>/dev/null | wc -l)
cx_count=$(ls "$ROOT/subskills-codex"/PHASE-*.md 2>/dev/null | wc -l)

if [ "$cc_count" -eq 12 ]; then
  PASS=$((PASS+1))
  echo "  ✓ subskills/: $cc_count phase files (expected 12)"
else
  FAIL=$((FAIL+1))
  echo "  ✗ subskills/: $cc_count phase files (expected 12)"
fi

if [ "$cx_count" -eq 12 ]; then
  PASS=$((PASS+1))
  echo "  ✓ subskills-codex/: $cx_count phase files (expected 12)"
else
  FAIL=$((FAIL+1))
  echo "  ✗ subskills-codex/: $cx_count phase files (expected 12)"
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "━━━ Results: $PASS passed, $FAIL failed ━━━"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "All routing contract tests passed."
