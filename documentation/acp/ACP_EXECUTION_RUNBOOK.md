# ACP Execution Runbook (Builder → Worker)

## Purpose
Deterministic orchestration for Builder-owned ACP execution.

## Session Selection
- **Default for Builder workspace:** per-task persistent ACP session with `runtime="acp"`, `agentId="codex"`, `mode="session"`, `thread=true`
- Put the full initial task brief in `sessions_spawn.task` (atomic spawn+brief); then keep follow-up turns in the same ACP session via `sessions_send(sessionKey, ...)` until task closure.
- One-shot runs (`mode="run"`, `thread=false`) are **not** the Builder default — use only for quick exploratory probes outside of task context.

## Spawn Contract (include in every worker task)
Require worker to return:
1. scope completed
2. files changed
3. tests/checks run + concise results
4. commit hash (or explicit no-commit reason)
5. unresolved risks/todos

## Task Lane Rules
- One thread = one scoped task lane
- Do not mix unrelated tasks in a single ACP thread
- If scope changes materially, open a new lane

## Completion / Cleanup (Required)
- Close via atomic command: `bash scripts/close-task.sh <projectPath> <taskId> <commitHash>`
- This updates canonical TASKS detail fields and removes task from active registry.
- When task is done, close the ACP session/binding
- Do not leave idle persistent sessions attached to threads
- In SYNC summary, include: `ACP_LIFECYCLE: closed` (or explicit reason if open)

## Config Guardrails (live)
- `channels.discord.threadBindings.spawnAcpSessions = true`
- `channels.discord.allowBots = false`
- `messages.queue.byChannel.discord = "collect"`
