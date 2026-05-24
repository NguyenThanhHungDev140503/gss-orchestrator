#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    echo "Expected '$file' to contain: $pattern" >&2
    exit 1
  fi
}

assert_not_exists() {
  local path="$1"
  if [ -e "$path" ]; then
    echo "Expected '$path' to not exist" >&2
    exit 1
  fi
}

assert_file_exists() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Expected file to exist: $path" >&2
    exit 1
  fi
}

SCRIPT="$ROOT/scripts/install_browser_automation_deps.sh"
SETUP="$ROOT/scripts/setup.sh"

assert_file_exists "$SCRIPT"
assert_contains "$SCRIPT" "STAGEHAND_MODEL_NAME"
assert_contains "$SCRIPT" "STAGEHAND_API_KEY"
assert_contains "$SCRIPT" "STAGEHAND_BASE_URL"
assert_contains "$SCRIPT" "stagehand.config.ts"
assert_contains "$SCRIPT" "tests/stagehand/example.spec.ts"
assert_contains "$SETUP" "install_browser_automation_deps.sh"
assert_not_exists "$ROOT/references/stagehand-custom-provider.md"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/package.json" <<'JSON'
{
  "name": "stagehand-contract-fixture",
  "private": true,
  "devDependencies": {}
}
JSON

(
  cd "$tmpdir"
  GSS_BROWSER_AUTOMATION_SKIP_INSTALL=1 bash "$SCRIPT" >/dev/null
)

assert_file_exists "$tmpdir/.env.stagehand.example"
assert_file_exists "$tmpdir/stagehand.config.ts"
assert_file_exists "$tmpdir/tests/stagehand/example.spec.ts"

assert_contains "$tmpdir/.env.stagehand.example" "STAGEHAND_MODEL_NAME=openai/gpt-4o-mini"
assert_contains "$tmpdir/.env.stagehand.example" "STAGEHAND_API_KEY="
assert_contains "$tmpdir/.env.stagehand.example" "STAGEHAND_BASE_URL=https://your-openai-compatible-provider.example.com/v1"
assert_contains "$tmpdir/stagehand.config.ts" "modelName: process.env.STAGEHAND_MODEL_NAME ?? \"openai/gpt-4o-mini\""
assert_contains "$tmpdir/stagehand.config.ts" "apiKey: process.env.STAGEHAND_API_KEY"
assert_contains "$tmpdir/stagehand.config.ts" "baseURL: process.env.STAGEHAND_BASE_URL"
assert_contains "$tmpdir/tests/stagehand/example.spec.ts" "createStagehand"

echo "browser automation contract ok"
