#!/usr/bin/env bash
set -euo pipefail

BACKUP_DEST="/home/simon/repos/builder-profile-backup/snapshots"
KEEP_COUNT=5
DRY_RUN=0
PRUNE=1

usage() {
  cat <<USAGE
Usage: backup-profile.sh [options]

Create a full profile backup archive (unencrypted) for Blue Builder environment.

Included sources (fixed full scope):
  /home/simon/.openclaw
  /home/simon/.acpx
  /home/simon/.config/opencode
  /home/simon/.local/share/opencode
  /home/simon/.claude
  /home/simon/.codex

Options:
  --dest <path>     Backup destination directory (default: /home/simon/repos/builder-profile-backup/snapshots)
  --keep <n>        Keep newest n snapshots (default: 5)
  --no-prune        Do not delete older snapshots
  --dry-run         Show actions without writing files
  -h, --help        Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dest)
      BACKUP_DEST="$2"
      shift 2
      ;;
    --keep)
      KEEP_COUNT="$2"
      shift 2
      ;;
    --no-prune)
      PRUNE=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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

if ! [[ "$KEEP_COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --keep must be a non-negative integer" >&2
  exit 1
fi

TS="$(date -u +%Y%m%d-%H%M%S)"
ARCHIVE_NAME="profile-${TS}.tar.zst"
ARCHIVE_PATH="$BACKUP_DEST/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
MANIFEST_PATH="$BACKUP_DEST/profile-${TS}.manifest.json"

SOURCE_REL=(
  ".openclaw"
  ".acpx"
  ".config/opencode"
  ".local/share/opencode"
  ".claude"
  ".codex"
)

EXISTING_SOURCES=()
for rel in "${SOURCE_REL[@]}"; do
  abs="/home/simon/$rel"
  if [ -e "$abs" ]; then
    EXISTING_SOURCES+=("$rel")
  fi
done

if [ "${#EXISTING_SOURCES[@]}" -eq 0 ]; then
  echo "ERROR: none of the expected full-profile sources exist" >&2
  exit 1
fi

SOURCES_JSON="$(printf '%s\n' "${EXISTING_SOURCES[@]}" | jq -R . | jq -s .)"

if [ "$DRY_RUN" -eq 1 ]; then
  jq -n \
    --arg dest "$BACKUP_DEST" \
    --arg archive "$ARCHIVE_PATH" \
    --argjson keep "$KEEP_COUNT" \
    --argjson prune "$( [ "$PRUNE" -eq 1 ] && echo true || echo false )" \
    --argjson sources "$SOURCES_JSON" \
    '{passed:true, dryRun:true, destination:$dest, archive:$archive, keep:$keep, prune:$prune, sources:$sources, summary:"profile backup dry-run complete"}'
  exit 0
fi

mkdir -p "$BACKUP_DEST"

TMP_EXCLUDES="$(mktemp)"
cat > "$TMP_EXCLUDES" <<X
.DS_Store
._*
X

tar --exclude-from="$TMP_EXCLUDES" -C /home/simon --zstd -cf "$ARCHIVE_PATH" "${EXISTING_SOURCES[@]}"
rm -f "$TMP_EXCLUDES"

CHECKSUM="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$CHECKSUM" "$ARCHIVE_NAME" > "$CHECKSUM_PATH"

ARCHIVE_SIZE_BYTES="$(stat -c%s "$ARCHIVE_PATH")"

jq -n \
  --arg ts "$TS" \
  --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg archive "$ARCHIVE_NAME" \
  --arg archivePath "$ARCHIVE_PATH" \
  --arg checksum "$CHECKSUM" \
  --arg checksumFile "$CHECKSUM_PATH" \
  --argjson sizeBytes "$ARCHIVE_SIZE_BYTES" \
  --argjson sources "$SOURCES_JSON" \
  '{timestamp:$ts, createdAt:$createdAt, archive:$archive, archivePath:$archivePath, sha256:$checksum, checksumFile:$checksumFile, sizeBytes:$sizeBytes, sources:$sources}' \
  > "$MANIFEST_PATH"

if [ "$PRUNE" -eq 1 ] && [ "$KEEP_COUNT" -gt 0 ]; then
  mapfile -t SNAPSHOTS < <(ls -1 "$BACKUP_DEST"/profile-*.tar.zst 2>/dev/null | sort)
  TOTAL="${#SNAPSHOTS[@]}"
  if [ "$TOTAL" -gt "$KEEP_COUNT" ]; then
    REMOVE_COUNT=$((TOTAL - KEEP_COUNT))
    for old in "${SNAPSHOTS[@]:0:REMOVE_COUNT}"; do
      base="${old##*/}"
      stem="${base%.tar.zst}"
      rm -f "$old" "$old.sha256" "$BACKUP_DEST/$stem.manifest.json"
    done
  fi
fi

jq -n \
  --arg dest "$BACKUP_DEST" \
  --arg archive "$ARCHIVE_PATH" \
  --arg checksum "$CHECKSUM" \
  --arg manifest "$MANIFEST_PATH" \
  --argjson keep "$KEEP_COUNT" \
  '{passed:true, dryRun:false, destination:$dest, archive:$archive, sha256:$checksum, manifest:$manifest, keep:$keep, summary:"profile backup complete"}'
