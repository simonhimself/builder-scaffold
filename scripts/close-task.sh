#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:?Usage: close-task.sh <projectPath> <taskId> <commitHash> [verifyCommand]}"
TASK_ID="${2:?Usage: close-task.sh <projectPath> <taskId> <commitHash> [verifyCommand]}"
COMMIT_HASH="${3:?Usage: close-task.sh <projectPath> <taskId> <commitHash> [verifyCommand]}"
CUSTOM_VERIFY_CMD="${4:-}"

WORKSPACE_ROOT="/home/simon/.openclaw/workspace-builder"
REGISTRY_PATH="$WORKSPACE_ROOT/active-tasks.json"
VERIFY_SCRIPT="$WORKSPACE_ROOT/scripts/verify.sh"
REGISTRY_SCRIPT="$WORKSPACE_ROOT/scripts/task-registry.sh"
TASKS_FILE="$PROJECT_PATH/TASKS.md"

if [ ! -d "$PROJECT_PATH" ]; then
  jq -n --arg error "project path not found" --arg projectPath "$PROJECT_PATH" '{passed:false,error:$error,projectPath:$projectPath}'
  exit 1
fi
if [ ! -f "$TASKS_FILE" ]; then
  jq -n --arg error "TASKS.md not found" --arg path "$TASKS_FILE" '{passed:false,error:$error,path:$path}'
  exit 1
fi
if [ ! -f "$REGISTRY_PATH" ]; then
  jq -n --arg error "registry not found" --arg path "$REGISTRY_PATH" '{passed:false,error:$error,path:$path}'
  exit 1
fi

if ! git -C "$PROJECT_PATH" rev-parse --verify "$COMMIT_HASH^{commit}" >/dev/null 2>&1; then
  jq -n --arg error "commit not found in project repo" --arg commit "$COMMIT_HASH" '{passed:false,error:$error,commit:$commit}'
  exit 1
fi

if [ -n "$CUSTOM_VERIFY_CMD" ]; then
  VERIFY_JSON="$($VERIFY_SCRIPT "$PROJECT_PATH" "$CUSTOM_VERIFY_CMD" || true)"
else
  VERIFY_JSON="$($VERIFY_SCRIPT "$PROJECT_PATH" || true)"
fi

if ! echo "$VERIFY_JSON" | jq -e '.passed == true' >/dev/null 2>&1; then
  echo "$VERIFY_JSON" | jq -c '. + {passed:false, gate:"verify"}'
  exit 1
fi

QUALITY_JSON="$(python3 - "$TASKS_FILE" "$TASK_ID" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
task_id = sys.argv[2]
text = path.read_text(errors='ignore')
m = re.search(rf'^###\s+{re.escape(task_id)}\b', text, re.M)
if not m:
    print(json.dumps({"passed": False, "issues": [f"Detail block for {task_id} not found"]}))
    raise SystemExit(0)
start = m.start()
rest = text[m.end():]
nxt = re.search(r'^###\s+', rest, re.M)
end = m.end() + (nxt.start() if nxt else len(rest))
block = text[start:end]


def heading_name(line: str):
    s = line.strip()
    if not s.startswith('-'):
        return None
    s = s[1:].strip().replace('**', '')
    if ':' not in s:
        return None
    key = s.split(':', 1)[0].strip().lower()
    if key.startswith('acceptance criteria'):
        return 'ac'
    if key.startswith('required tests'):
        return 'tests'
    if key.startswith('verification plan'):
        return 'plan'
    if key.startswith('verification evidence'):
        return 'evidence'
    return None

sections = {"ac": [], "tests": [], "plan": [], "evidence": []}
unchecked = {"ac": 0, "tests": 0, "plan": 0}
current = None

for line in block.splitlines():
    h = heading_name(line)
    if h:
        current = h
        value = line.split(':', 1)[1].strip().replace('**', '').strip() if ':' in line else ''
        if value:
            sections[current].append(value)
        continue

    st = line.strip()
    if re.match(r'^-\s+\*\*[^*]+:\*\*', st) or re.match(r'^-\s+[A-Z][A-Za-z0-9 /()_-]{1,60}:\s*', st):
        current = None
        continue

    if current is None:
        continue

    if re.match(r'^-\s+\[\s\]\s+', st):
        if current in unchecked:
            unchecked[current] += 1
        sections[current].append(st)
    elif st.startswith('- '):
        sections[current].append(st[2:].strip())

issues = []
for k, name in (("ac", "Acceptance Criteria"), ("tests", "Required Tests"), ("plan", "Verification Plan")):
    if len(sections[k]) == 0:
        issues.append(f"{name} is empty")
    if unchecked.get(k, 0) > 0:
        issues.append(f"{name} has unchecked checklist items")

evidence_entries = [x.strip() for x in sections['evidence'] if x.strip()]
if not evidence_entries:
    issues.append('Verification Evidence is empty')
