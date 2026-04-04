# Delegation Rubric — Builder vs ACP

Purpose: decide deterministically whether Builder executes directly or delegates to ACP.

## Core Rule

Use this test before every BUILD slice:

> Can I write a complete brief right now that an ACP worker can execute **without questions** and verify with explicit commands?

- **Yes** → Delegate to ACP.
- **No** → Builder executes directly.

## Delegate to ACP when ALL are true

1. Task is bounded to one task ID in `TASKS.md`
2. Acceptance criteria are explicit and binary
3. Required tests / verify command are known
4. Working directory and file scope are clear
5. No live interactive guidance expected from Simon
6. Failure is recoverable by one re-brief + retry

## Builder Direct when ANY are true

1. Simon is actively guiding in real time
2. Scope is exploratory/unclear/changing
3. Task is ops/config/auth/debug glue work
4. Task is small enough that ACP overhead is larger than execution
5. Action is externally sensitive and needs high-trust control

## Defaults

- Default to **ACP** for autonomous implementation tasks.
- Default to **Builder direct** for planning, ops, config, and interactive debugging.

## ACP Spawn Profile (this workspace)

- `runtime: "acp"`, `agentId: "codex"`, `mode: "session"`, `thread: true`
- Registry first (add as `pending`), then 🔨 post, then spawn
- Attach real session key via `bash scripts/task-registry.sh attach <id> <sessionKey>`
- Put full initial brief in `sessions_spawn.task` at spawn time; use `sessions_send(sessionKey, ...)` for follow-ups only
- Verify completion via `git log` + `bash scripts/verify.sh <projectPath>`
- Close atomically via `bash scripts/close-task.sh <projectPath> <taskId> <commitHash>` (updates TASKS.md + removes from active inventory)
- Close ACP session after task: `acpx codex sessions close <sessionKey>`

## Notes

- Persistent sessions (not one-shot) are the default to allow mid-task steering and reliable follow-up.
- Codebase (git + project artifacts) is the persistent state between sessions.
