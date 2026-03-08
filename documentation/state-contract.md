# Runtime State Contract

This document defines the interface contract for runtime task-state files.

These files are generated and maintained by scripts. They are not project templates.

## Purpose

- Keep runtime state machine-readable and stable across tools.
- Make script outputs safe to consume by heartbeat/check tooling and future agents.
- Separate durable planning truth (`TASKS.md`) from ephemeral runtime state.

## Source of Truth

Implementation source of truth:
- `scripts/task-registry.sh`
- `scripts/close-task.sh`
- `scripts/check.sh`

Contract source of truth:
- `state/schemas/active-tasks.schema.json`
- `state/schemas/task-event.schema.json`

## Files

### `active-tasks.json`

- Purpose: active inventory only (ephemeral).
- Lifecycle:
  - Added by `task-registry.sh add`
  - Updated by `task-registry.sh attach`
  - Removed by `task-registry.sh done|fail|remove`
- Canonical statuses for active inventory: `pending`, `running`, `retrying`
- Completed and failed tasks are removed from active inventory.

Structure:
- Top-level object with `tasks` array.
- Each task includes:
  - `id`
  - `taskId`
  - `description`
  - `project`
  - `projectPath`
  - `acpSessionKey`
  - `threadId`
  - `startedAt` (UTC timestamp)
  - `status`

### `task-events.jsonl`

- Purpose: append-only event log for task lifecycle transitions.
- Writer: `task-registry.sh` (`append_event` function).
- One JSON object per line.

Each line includes:
- `ts` (UTC timestamp)
- `kind` (`add`, `attach`, `done`, `fail`, `remove`)
- `id` (registry task id)
- `payload` (event-specific payload)

Payload conventions:
- `add`, `attach`, `remove`: payload is a task object snapshot.
- `done`: payload includes `commitHash` and `task` snapshot.
- `fail`: payload includes `reason` and `task` snapshot.

## Operational Rules

- Do not hand-edit runtime files during normal operation.
- Do not pre-seed these files from templates in new projects.
- Use deterministic commands:
  - `bash scripts/task-registry.sh add ...`
  - `bash scripts/task-registry.sh attach ...`
  - `bash scripts/task-registry.sh done ...`
  - `bash scripts/task-registry.sh fail ...`
- Treat `TASKS.md` as durable orchestration ledger and `active-tasks.json` as ephemeral runtime inventory.

## Validation

Schema files in `state/schemas/` define the contract expected by tooling.
Fixtures in `state/fixtures/` provide example payloads for tests and documentation.
