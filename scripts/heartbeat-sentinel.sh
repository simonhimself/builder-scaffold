#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/simon/.openclaw/workspace-builder"
CHECK_SCRIPT="$WORKSPACE/scripts/check.sh"
STATE_FILE="$WORKSPACE/state/heartbeat-sentinel-state.json"
STATUS_TARGET="channel:1477348546502987828"
COOLDOWN_SECONDS=3600
OPENCLAW_BIN="/home/simon/.npm-global/bin/openclaw"

mkdir -p "$(dirname "$STATE_FILE")"

if [ ! -x "$CHECK_SCRIPT" ]; then
  exit 1
fi

CHECK_JSON="$(bash "$CHECK_SCRIPT")"
NOW_EPOCH="$(date -u +%s)"
NOW_ISO="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

PARSED="$(python3 - "$STATE_FILE" "$COOLDOWN_SECONDS" "$NOW_EPOCH" "$CHECK_JSON" <<'PY2'
import hashlib
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
cooldown = int(sys.argv[2])
now_epoch = int(sys.argv[3])
check = json.loads(sys.argv[4])

state = {
    "lastStatus": "clean",
    "lastHash": "",
    "lastAlertAt": 0,
}
if state_path.exists():
    try:
        loaded = json.loads(state_path.read_text())
        if isinstance(loaded, dict):
            state.update(loaded)
    except Exception:
        pass

active_ids = sorted((t or {}).get("taskId", "") for t in check.get("activeTasks", []) if (t or {}).get("taskId"))
stalled_ids = sorted((t or {}).get("taskId", "") for t in check.get("stalledTasks", []) if (t or {}).get("taskId"))
consistency = int(check.get("consistencyIssueCount", 0))
idle = int(check.get("idleIssueCount", 0))
summary = str(check.get("summary", ""))

is_clean = (not check.get("hasActiveTasks", False) and consistency == 0 and idle == 0)
status = "clean" if is_clean else "alert"

payload = {
    "status": status,
    "activeTaskIds": active_ids,
    "stalledTaskIds": stalled_ids,
    "consistencyIssueCount": consistency,
    "idleIssueCount": idle,
    "summary": summary,
}
current_hash = hashlib.sha256(json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()

last_hash = str(state.get("lastHash", ""))
last_alert = int(state.get("lastAlertAt", 0) or 0)
last_status = str(state.get("lastStatus", "clean"))

should_alert = False
should_recovery = False

if status == "alert":
    if current_hash != last_hash:
        should_alert = True
    elif now_epoch - last_alert >= cooldown:
        should_alert = True
else:
    if last_status == "alert":
        should_recovery = True

out = {
    "status": status,
    "shouldAlert": should_alert,
    "shouldRecovery": should_recovery,
    "activeTaskIds": active_ids,
    "stalledTaskIds": stalled_ids,
    "consistencyIssueCount": consistency,
    "idleIssueCount": idle,
    "summary": summary,
    "hash": current_hash,
    "newState": {
        "lastStatus": status,
        "lastHash": current_hash if status == "alert" else "",
        "lastAlertAt": now_epoch if should_alert else last_alert,
    },
}
print(json.dumps(out))
PY2
)"

SHOULD_ALERT="$(printf '%s' "$PARSED" | python3 -c 'import json,sys; print("true" if json.load(sys.stdin)["shouldAlert"] else "false")')"
SHOULD_RECOVERY="$(printf '%s' "$PARSED" | python3 -c 'import json,sys; print("true" if json.load(sys.stdin)["shouldRecovery"] else "false")')"

if [ "$SHOULD_ALERT" = "true" ]; then
  ALERT_MSG="$(python3 - "$NOW_ISO" "$PARSED" <<'PY4'
import json
import sys

p = json.loads(sys.argv[2])
now_iso = sys.argv[1]
active = ", ".join(p["activeTaskIds"]) or "none"
stalled = ", ".join(p["stalledTaskIds"]) or "none"
print(
    "Dragon Heartbeat ALERT - {summary}\n"
    "Time: {time}\n"
    "Active tasks: {active}\n"
    "Stalled tasks: {stalled}\n"
    "Consistency issues: {consistency}\n"
    "Idle issues: {idle}".format(
        summary=p["summary"],
        time=now_iso,
        active=active,
        stalled=stalled,
        consistency=p["consistencyIssueCount"],
        idle=p["idleIssueCount"],
    )
)
PY4
)"
  PATH="/home/simon/.npm-global/bin:$PATH" "$OPENCLAW_BIN" message send --channel discord --target "$STATUS_TARGET" --message "$ALERT_MSG" >/dev/null
fi

if [ "$SHOULD_RECOVERY" = "true" ]; then
  RECOVERY_MSG="Dragon Heartbeat RECOVERED - check.sh clean
Time: $NOW_ISO
Status: no active tasks and no drift issues"
  PATH="/home/simon/.npm-global/bin:$PATH" "$OPENCLAW_BIN" message send --channel discord --target "$STATUS_TARGET" --message "$RECOVERY_MSG" >/dev/null
fi

python3 - "$STATE_FILE" "$PARSED" <<'PY3'
import json
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
p = json.loads(sys.argv[2])
state_path.write_text(json.dumps(p["newState"], indent=2) + "\n")
PY3
