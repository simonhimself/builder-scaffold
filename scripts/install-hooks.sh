#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="/home/simon/.openclaw/workspace-builder"
PROJECTS_ROOT="$WORKSPACE_ROOT/projects"
CHECK_SCRIPT="$WORKSPACE_ROOT/scripts/enforce-task-consistency.sh"

install_hook() {
  local repo_path="$1"
  local hook_path="$repo_path/.git/hooks/pre-push"

  if [ ! -d "$repo_path/.git" ]; then
    echo "skip: $repo_path (no .git)"
    return
  fi

  cat > "$hook_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CHECK_SCRIPT="/home/simon/.openclaw/workspace-builder/scripts/enforce-task-consistency.sh"

if [ -x "$CHECK_SCRIPT" ]; then
  "$CHECK_SCRIPT" "$REPO_ROOT" >/dev/null
else
  echo "[warn] consistency script not executable: $CHECK_SCRIPT" >&2
fi
EOF

  chmod +x "$hook_path"
  echo "installed: $hook_path"
}

if [ ! -x "$CHECK_SCRIPT" ]; then
  echo "error: missing executable $CHECK_SCRIPT" >&2
  exit 1
fi

if [ "${1:-}" = "--all" ] || [ "$#" -eq 0 ]; then
  while IFS= read -r repo; do
    install_hook "$repo"
  done < <(find "$PROJECTS_ROOT" -mindepth 1 -maxdepth 2 -type d -name .git -print | sed 's#/.git$##')
else
  install_hook "$1"
fi
