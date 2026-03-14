#!/usr/bin/env bash
# verify.sh — runs project CI checks after ACP task completes
# Usage: verify.sh <project-path> [verify-command]
# Output: JSON {passed: bool, summary: string, output: string}
# Exit code: 0 if passed, 1 if failed

set -uo pipefail

PROJECT_PATH="${1:?project-path required}"
CUSTOM_CMD="${2:-}"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "{\"passed\":false,\"summary\":\"Project path not found: $PROJECT_PATH\",\"output\":\"\"}"
  exit 1
fi

cd "$PROJECT_PATH"

detect_package_manager() {
  local package_manager=""

  if [ -f "package.json" ]; then
    package_manager=$(jq -r '.packageManager // empty' package.json 2>/dev/null || true)
    package_manager="${package_manager%%@*}"
    case "$package_manager" in
      pnpm|yarn|npm|bun)
        echo "$package_manager"
        return
        ;;
    esac
  fi

  if [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
    return
  fi
  if [ -f "yarn.lock" ]; then
    echo "yarn"
    return
  fi
  if [ -f "package-lock.json" ] || [ -f "npm-shrinkwrap.json" ]; then
    echo "npm"
    return
  fi

  if command -v pnpm >/dev/null 2>&1; then
    echo "pnpm"
    return
  fi
  if command -v yarn >/dev/null 2>&1; then
    echo "yarn"
    return
  fi
  if command -v npm >/dev/null 2>&1; then
    echo "npm"
    return
  fi
  if command -v bun >/dev/null 2>&1; then
    echo "bun"
    return
  fi

  echo "npm"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

first_available_js_manager() {
  local pm
  for pm in npm pnpm yarn bun; do
    if command_exists "$pm"; then
      echo "$pm"
      return
    fi
  done
  echo ""
}

resolve_package_manager() {
  local detected="$1"

  if command_exists "$detected"; then
    PACKAGE_MANAGER="$detected"
    PACKAGE_MANAGER_WARNING=""
    return
  fi

  local fallback
  fallback="$(first_available_js_manager)"
  if [ -n "$fallback" ]; then
    PACKAGE_MANAGER="$fallback"
    PACKAGE_MANAGER_WARNING="Detected package manager '$detected' but binary is unavailable; using '$fallback'"
    return
  fi

  PACKAGE_MANAGER="$detected"
  PACKAGE_MANAGER_WARNING="Detected package manager '$detected' but no JS package manager binaries are available"
}

js_verify_command() {
  local package_manager="$1"
  local has_type_check="$2"

  case "$package_manager" in
    pnpm)
      if [ "$has_type_check" = "true" ]; then
        echo "pnpm run type-check && pnpm test -- --passWithNoTests"
      else
        echo "pnpm test -- --passWithNoTests"
      fi
      ;;
    yarn)
      if [ "$has_type_check" = "true" ]; then
        echo "yarn run type-check && yarn test"
      else
        echo "yarn test"
      fi
      ;;
    bun)
      if [ "$has_type_check" = "true" ]; then
        echo "bun run type-check && bun test"
      else
        echo "bun test"
      fi
      ;;
    npm|*)
      if [ "$has_type_check" = "true" ]; then
        echo "npm run type-check && npm test -- -- --passWithNoTests"
      else
        echo "npm test -- -- --passWithNoTests"
      fi
      ;;
  esac
}

# Determine verify command:
# 1. Use custom command if provided
# 2. Look for SPEC.md verify command
# 3. Detect project type and use defaults
if [ -n "$CUSTOM_CMD" ]; then
  CMD="$CUSTOM_CMD"
elif [ -f "SPEC.md" ] && grep -q "verify-command:" SPEC.md 2>/dev/null; then
  CMD=$(grep "verify-command:" SPEC.md | head -1 | sed "s/verify-command://" | xargs)
elif [ -f "package.json" ]; then
  # JavaScript/TypeScript project — detect package manager and run standard checks
  DETECTED_PACKAGE_MANAGER="$(detect_package_manager)"
  resolve_package_manager "$DETECTED_PACKAGE_MANAGER"
  if jq -e '.scripts["type-check"]' package.json > /dev/null 2>&1; then
    CMD="$(js_verify_command "$PACKAGE_MANAGER" true)"
  else
    CMD="$(js_verify_command "$PACKAGE_MANAGER" false)"
  fi
elif [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  CMD="python3 -m pytest --tb=short -q"
elif [ -f "Makefile" ] && grep -q "^test:" Makefile; then
  CMD="make test"
else
  # No test framework detected — just check for uncommitted changes as a sanity check
  CMD="git diff --exit-code HEAD"
fi

# Run the command, capture output
OUTPUT=$(eval "$CMD" 2>&1)
EXIT_CODE=$?

if [ -n "${PACKAGE_MANAGER_WARNING:-}" ]; then
  OUTPUT="[verify warning] $PACKAGE_MANAGER_WARNING
$OUTPUT"
fi

# Escape output for JSON
OUTPUT_ESCAPED=$(echo "$OUTPUT" | tail -50 | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read()))
" 2>/dev/null || echo "\"[output capture failed]\"")

PACKAGE_MANAGER_WARNING_ESCAPED=$(printf '%s' "${PACKAGE_MANAGER_WARNING:-}" | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read()))
" 2>/dev/null || echo "\"\"")

if [ "$EXIT_CODE" -eq 0 ]; then
  PASSED=true
  SUMMARY="✅ Verification passed"
else
  PASSED=false
  SUMMARY="❌ Verification failed (exit $EXIT_CODE)"
fi

echo "{\"passed\":$PASSED,\"summary\":\"$SUMMARY\",\"exitCode\":$EXIT_CODE,\"command\":\"$CMD\",\"packageManager\":\"${PACKAGE_MANAGER:-}\",\"managerWarning\":$PACKAGE_MANAGER_WARNING_ESCAPED,\"output\":$OUTPUT_ESCAPED}"
exit $EXIT_CODE
