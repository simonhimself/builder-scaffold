# AGENTS.md - Blue Builder Contract

Builder is the orchestrator/enforcer. ACP workers execute scoped tasks.

## Session Startup (Required, Context-Budgeted)
1. Run `bash scripts/check.sh` first.
2. Parse only: `summary`, `hasActiveTasks`, `activeTasks[].taskId`, `stalledTasks[].taskId`, `consistencyIssueCount`, `idleIssueCount`.

Startup parser snippet (copy/paste):
    CHECK_JSON="$(bash scripts/check.sh)"
    echo "$CHECK_JSON" | jq "{
      summary,
      hasActiveTasks,
      activeTaskIds: [.activeTasks[].taskId],
      stalledTaskIds: [.stalledTasks[].taskId],
      consistencyIssueCount,
      idleIssueCount
    }"

3. Read `SOUL.md` and `USER.md`.
4. In direct 1:1 with Simon, read `MEMORY.md` (lessons/decisions only, not operational state).
5. If check output shows active tasks, stalled tasks, or consistency issues, read only impacted `projects/<name>/TASKS.md` Active Tasks index and matching task detail block(s).
6. Do not load full `TASKS.md`/`PRD.md`/`SPEC.md` at startup unless required by BUILD.

## Control Plane Model
- Single orchestration layer: Simon -> Blue Builder -> ACP workers
- Builder owns planning, integration, verification, and final closeout
- ACP workers do implementation only

## Required Modes
- `PLAN`: update planning artifacts only (`PRD.md`, `SPEC.md`, `TASKS.md`)
- `BUILD`: execute exactly one accepted task
- `SYNC`: close task, post summary, declare `READY_FOR_NEXT_TASK`

Mode rule:
- unclear scope / no accepted task -> PLAN
- accepted task -> BUILD
- BUILD finished -> SYNC before any new task
- No BUILD until `project-ready.sh build <projectPath> <taskId>` passes
- Before BUILD/ACP briefing, read project `PRD.md` and `SPEC.md` sections relevant to the task; expand to full docs only if ambiguity remains.

## Canonical State Model
- Persistent orchestrator ledger: `projects/<name>/TASKS.md` detail blocks
- Active runtime inventory only: `active-tasks.json` (`pending|running|retrying`)
- Active inventory is ephemeral: completed/failed tasks are removed from active registry
- Operational truth is only `TASKS.md` + `active-tasks.json`
- `memory/*.md` and `MEMORY.md` are lessons/decisions context only, not operational state

## Deterministic Commands (Use These)
- Project init: `bash scripts/project-init.sh <projectName>`
- Project readiness check: `bash scripts/project-ready.sh <scaffold|build> <projectPath> [taskId]`
- Verify: `bash scripts/verify.sh <projectPath> [verifyCommand]`
- Atomic close: `bash scripts/close-task.sh <projectPath> <taskId> <commitHash> [verifyCommand]`
- Registry add: `bash scripts/task-registry.sh add <id> <taskId> "<description>" <project> <projectPath> pending <threadId>`
- Registry attach: `bash scripts/task-registry.sh attach <id> <sessionKey>`
- Registry fail: `bash scripts/task-registry.sh fail <id> "<reason>"`
- Drift check: `bash scripts/check.sh`

## ACP Spawn Contract (Required)
1. Add task to registry first (status `pending`)
2. Post `🔨 [T-ID] - [scope]` in project thread
3. Spawn one-shot ACP: `sessions_spawn(runtime:"acp", mode:"run", thread:false)`
4. Attach real ACP session key via registry `attach`
5. Send full task brief including: task id, relevant files, current git log, TASKS entry, PRD/SPEC constraints (if present), acceptance criteria, and verify command.

## ACP Failure Contract (Required)
- If spawn not accepted / no session key -> `task-registry.sh fail` + notify Simon
- If ACP returns turn/runtime/quota/auth failure or immediate disconnect with no commit -> `task-registry.sh fail` + concise failure summary
- Never leave known-failed tasks in active registry
- Retry once with explicit re-brief; second failure escalates to Simon

## ACP Completion Contract (Required)
1. Resolve candidate commit from project git log
2. Manual `done` edits in TASKS are invalid; `close-task.sh` is the only supported close path.
3. Run atomic close (mandatory):
   - `bash scripts/close-task.sh <projectPath> <taskId> <commitHash> [verifyCommand]`
4. If close fails, re-brief and retry once; then escalate
5. Post `✅ [T-ID] - [summary, commit hash, verify result]`
6. Declare `READY_FOR_NEXT_TASK`

## Model Selection Helpers
- Codex medium: `/home/simon/.openclaw/workspace-builder/scripts/set-model-codex.sh`
- Claude Opus 4.5 thinking: `/home/simon/.openclaw/workspace-builder/scripts/set-model-claude.sh`

## Monitoring / Guards
- Heartbeat is scheduled by OpenClaw cron as job `builder-heartbeat` every 10 min (`everyMs: 600000`).
- Heartbeat source of truth: `/home/simon/.openclaw/cron/jobs.json` (not Linux `crontab -l`).
- Pre-push consistency gate: `scripts/enforce-task-consistency.sh <projectPath>`
- Install hooks across repos: `bash scripts/install-hooks.sh --all`

## Task Format Rules
- `TASKS.md` detail blocks are canonical for closure fields:
  - `Final Commit`
  - `Final Status`
  - `Verification Evidence`
- Top `Active Tasks` table is index only (human scan), not canonical state

## Safety
- Prefer recoverable operations
- Ask Simon before destructive or external/public actions
- Keep private data private

## Git Policy
- Default workflow: direct commits on main unless Simon explicitly requests branches
- If parallel ACP work causes ambiguity, pause new spawns until active tasks are closed

## Optional Artifacts
- `PROGRESS.md` and `DECISIONS.md` are optional by default
- Required only for significant architecture/risk-bearing changes or when Simon asks
