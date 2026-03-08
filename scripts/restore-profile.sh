#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH=""
STAGING_ROOT="/home/simon/restores"
IN_PLACE=0
CONFIRM=0
LIST_ONLY=0
VERIFY_CHECKSUM=1

usage() {
  cat <<USAGE
Usage: restore-profile.sh --archive <path> [options]

Restore a full profile backup created by backup-profile.sh.

Options:
  --archive <path>    Required archive path (profile-*.tar.zst)
  --list              List archive contents and exit
  --staging-dir <p>   Staging restore parent dir (default: /home/simon/restores)
  --in-place          Restore directly into /home/simon (destructive overlay)
  --confirm           Required with --in-place
  --no-verify         Skip checksum verification
  -h, --help          Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive)
      ARCHIVE_PATH="$2"
      shift 2
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    --staging-dir)
      STAGING_ROOT="$2"
      shift 2
      ;;
    --in-place)
      IN_PLACE=1
      shift
      ;;
    --confirm)
      CONFIRM=1
      shift
      ;;
    --no-verify)
      VERIFY_CHECKSUM=0
      shift
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

if [ -z "$ARCHIVE_PATH" ]; then
  echo "ERROR: --archive is required" >&2
  usage
  exit 1
fi

[ -f "$ARCHIVE_PATH" ] || { echo "ERROR: archive not found: $ARCHIVE_PATH" >&2; exit 1; }

if [ "$IN_PLACE" -eq 1 ] && [ "$CONFIRM" -ne 1 ]; then
  echo "ERROR: --in-place requires --confirm" >&2
  exit 1
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  tar --zstd -tf "$ARCHIVE_PATH"
  exit 0
fi

if [ "$VERIFY_CHECKSUM" -eq 1 ]; then
  CHECKSUM_FILE="$ARCHIVE_PATH.sha256"
  if [ -f "$CHECKSUM_FILE" ]; then
    EXPECTED="$(awk '{print $1}' "$CHECKSUM_FILE")"
    ACTUAL="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
    if [ "$EXPECTED" != "$ACTUAL" ]; then
      echo "ERROR: checksum mismatch for $ARCHIVE_PATH" >&2
      echo "expected: $EXPECTED" >&2
      echo "actual:   $ACTUAL" >&2
      exit 1
    fi
  fi
fi

if [ "$IN_PLACE" -eq 1 ]; then
  TARGET="/home/simon"
else
  TS="$(date -u +%Y%m%d-%H%M%S)"
  TARGET="$STAGING_ROOT/profile-restore-$TS"
  mkdir -p "$TARGET"
fi

tar --zstd -xf "$ARCHIVE_PATH" -C "$TARGET"

MODE="staging"
if [ "$IN_PLACE" -eq 1 ]; then
  MODE="in-place"
fi

jq -n \
  --arg archive "$ARCHIVE_PATH" \
  --arg target "$TARGET" \
  --arg mode "$MODE" \
  '{passed:true, archive:$archive, target:$target, mode:$mode, summary:"profile restore complete"}'
