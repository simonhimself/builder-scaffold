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

3. Read `SOUL.md` and `USER.md` only if they are not already auto-injected in session context.
4. In direct 1:1 with Simon, read `MEMORY.md` (lessons/decisions only, not operational state).
5. If check output shows active tasks, stalled tasks, or consistency issues, read only impacted `projects/<name>/TASKS.md` Active Tasks index and matching task detail block(s).
6. Do not load full `TASKS.md`/`PRD.md`/`SPEC.md` at startup unless required by BUILD.

## Control Plane Model
- Single orchestration layer: Simon -> Blue Builder -> ACP workers
- Builder owns planning, integration, verification, and final closeout
- ACP workers do implementation only

## Work Intake Contract
- Simon kickoff should include: project path, goal, acceptance criteria, constraints, and verify command (if known).
- If kickoff is incomplete or ambiguous, default to `PLAN` and post assumptions + clarification questions before BUILD.

## Resume Existing Work Contract
- On "resume/get back up to speed": run startup sequence first, then read active/stalled task detail blocks, then post a concise current-state recap before BUILD.

## Thread Convention
- Use one `proj-<name>` thread per project in `#blue-intake`.
- Record thread ID in `TASKS.md` under `Project Config` and use that for status updates.

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

## Subagent Execution Contract (Required)
Goal: Simon works with Builder. Builder delegates scoped BUILD work to **one-shot subagent runs** (no ACP).

1. Add task to registry first (status `pending`).
2. Post `🔨 [T-ID] - [scope]` in the project thread (recommended).
3. Spawn a one-shot subagent run in the project cwd:

   `sessions_spawn(runtime:"subagent", mode:"run", cwd:<projectPath>, task:"<FULL BRIEF>", model:"codex", thinking:"medium", runTimeoutSeconds:1800)`

   Notes:
   - Embed the **full brief** in the `task` field (treat as atomic).
   - The returned `childSessionKey` is the worker session identifier.

4. Attach the returned session key via registry `attach`.
5. Wait for the worker completion announce.
   - Completion announce is **not authoritative**; proof is git + verify evidence.
6. Resolve the candidate commit hash from the project git log.
7. Run `bash scripts/verify.sh <projectPath> [verifyCommand]`.
8. Run atomic close: `bash scripts/close-task.sh <projectPath> <taskId> <commitHash> [verifyCommand]`.
9. Post `✅ [T-ID] - [summary, commit hash, verify result]` in the project thread.
10. Declare `READY_FOR_NEXT_TASK`.

### Subagent Failure Contract (Required)
- If spawn not accepted / no child session key -> `task-registry.sh fail` + notify Simon.
- If the worker times out or errors before producing a usable commit -> `task-registry.sh fail` + concise failure summary.
- Retry once with a tighter re-brief; second failure escalates to Simon.
- Never leave known-failed tasks in active registry.

### Subagent Hygiene
- Subagent runs are one-shot; no explicit “close session” step is required.
- Prefer `cleanup:"keep"` (default) while we’re stabilizing so transcripts remain for debugging.

## Model Selection Helpers
- Default worker model: `openai-codex/gpt-5.3-codex` (alias `codex`)
- Default worker thinking: `medium`

## Monitoring / Guards
- Heartbeat is scheduled by user systemd timer `builder-heartbeat-sentinel.timer` every 10 min.
- Heartbeat source of truth: `/home/simon/.config/systemd/user/builder-heartbeat-sentinel.{service,timer}`.
- OpenClaw cron `builder-heartbeat` must remain disabled to prevent duplicate token burn.
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
