#!/usr/bin/env bash
# task-registry.sh — active ACP inventory (ephemeral) + event log
# Usage:
#   task-registry.sh add <id> <taskId> <description> <project> <projectPath> <acpSessionKey> <threadId>
#   task-registry.sh attach <id> <acpSessionKey>
#   task-registry.sh done <id> <commitHash>      # removes from active inventory
#   task-registry.sh fail <id> <reason>          # removes from active inventory
#   task-registry.sh remove <id>
#   task-registry.sh list
#   task-registry.sh get <id>

set -euo pipefail

WORKSPACE_ROOT="/home/simon/.openclaw/workspace-builder"
REGISTRY="$WORKSPACE_ROOT/active-tasks.json"
EVENTS="$WORKSPACE_ROOT/task-events.jsonl"
PROJECT_READY="$WORKSPACE_ROOT/scripts/project-ready.sh"

# Ensure registry exists
if [ ! -f "$REGISTRY" ]; then
  echo '{"tasks":[]}' > "$REGISTRY"
fi

ts_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_event() {
  local kind="$1"
  local id="$2"
  local payload_json="${3-}"

  if [ -z "$payload_json" ]; then
    payload_json='{}'
  fi

  jq -nc \
    --arg ts "$(ts_now)" \
    --arg kind "$kind" \
    --arg id "$id" \
    --argjson payload "$payload_json" \
    '{ts:$ts, kind:$kind, id:$id, payload:$payload}' >> "$EVENTS"
}

get_task_json() {
  local id="$1"
  jq -c --arg id "$id" '.tasks[] | select(.id == $id)' "$REGISTRY"
}

CMD="${1:-list}"

case "$CMD" in

  add)
    ID="${2:?id required}"
    TASK_ID="${3:?taskId required}"
    DESCRIPTION="${4:?description required}"
    PROJECT="${5:?project required}"
    PROJECT_PATH="${6:?projectPath required}"
    ACP_SESSION_KEY="${7:?acpSessionKey required}"
    THREAD_ID="${8:?threadId required}"
    STARTED_AT="$(ts_now)"

    # Build-ready gate: require project + task readiness before ACP tracking
    if [ ! -x "$PROJECT_READY" ]; then
      echo "ERROR: missing executable $PROJECT_READY" >&2
      exit 1
    fi

    ready_json="$($PROJECT_READY build "$PROJECT_PATH" "$TASK_ID" || true)"
    if ! echo "$ready_json" | jq -e ' .passed == true ' >/dev/null 2>&1; then
      echo "ERROR: project/task not build-ready" >&2
      echo "$ready_json" >&2
      exit 1
    fi

    # Check for duplicate
    existing="$(get_task_json "$ID" || true)"
    if [ -n "$existing" ]; then
      echo "ERROR: task $ID already exists in registry" >&2
      exit 1
    fi

    if [ "$ACP_SESSION_KEY" = "pending" ]; then
      STATUS="pending"
    else
      STATUS="running"
    fi

    NEW_ENTRY=$(jq -n \
      --arg id "$ID" \
      --arg taskId "$TASK_ID" \
      --arg description "$DESCRIPTION" \
      --arg project "$PROJECT" \
      --arg projectPath "$PROJECT_PATH" \
      --arg acpSessionKey "$ACP_SESSION_KEY" \
      --arg threadId "$THREAD_ID" \
      --arg startedAt "$STARTED_AT" \
      --arg status "$STATUS" \
      '{
        id: $id,
        taskId: $taskId,
        description: $description,
        project: $project,
        projectPath: $projectPath,
        acpSessionKey: $acpSessionKey,
        threadId: $threadId,
        startedAt: $startedAt,
        status: $status
      }')

    jq --argjson entry "$NEW_ENTRY" '.tasks += [$entry]' "$REGISTRY" > "${REGISTRY}.tmp" \
      && mv "${REGISTRY}.tmp" "$REGISTRY"

    append_event "add" "$ID" "$NEW_ENTRY"
    echo "OK: added $ID ($STATUS)"
    ;;

  attach)
    ID="${2:?id required}"
    ACP_SESSION_KEY="${3:?acpSessionKey required}"

    existing="$(get_task_json "$ID" || true)"
    if [ -z "$existing" ]; then
      echo "ERROR: task $ID not found in registry" >&2
      exit 1
    fi

    jq --arg id "$ID" \
       --arg key "$ACP_SESSION_KEY" \
       '(.tasks[] | select(.id == $id)) |= . + {acpSessionKey: $key, status: "running"}' \
       "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

    updated="$(get_task_json "$ID")"
    append_event "attach" "$ID" "$updated"
    echo "OK: attached session key for $ID"
    ;;

  done)
    ID="${2:?id required}"
    COMMIT_HASH="${3:?commitHash required}"

    existing="$(get_task_json "$ID" || true)"
    if [ -z "$existing" ]; then
      echo "ERROR: task $ID not found in registry" >&2
      exit 1
    fi

    jq --arg id "$ID" '.tasks = [.tasks[] | select(.id != $id)]' \
      "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

    payload=$(jq -n --arg commitHash "$COMMIT_HASH" --argjson task "$existing" '{commitHash:$commitHash, task:$task}')
    append_event "done" "$ID" "$payload"
    echo "OK: removed $ID from active inventory (commit: $COMMIT_HASH)"
    ;;

  fail)
    ID="${2:?id required}"
    REASON="${3:?reason required}"

    existing="$(get_task_json "$ID" || true)"
    if [ -z "$existing" ]; then
      echo "ERROR: task $ID not found in registry" >&2
      exit 1
    fi

    jq --arg id "$ID" '.tasks = [.tasks[] | select(.id != $id)]' \
      "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

    payload=$(jq -n --arg reason "$REASON" --argjson task "$existing" '{reason:$reason, task:$task}')
    append_event "fail" "$ID" "$payload"
    echo "OK: removed $ID from active inventory (failed)"
    ;;

  remove)
    ID="${2:?id required}"
    existing="$(get_task_json "$ID" || true)"
    if [ -z "$existing" ]; then
      echo "ERROR: task $ID not found in registry" >&2
      exit 1
    fi

    jq --arg id "$ID" '.tasks = [.tasks[] | select(.id != $id)]' \
      "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

    append_event "remove" "$ID" "$existing"
    echo "OK: removed $ID"
    ;;

  list)
    jq '.tasks' "$REGISTRY"
    ;;

  get)
    ID="${2:?id required}"
    jq --arg id "$ID" '.tasks[] | select(.id == $id)' "$REGISTRY"
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    exit 1
    ;;
esac
