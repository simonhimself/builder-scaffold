#!/usr/bin/env bash
set -euo pipefail

SRC_ROOT="/home/simon/.openclaw/workspace-builder"
DEST_ROOT="/home/simon/repos/builder-scaffold"
DRY_RUN=0
DO_COMMIT=0
DO_PUSH=0
COMMIT_MSG="chore(scaffold): sync curated files from workspace-builder"

usage() {
  cat <<USAGE
Usage: export-scaffold.sh [options]

Sync curated scaffold files from workspace-builder to builder-scaffold.

Options:
  --src <path>        Source workspace root (default: /home/simon/.openclaw/workspace-builder)
  --dest <path>       Destination scaffold repo (default: /home/simon/repos/builder-scaffold)
  --dry-run           Show actions without writing files
  --commit            Commit changes in destination repo if dirty
  --push              Push commit to origin (requires --commit)
  --message <msg>     Commit message (used with --commit)
  -h, --help          Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --src)
      SRC_ROOT="$2"
      shift 2
      ;;
    --dest)
      DEST_ROOT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --commit)
      DO_COMMIT=1
      shift
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --message)
      COMMIT_MSG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$DO_PUSH" -eq 1 ] && [ "$DO_COMMIT" -ne 1 ]; then
  echo "ERROR: --push requires --commit" >&2
  exit 1
fi

[ -d "$SRC_ROOT" ] || { echo "ERROR: source root missing: $SRC_ROOT" >&2; exit 1; }
[ -d "$DEST_ROOT" ] || { echo "ERROR: destination root missing: $DEST_ROOT" >&2; exit 1; }
[ -d "$DEST_ROOT/.git" ] || { echo "ERROR: destination is not a git repo: $DEST_ROOT" >&2; exit 1; }

RSYNC_FLAGS=("-a" "--delete" "--exclude" ".DS_Store" "--exclude" "._*")
if [ "$DRY_RUN" -eq 1 ]; then
  RSYNC_FLAGS+=("--dry-run" "--itemize-changes")
fi

copy_root_doc() {
  local name="$1"
  local src="$SRC_ROOT/$name"
  local dest="$DEST_ROOT/$name"

  if [ ! -f "$src" ]; then
    if [ -f "$dest" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN remove $dest (missing in source)"
      else
        rm -f "$dest"
      fi
    fi
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN copy $src -> $dest"
  else
    cp -f "$src" "$dest"
  fi
}

mkdir -p "$DEST_ROOT/documentation" "$DEST_ROOT/scripts" "$DEST_ROOT/projects/_templates" "$DEST_ROOT/state/schemas" "$DEST_ROOT/state/fixtures"

copy_root_doc "AGENTS.md"
copy_root_doc "HEARTBEAT.md"
copy_root_doc "TOOLS.md"
copy_root_doc "BOOTSTRAP.md"

rsync "${RSYNC_FLAGS[@]}" \
  "$SRC_ROOT/documentation/" \
  "$DEST_ROOT/documentation/"

rsync "${RSYNC_FLAGS[@]}" \
  --exclude "backups/" \
  --include "*/" \
  --include "*.sh" \
  --exclude "*" \
  "$SRC_ROOT/scripts/" \
  "$DEST_ROOT/scripts/"

rsync "${RSYNC_FLAGS[@]}" \
  --include "*/" \
  --include "*.md" \
  --exclude "*" \
  "$SRC_ROOT/projects/_templates/" \
  "$DEST_ROOT/projects/_templates/"

rsync "${RSYNC_FLAGS[@]}" \
  --include "*/" \
  --include "*.json" \
  --exclude "*" \
  "$SRC_ROOT/state/schemas/" \
  "$DEST_ROOT/state/schemas/"

rsync "${RSYNC_FLAGS[@]}" \
  --include "*/" \
  --include "*.json" \
  --include "*.jsonl" \
  --exclude "*" \
  "$SRC_ROOT/state/fixtures/" \
  "$DEST_ROOT/state/fixtures/"

cd "$DEST_ROOT"
STATUS_SHORT="$(git status --short)"

if [ "$DRY_RUN" -eq 1 ]; then
  jq -n --arg src "$SRC_ROOT" --arg dest "$DEST_ROOT" --arg status "$STATUS_SHORT" \
    '{passed:true, dryRun:true, src:$src, dest:$dest, gitStatus:$status, summary:"scaffold export dry-run complete"}'
  exit 0
fi

if [ "$DO_COMMIT" -eq 1 ] && [ -n "$STATUS_SHORT" ]; then
  git add .
  git commit -m "$COMMIT_MSG"
  if [ "$DO_PUSH" -eq 1 ]; then
    git push
  fi
fi

FINAL_STATUS="$(git status --short)"
jq -n --arg src "$SRC_ROOT" --arg dest "$DEST_ROOT" --arg status "$FINAL_STATUS" \
  '{passed:true, dryRun:false, src:$src, dest:$dest, gitStatus:$status, summary:"scaffold export complete"}'
