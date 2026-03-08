# HEARTBEAT.md

## Source of Truth
- Heartbeat is scheduled by OpenClaw cron, not Linux user crontab.
- Job name: `builder-heartbeat`.
- Cadence: every 600000ms (10 minutes).
- Config/state file: `/home/simon/.openclaw/cron/jobs.json`.

## Runtime Behavior
- Heartbeat runs: `bash /home/simon/.openclaw/workspace-builder/scripts/check.sh`.
- If `hasActiveTasks` is `false`, it should return `NO_REPLY` (silent when idle).
- If active or stalled work exists, post compact status to Blue status channel.

## Guardrails
- Do not create duplicate heartbeat/watchdog cron jobs unless Simon explicitly asks.
- If docs disagree with scheduler state, scheduler state is authoritative.
