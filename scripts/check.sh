#!/usr/bin/env bash
# check.sh — reads active-tasks.json + git, outputs structured JSON

set -uo pipefail

WORKSPACE_ROOT="/home/simon/.openclaw/workspace-builder"
REGISTRY="$WORKSPACE_ROOT/active-tasks.json"
ENFORCE="$WORKSPACE_ROOT/scripts/enforce-task-consistency.sh"
PROJECTS_ROOT="$WORKSPACE_ROOT/projects"
STALL_THRESHOLD=900
MAX_ISSUES=5

if [ ! -f "$REGISTRY" ]; then
  echo '{"hasActiveTasks":false,"activeTasks":[],"stalledTasks":[],"consistencyIssues":[],"idleIssues":[],"summary":"No registry found"}'
  exit 0
fi

NOW=$(date +%s)
active_count=$(jq '[.tasks[]] | length' "$REGISTRY")
active_tasks='[]'
stalled_tasks='[]'

while IFS= read -r task_json; do
  project_path=$(echo "$task_json" | jq -r '.projectPath')
  started_at=$(echo "$task_json" | jq -r '.startedAt')
  status=$(echo "$task_json" | jq -r '.status // "running"')

  started_ts=$(date -d "$started_at" +%s 2>/dev/null || echo "$NOW")
  running_for=$((NOW - started_ts))

  if [ -d "$project_path" ]; then
    last_commit_ts=$(git -C "$project_path" log --format="%ct" -1 2>/dev/null || echo "0")
    last_commit_hash=$(git -C "$project_path" log --format="%h" -1 2>/dev/null || echo "none")
    last_commit_msg=$(git -C "$project_path" log --format="%s" -1 2>/dev/null || echo "none")
  else
    last_commit_ts=0
    last_commit_hash="unknown"
    last_commit_msg="project path not found"
  fi

  commit_age=$((NOW - last_commit_ts))
  if [ "$last_commit_ts" -gt "$started_ts" ]; then
    commit_after_start=true
  else
    commit_after_start=false
  fi

  enriched=$(echo "$task_json" | jq \
    --argjson commitAge "$commit_age" \
    --arg commitHash "$last_commit_hash" \
    --arg commitMsg "$last_commit_msg" \
    --argjson runningFor "$running_for" \
    --argjson commitAfterStart "$commit_after_start" \
    --arg status "$status" \
    '. + {
      lastCommitAgeSeconds: $commitAge,
      lastCommitHash: $commitHash,
      lastCommitMsg: $commitMsg,
      runningForSeconds: $runningFor,
      lastCommitAfterTaskStart: $commitAfterStart,
      status: $status
    }')

  pending_key=$(echo "$task_json" | jq -r '.acpSessionKey // ""')
  if { [ "$running_for" -gt "$STALL_THRESHOLD" ] && [ "$commit_after_start" = "false" ]; } || { [ "$pending_key" = "pending" ] && [ "$running_for" -gt 120 ]; }; then
    stalled_tasks=$(echo "$stalled_tasks" | jq --argjson t "$enriched" '. + [$t]')
  else
    active_tasks=$(echo "$active_tasks" | jq --argjson t "$enriched" '. + [$t]')
  fi

done < <(jq -c '.tasks[]' "$REGISTRY")

consistency_issues='[]'  # active-project issues
idle_issues='[]'         # non-active project issues

if [ -x "$ENFORCE" ] && [ -d "$PROJECTS_ROOT" ]; then
  active_project_list="$(jq -r '.tasks[].projectPath' "$REGISTRY" | sort -u)"
  while IFS= read -r tasks_file; do
    project_path="${tasks_file%/TASKS.md}"
    [ -z "$project_path" ] && continue

    result="$($ENFORCE "$project_path" 2>/dev/null || true)"
    issues="$(echo "$result" | jq -c '.issues // []' 2>/dev/null || echo '["consistency-check parse error"]')"
    issue_count="$(echo "$issues" | jq 'length')"
    [ "$issue_count" -eq 0 ] && continue

    prefixed="$(echo "$issues" | jq -c --arg p "$project_path" '[ .[] | "\($p): \(.)" ]')"

    if echo "$active_project_list" | grep -Fxq "$project_path"; then
      consistency_issues="$(echo "$consistency_issues" | jq --argjson x "$prefixed" '. + $x')"
    else
      idle_issues="$(echo "$idle_issues" | jq --argjson x "$prefixed" '. + $x')"
    fi
  done < <(find "$PROJECTS_ROOT" -mindepth 2 -maxdepth 2 -type f -name TASKS.md)
fi

# Cap issue arrays for token efficiency
consistency_total=$(echo "$consistency_issues" | jq 'length')
idle_total=$(echo "$idle_issues" | jq 'length')
consistency_preview=$(echo "$consistency_issues" | jq --argjson n "$MAX_ISSUES" '.[0:$n]')
idle_preview=$(echo "$idle_issues" | jq --argjson n "$MAX_ISSUES" '.[0:$n]')

total_active=$(echo "$active_tasks" | jq 'length')
total_stalled=$(echo "$stalled_tasks" | jq 'length')

if [ "$active_count" -eq 0 ]; then
  has_active=false
else
  has_active=true
fi

if [ "$consistency_total" -gt 0 ]; then
  summary="⚠️ active consistency drift: ${consistency_total} issue(s), ${total_stalled} stalled, ${total_active} progressing"
elif [ "$idle_total" -gt 0 ]; then
  summary="⚠️ idle consistency drift: ${idle_total} issue(s), ${total_active} active"
elif [ "$total_stalled" -gt 0 ]; then
  summary="⚠️ ${total_stalled} stalled, ${total_active} progressing"
elif [ "$total_active" -gt 0 ]; then
  summary="✅ ${total_active} active task(s) progressing"
else
  summary="No active tasks"
fi

jq -n \
  --argjson hasActive "$has_active" \
  --argjson active "$active_tasks" \
  --argjson stalled "$stalled_tasks" \
  --argjson consistency "$consistency_preview" \
  --argjson consistencyCount "$consistency_total" \
  --argjson idle "$idle_preview" \
  --argjson idleCount "$idle_total" \
  --arg summary "$summary" \
  '{hasActiveTasks:$hasActive, activeTasks:$active, stalledTasks:$stalled, consistencyIssues:$consistency, consistencyIssueCount:$consistencyCount, idleIssues:$idle, idleIssueCount:$idleCount, summary:$summary}'