else:
    import re
    def is_placeholder(entry: str) -> bool:
        e = entry.strip().replace('**', '').lower().strip('`')
        patterns = [
            r'^_?pending_?$',
            r'^\(?(fill|fill at review/done|fill at done)\)?$',
            r'^\(?(hash)\)?$',
            r'^tbd$',
            r'^todo$'
        ]
        return any(re.match(p, e) for p in patterns)

    if all(is_placeholder(e) for e in evidence_entries):
        issues.append('Verification Evidence appears pending/placeholder')

print(json.dumps({"passed": len(issues) == 0, "issues": issues}))
PY
)"

if ! echo "$QUALITY_JSON" | jq -e '.passed == true' >/dev/null 2>&1; then
  echo "$QUALITY_JSON" | jq -c '. + {passed:false, gate:"quality"}'
  exit 1
fi

REGISTRY_ID="$(python3 - "$REGISTRY_PATH" "$PROJECT_PATH" "$TASK_ID" <<'PY'
import json
import sys
from datetime import datetime
from pathlib import Path

registry_path = Path(sys.argv[1])
project_path = sys.argv[2]
task_id = sys.argv[3]
obj = json.loads(registry_path.read_text())
items = [t for t in obj.get('tasks', []) if t.get('projectPath') == project_path and t.get('taskId') == task_id]

def ts(it):
    raw = it.get('startedAt') or ''
    try:
        return datetime.fromisoformat(raw.replace('Z', '+00:00')).timestamp()
    except Exception:
        return 0

if not items:
    print('')
else:
    print(sorted(items, key=ts, reverse=True)[0].get('id', ''))
PY
)"

python3 - "$TASKS_FILE" "$TASK_ID" "$COMMIT_HASH" <<'PY'
import re
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
task_id = sys.argv[2]
commit_hash = sys.argv[3]
text = file_path.read_text(errors='ignore')
lines = text.splitlines()

# Optional index table update (best-effort only)
section = None
for i, line in enumerate(lines):
    if line.strip().lower().startswith('## active tasks'):
        section = i
        break

if section is not None:
    header_i = None
    sep_i = None
    for i in range(section + 1, len(lines)):
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
        i = sep_i + 1
        while i < len(lines) and lines[i].strip().startswith('|'):
            row = [c.strip() for c in lines[i].strip().strip('|').split('|')]
            if len(row) >= len(headers):
                id_idx = hmap.get('id')
                if id_idx is not None and row[id_idx] == task_id:
                    status_idx = hmap.get('status')
                    if status_idx is not None:
                        row[status_idx] = 'done'
                    commit_idx = hmap.get('commit')
                    if commit_idx is not None:
                        row[commit_idx] = commit_hash
                    evidence_idx = hmap.get('verification evidence')
                    if evidence_idx is not None:
                        cur = row[evidence_idx].strip().lower()
                        if cur in {'', 'pending', '_pending_'}:
                            row[evidence_idx] = 'verify.sh ✅'
                    lines[i] = '| ' + ' | '.join(row[:len(headers)]) + ' |'
                    break
            i += 1

new_text = '\n'.join(lines) + '\n'

m = re.search(rf'^###\s+{re.escape(task_id)}\b', new_text, re.M)
if not m:
    raise SystemExit(f'Detail block for {task_id} not found')
start = m.start()
rest = new_text[m.end():]
nxt = re.search(r'^###\s+', rest, re.M)
end = m.end() + (nxt.start() if nxt else len(rest))
block = new_text[start:end]


def set_label(src: str, label: str, value: str) -> str:
    esc = re.escape(label)
    for pat, repl in [
        (rf"^- \*\*{esc}:\*\*\s*(.*)$", f"- **{label}:** {value}"),
        (rf"^- {esc}:\s*(.*)$", f"- {label}: {value}"),
    ]:
        if re.search(pat, src, re.M):
            return re.sub(pat, repl, src, count=1, flags=re.M)
    if not src.endswith('\n'):
        src += '\n'
    return src + f"- {label}: {value}\n"

block = set_label(block, 'Final Commit', f'`{commit_hash}`')
block = set_label(block, 'Final Status', '`done`')
new_text = new_text[:start] + block + new_text[end:]
file_path.write_text(new_text)
PY

if [ -n "$REGISTRY_ID" ]; then
  "$REGISTRY_SCRIPT" done "$REGISTRY_ID" "$COMMIT_HASH" >/dev/null
fi

VERIFY_COMPACT="$(printf '%s' "$VERIFY_JSON" | jq -c '.' 2>/dev/null || echo '{}')"
QUALITY_COMPACT="$(printf '%s' "$QUALITY_JSON" | jq -c '.' 2>/dev/null || echo '{}')"

jq -n \
  --arg taskId "$TASK_ID" \
  --arg commit "$COMMIT_HASH" \
  --arg projectPath "$PROJECT_PATH" \
  --arg registryId "$REGISTRY_ID" \
  --argjson verify "$VERIFY_COMPACT" \
  --argjson quality "$QUALITY_COMPACT" \
  '{passed:true, taskId:$taskId, commit:$commit, projectPath:$projectPath, registryId:$registryId, removedFromActiveInventory: ($registryId != ""), verify:$verify, quality:$quality, summary:"Task closed atomically"}'
