# HEARTBEAT.md

## Source of Truth
- Heartbeat is scheduled by OpenClaw cron, not Linux user crontab.
- Job name: `builder-heartbeat`.
- Cadence: every 600000ms (10 minutes).
- Config/state file: `/home/simon/.openclaw/cron/jobs.json`.

## Runtime Behavior
- Heartbeat runs: `bash /home/simon/.openclaw/workspace-builder/scripts/check.sh`.
- Early exit (`NO_REPLY`) only when all are true: `hasActiveTasks == false`, `consistencyIssueCount == 0`, and `idleIssueCount == 0`.
- Otherwise, post compact status to Blue status channel (including drift sections when present).

## Guardrails
- Do not create duplicate heartbeat/watchdog cron jobs unless Simon explicitly asks.
- If docs disagree with scheduler state, scheduler state is authoritative.
