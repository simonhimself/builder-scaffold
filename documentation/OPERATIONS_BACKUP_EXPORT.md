# Backup and Scaffold Operations

## Purpose

This runbook defines the recurring operations for:

1. Syncing portable scaffold files to `builder-scaffold`
2. Creating full profile backups for disaster recovery
3. Restoring full profile backups safely

## Paths

- Workspace source: `/home/simon/.openclaw/workspace-builder`
- Scaffold repo: `/home/simon/repos/builder-scaffold`
- Backup folder: `/home/simon/repos/builder-profile-backup/snapshots`

## Scaffold Sync

Dry run:

```bash
bash scripts/export-scaffold.sh --dry-run
```

Sync only:

```bash
bash scripts/export-scaffold.sh
```

Sync + commit + push scaffold repo:

```bash
bash scripts/export-scaffold.sh --commit --push --message "chore(scaffold): sync curated files"
```

## Full Profile Backup (Unencrypted)

Dry run:

```bash
bash scripts/backup-profile.sh --dry-run
```

Create backup:

```bash
bash scripts/backup-profile.sh
```

Behavior:
- Creates `profile-YYYYmmdd-HHMMSS.tar.zst`
- Writes `*.sha256` checksum
- Writes `*.manifest.json`
- Prunes old snapshots (keeps newest 5 by default)

Optional flags:

```bash
bash scripts/backup-profile.sh --keep 7
bash scripts/backup-profile.sh --no-prune
bash scripts/backup-profile.sh --dest /some/other/path
```

## Restore

List backup contents:

```bash
bash scripts/restore-profile.sh --archive /path/to/profile-*.tar.zst --list
```

Safe staged restore (default):

```bash
bash scripts/restore-profile.sh --archive /path/to/profile-*.tar.zst
```

In-place restore (destructive overlay):

```bash
bash scripts/restore-profile.sh --archive /path/to/profile-*.tar.zst --in-place --confirm
```

## Recommended Cadence

- Scaffold sync: after meaningful workflow/script/docs updates
- Full profile backup: daily or before risky changes
- Restore test: after script changes or monthly

## Notes

- Full backup scope is fixed to full profile (not workspace-only).
- Runtime task files are still script-owned and not templated.
