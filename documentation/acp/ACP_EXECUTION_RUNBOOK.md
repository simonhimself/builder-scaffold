# ACP Execution Runbook (Builder → Worker)

## Purpose
Deterministic orchestration for Builder-owned ACP execution.

## Session Selection
- **Default for Builder workspace:** one-shot implementation/task execution with `runtime="acp"`, `mode="run"`, `thread=false`
- Persistent thread-bound ACP sessions: use only when explicitly requested for follow-up conversational work (`mode="session"`, `thread=true`)

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
