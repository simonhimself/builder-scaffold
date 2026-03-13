#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?Usage: project-ready.sh <scaffold|build> <projectPath> [taskId]}"
PROJECT_PATH="${2:?Usage: project-ready.sh <scaffold|build> <projectPath> [taskId]}"
TASK_ID="${3:-}"

TASKS_FILE="$PROJECT_PATH/TASKS.md"
PRD_FILE="$PROJECT_PATH/PRD.md"
SPEC_FILE="$PROJECT_PATH/SPEC.md"
HOOK_FILE="$PROJECT_PATH/.git/hooks/pre-push"

fail() {
  local msg="$1"
  jq -n --arg msg "$msg" --arg mode "$MODE" --arg projectPath "$PROJECT_PATH" --arg taskId "$TASK_ID" \
    '{passed:false, mode:$mode, projectPath:$projectPath, taskId:$taskId, error:$msg}'
  exit 1
}

if [ "$MODE" != "scaffold" ] && [ "$MODE" != "build" ]; then
  fail "mode must be scaffold or build"
fi

[ -d "$PROJECT_PATH" ] || fail "project path missing"
[ -f "$TASKS_FILE" ] || fail "TASKS.md missing"
[ -f "$PRD_FILE" ] || fail "PRD.md missing"
[ -f "$SPEC_FILE" ] || fail "SPEC.md missing"
[ -d "$PROJECT_PATH/.git" ] || fail "git repo missing (.git)"
[ -x "$HOOK_FILE" ] || fail "pre-push hook missing or not executable"

if [ "$MODE" = "build" ]; then
  [ -n "$TASK_ID" ] || fail "taskId required for build mode"

  TASK_CHECK="$(python3 - "$TASKS_FILE" "$TASK_ID" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
task_id = sys.argv[2]
text = path.read_text(errors='ignore')
lines = text.splitlines()

row_status = None
# Parse active tasks table status if present
sec = None
for i, l in enumerate(lines):
    if l.strip().lower().startswith('## active tasks'):
        sec = i
        break
if sec is not None:
    header_i = None
    sep_i = None
    for i in range(sec + 1, len(lines)):
        if lines[i].startswith('## '):
            break
        if lines[i].strip().startswith('|'):
            header_i = i
            if i + 1 < len(lines) and lines[i + 1].strip().startswith('|'):
                sep_i = i + 1
                break
    if header_i is not None and sep_i is not None:
        headers = [c.strip().lower() for c in lines[header_i].strip().strip('|').split('|')]
        hmap = {h: idx for idx, h in enumerate(headers)}
        id_idx = hmap.get('id')
        status_idx = hmap.get('status')
        if id_idx is not None and status_idx is not None:
            i = sep_i + 1
            while i < len(lines) and lines[i].strip().startswith('|'):
                row = [c.strip() for c in lines[i].strip().strip('|').split('|')]
                if len(row) >= len(headers) and row[id_idx] == task_id:
                    row_status = row[status_idx]
                    break
                i += 1

m = re.search(rf'^###\s+{re.escape(task_id)}\b', text, re.M)
if not m:
    print(json.dumps({"passed": False, "error": f"task detail block missing for {task_id}"}))
    raise SystemExit

start = m.start()
rest = text[m.end():]
nxt = re.search(r'^###\s+', rest, re.M)
end = m.end() + (nxt.start() if nxt else len(rest))
block = text[start:end]

final_status = ''
for pat in [r'^- \*\*Final Status:\*\*\s*(.*)$', r'^- Final Status:\s*(.*)$']:
    mm = re.search(pat, block, re.M)
    if mm:
        final_status = mm.group(1).strip()
        break

def norm(s):
    return re.sub(r'[`*_]', '', (s or '')).strip().lower()

status = norm(row_status) if row_status else norm(final_status)
if not status:
    print(json.dumps({"passed": False, "error": f"task {task_id} status missing (set todo/in-progress/review)", "rowStatus": row_status, "finalStatus": final_status}))
    raise SystemExit

if status in {'done', 'blocked'}:
    print(json.dumps({"passed": False, "error": f"task {task_id} status is {status}, not build-ready", "status": status}))
    raise SystemExit

# Upfront quality presence checks (non-empty sections, evidence field present)

def heading_name(line: str):
    s = line.strip()
    if not s.startswith('-'):
        return None
    s = s[1:].strip().replace('**', '')
    if ':' not in s:
        return None
    k = s.split(':', 1)[0].strip().lower()
    if k.startswith('acceptance criteria'):
        return 'ac'
    if k.startswith('required tests'):
        return 'tests'
    if k.startswith('verification plan'):
        return 'plan'
    if k.startswith('verification evidence'):
        return 'evidence'
    return None

sections = {'ac': [], 'tests': [], 'plan': [], 'evidence': []}
cur = None
for line in block.splitlines():
    h = heading_name(line)
    if h:
        cur = h
        val = line.split(':',1)[1].strip().replace('**', '').strip() if ':' in line else ''
        if val:
            sections[cur].append(val)
        continue
    st = line.strip()
    if re.match(r'^-\s+\*\*(Final Commit|Final Status|Risks/Todos|Goal|Scope|Owner|Depends on|Blocked by)\s*:\*\*', st) or re.match(r'^-\s+(Final Commit|Final Status|Risks/Todos|Goal|Scope|Owner|Depends on|Blocked by)\s*:\s*', st):
        cur = None
        continue
    if cur is None:
        continue
    if st.startswith('- '):
        sections[cur].append(st[2:].strip())

missing = []
if len(sections['ac']) == 0:
    missing.append('Acceptance Criteria missing/empty')
if len(sections['tests']) == 0:
    missing.append('Required Tests missing/empty')
if len(sections['plan']) == 0:
    missing.append('Verification Plan missing/empty')
# Evidence can be placeholder pre-build, but field must exist
if len(sections['evidence']) == 0:
    missing.append('Verification Evidence field missing/empty')

if missing:
    print(json.dumps({"passed": False, "error": "task not build-ready", "issues": missing, "taskId": task_id, "status": status}))
    raise SystemExit

print(json.dumps({"passed": True, "taskId": task_id, "status": status}))
PY
)"

  if ! echo "$TASK_CHECK" | jq -e '.passed == true' >/dev/null 2>&1; then
    echo "$TASK_CHECK" | jq -c '. + {mode:"build", projectPath:"'"$PROJECT_PATH"'"}'
    exit 1
  fi
fi

jq -n --arg mode "$MODE" --arg projectPath "$PROJECT_PATH" --arg taskId "$TASK_ID" '{passed:true, mode:$mode, projectPath:$projectPath, taskId:$taskId, summary:"project ready"}'
