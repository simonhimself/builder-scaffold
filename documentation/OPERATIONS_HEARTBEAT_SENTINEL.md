# OPERATIONS_HEARTBEAT_SENTINEL.md

## Purpose
- Keep continuous heartbeat monitoring without recurring model/token usage during idle periods.
- Preserve deterministic drift/task detection from `scripts/check.sh`.

## Current Architecture
- Scheduler: user systemd timer `builder-heartbeat-sentinel.timer` (every 10 minutes).
- Worker: user systemd service `builder-heartbeat-sentinel.service`.
- Script: `scripts/heartbeat-sentinel.sh`.
- Source of truth check: `scripts/check.sh`.
- Delivery path: `openclaw message send --channel discord --target channel:1477348546502987828`.
- OpenClaw cron `builder-heartbeat` is intentionally disabled.

## Runtime Behavior
- Sentinel runs `check.sh` and parses active/stalled/drift status.
- Clean state (`no active tasks`, `consistencyIssueCount=0`, `idleIssueCount=0`) -> no post.
- Non-clean state -> send ALERT message.
- Recovery from alert -> send RECOVERED message once.
- Dedupe/cooldown state is persisted in `state/heartbeat-sentinel-state.json`.

## Files
- Script: `/home/simon/.openclaw/workspace-builder/scripts/heartbeat-sentinel.sh`
- State: `/home/simon/.openclaw/workspace-builder/state/heartbeat-sentinel-state.json`
- Timer unit: `/home/simon/.config/systemd/user/builder-heartbeat-sentinel.timer`
- Service unit: `/home/simon/.config/systemd/user/builder-heartbeat-sentinel.service`
- Disabled OpenClaw cron config: `/home/simon/.openclaw/cron/jobs.json`

## Operations
- Check timer/service status:
  - `systemctl --user status builder-heartbeat-sentinel.timer`
  - `systemctl --user status builder-heartbeat-sentinel.service`
- Run one manual cycle:
  - `systemctl --user start builder-heartbeat-sentinel.service`
- Read recent sentinel logs:
  - `journalctl --user -u builder-heartbeat-sentinel.service -n 50 --no-pager`
- Confirm OpenClaw cron heartbeat remains disabled:
  - verify `enabled: false` for job `5aa261e5-49c4-4d58-971b-c937d4ed5892` in `/home/simon/.openclaw/cron/jobs.json`

## Rollback (if needed)
- Disable sentinel timer:
  - `systemctl --user disable --now builder-heartbeat-sentinel.timer`
- Re-enable OpenClaw cron heartbeat job by setting `enabled: true` on job `builder-heartbeat` in `/home/simon/.openclaw/cron/jobs.json`.
