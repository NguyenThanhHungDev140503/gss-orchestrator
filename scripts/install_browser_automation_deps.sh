#!/usr/bin/env bash
# install_browser_automation_deps.sh
# Install Playwright + Stagehand and scaffold custom-provider config.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Checking browser automation dependencies..."

if [ ! -f "package.json" ]; then
  echo -e "  ${YELLOW}⚠${NC} package.json not found — skipped Playwright/Stagehand install"
  echo "     Run inside a Node.js project, or create package.json first."
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo -e "  ${RED}✗${NC} node not found — cannot install Playwright/Stagehand"
  exit 1
fi

copy_template() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [ -f "$dest" ]; then
    echo -e "  ${YELLOW}↺${NC} $label exists — skipped"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo -e "  ${GREEN}✓${NC} $label → $dest"
}

has_installed_package() {
  local pkg="$1"
  node -e '
    try {
      require.resolve(process.argv[1]);
      process.exit(0);
    } catch {
      process.exit(1);
    }
  ' "$pkg"
}

PM=""
INSTALL_CMD=""
PLAYWRIGHT_CMD=""

if [ -f "pnpm-lock.yaml" ] && command -v pnpm >/dev/null 2>&1; then
  PM="pnpm"
  INSTALL_CMD="pnpm add -D playwright @playwright/test @browserbasehq/stagehand"
  PLAYWRIGHT_CMD="pnpm exec playwright install"
elif [ -f "yarn.lock" ] && command -v yarn >/dev/null 2>&1; then
  PM="yarn"
  INSTALL_CMD="yarn add -D playwright @playwright/test @browserbasehq/stagehand"
  PLAYWRIGHT_CMD="yarn playwright install"
elif [ -f "bun.lockb" ] && command -v bun >/dev/null 2>&1; then
  PM="bun"
  INSTALL_CMD="bun add -d playwright @playwright/test @browserbasehq/stagehand"
  PLAYWRIGHT_CMD="bunx playwright install"
elif [ -f "package-lock.json" ] && command -v npm >/dev/null 2>&1; then
  PM="npm"
  INSTALL_CMD="npm install --save-dev playwright @playwright/test @browserbasehq/stagehand"
  PLAYWRIGHT_CMD="npx playwright install"
elif command -v pnpm >/dev/null 2>&1; then
  PM="pnpm"
  INSTALL_CMD="pnpm add -D playwright @playwright/test @browserbasehq/stagehand"
  PLAYWRIGHT_CMD="pnpm exec playwright install"
elif command -v npm >/dev/null 2>&1; then
  PM="npm"
  INSTALL_CMD="npm install --save-dev playwright @playwright/test @browserbasehq/stagehand"
  PLAYWRIGHT_CMD="npx playwright install"
else
  echo -e "  ${RED}✗${NC} No supported package manager found (pnpm/npm/yarn/bun)"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} package manager: $PM"

MISSING_PACKAGES=()
has_installed_package "playwright" || MISSING_PACKAGES+=("playwright")
has_installed_package "@playwright/test" || MISSING_PACKAGES+=("@playwright/test")
has_installed_package "@browserbasehq/stagehand" || MISSING_PACKAGES+=("@browserbasehq/stagehand")

if [ "${GSS_BROWSER_AUTOMATION_SKIP_INSTALL:-0}" = "1" ]; then
  echo -e "  ${YELLOW}↺${NC} Package install skipped by GSS_BROWSER_AUTOMATION_SKIP_INSTALL=1"
elif [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
  echo -e "  ${GREEN}✓${NC} Playwright + Stagehand packages already installed"
else
  echo -e "  ${DIM}$INSTALL_CMD${NC}"
  if $INSTALL_CMD; then
    echo -e "  ${GREEN}✓${NC} Playwright + Stagehand packages installed"
  else
    echo -e "  ${RED}✗${NC} Package install failed"
    exit 1
  fi
fi

if [ "${GSS_BROWSER_AUTOMATION_SKIP_INSTALL:-0}" = "1" ]; then
  echo -e "  ${YELLOW}↺${NC} Playwright browser install skipped by GSS_BROWSER_AUTOMATION_SKIP_INSTALL=1"
else
  echo -e "  ${DIM}$PLAYWRIGHT_CMD${NC}"
  if $PLAYWRIGHT_CMD; then
    echo -e "  ${GREEN}✓${NC} Playwright browser binaries installed"
  else
    echo -e "  ${YELLOW}⚠${NC} Playwright browser install failed"
    echo "     Retry manually: $PLAYWRIGHT_CMD"
  fi
fi

echo ""
echo "Scaffolding Stagehand custom provider config..."

copy_template \
  "$SKILL_DIR/references/env.stagehand.example.template" \
  ".env.stagehand.example" \
  ".env.stagehand.example"

copy_template \
  "$SKILL_DIR/references/stagehand.config.ts.template" \
  "stagehand.config.ts" \
  "stagehand.config.ts"

copy_template \
  "$SKILL_DIR/references/stagehand.example.spec.ts.template" \
  "tests/stagehand/example.spec.ts" \
  "tests/stagehand/example.spec.ts"

echo "  Stagehand provider env: STAGEHAND_MODEL_NAME, STAGEHAND_API_KEY, STAGEHAND_BASE_URL"
