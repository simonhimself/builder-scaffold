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

# Determine verify command:
# 1. Use custom command if provided
# 2. Look for SPEC.md verify command
# 3. Detect project type and use defaults
if [ -n "$CUSTOM_CMD" ]; then
  CMD="$CUSTOM_CMD"
elif [ -f "SPEC.md" ] && grep -q "verify-command:" SPEC.md 2>/dev/null; then
  CMD=$(grep "verify-command:" SPEC.md | head -1 | sed 's/verify-command://' | xargs)
elif [ -f "package.json" ]; then
  # Node project — run type check + tests
  if jq -e '.scripts["type-check"]' package.json > /dev/null 2>&1; then
    CMD="npm run type-check && npm test -- -- --passWithNoTests"
  else
    CMD="npm test -- -- --passWithNoTests"
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

# Escape output for JSON
OUTPUT_ESCAPED=$(echo "$OUTPUT" | tail -50 | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read()))
" 2>/dev/null || echo "\"[output capture failed]\"")

if [ "$EXIT_CODE" -eq 0 ]; then
  PASSED=true
  SUMMARY="✅ Verification passed"
else
  PASSED=false
  SUMMARY="❌ Verification failed (exit $EXIT_CODE)"
fi

echo "{\"passed\":$PASSED,\"summary\":\"$SUMMARY\",\"exitCode\":$EXIT_CODE,\"command\":\"$CMD\",\"output\":$OUTPUT_ESCAPED}"
exit $EXIT_CODE
