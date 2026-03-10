#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:?Usage: enforce-task-consistency.sh <projectPath>}"
WORKSPACE_ROOT="/home/simon/.openclaw/workspace-builder"
REGISTRY_PATH="$WORKSPACE_ROOT/active-tasks.json"
TASKS_FILE="$PROJECT_PATH/TASKS.md"

if [ ! -f "$TASKS_FILE" ]; then
  echo '{"passed":false,"summary":"TASKS.md not found","issues":["missing TASKS.md"]}'
  exit 1
fi
if [ ! -f "$REGISTRY_PATH" ]; then
  echo '{"passed":false,"summary":"registry not found","issues":["missing active-tasks.json"]}'
  exit 1
fi

python3 - "$REGISTRY_PATH" "$TASKS_FILE" "$PROJECT_PATH" <<'PY'
import json
import re
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
tasks_path = Path(sys.argv[2])
project_path = sys.argv[3]
reg = json.loads(registry_path.read_text())
text = tasks_path.read_text(errors="ignore")

active_statuses = {"pending", "running", "retrying"}
final_statuses = {"todo", "in-progress", "review", "blocked", "done", "pending"}
issues = []


def label_value(block: str, label: str) -> str:
    esc = re.escape(label)
    for pat in [rf"^- \*\*{esc}:\*\*\s*(.*)$", rf"^- {esc}:\s*(.*)$"]:
        m = re.search(pat, block, re.M)
        if m:
            return m.group(1).strip()
    return ""


def norm_status(raw: str) -> str:
    return re.sub(r"[`*_]", "", raw or "").strip().lower()


def placeholder_commit(raw: str) -> bool:
    v = (raw or "").strip().lower()
    if not v:
        return True
    return any(tok in v for tok in ["pending", "hash", "todo", "fill"])


def is_placeholder_evidence(entry: str) -> bool:
    e = entry.strip().lower().strip('`')
    patterns = [
        r'^_?pending_?$',
        r'^\(?(fill|fill at review/done|fill at done)\)?$',
        r'^\(?(hash)\)?$',
        r'^tbd$',
        r'^todo$'
    ]
    return any(re.match(p, e) for p in patterns)


def section_quality(block: str):
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
    cur = None
    for line in block.splitlines():
        h = heading_name(line)
        if h:
            cur = h
            val = line.split(':', 1)[1].strip().replace('**', '').strip() if ':' in line else ''
            if val:
                sections[cur].append(val)
            continue
        st = line.strip()
        if re.match(r'^-\s+\*\*[^*]+:\*\*', st) or re.match(r'^-\s+[A-Z][A-Za-z0-9 /()_-]{1,60}:\s*', st):
            cur = None
            continue
        if cur is None:
            continue
        if re.match(r'^-\s+\[\s\]\s+', st):
            if cur in unchecked:
                unchecked[cur] += 1
            sections[cur].append(st)
        elif st.startswith('- '):
            sections[cur].append(st[2:].strip())

    out = []
    for k, name in (("ac", "Acceptance Criteria"), ("tests", "Required Tests"), ("plan", "Verification Plan")):
        if len(sections[k]) == 0:
            out.append(f"{name} is empty")
        if unchecked[k] > 0:
            out.append(f"{name} has unchecked checklist items")

    evidence_entries = [x.strip() for x in sections['evidence'] if x.strip()]
    if not evidence_entries:
        out.append('Verification Evidence is empty')
    elif all(is_placeholder_evidence(e) for e in evidence_entries):
        out.append('Verification Evidence appears pending/placeholder')
    return out

blocks = {}
for m in re.finditer(r"^###\s+(T\d+)\b", text, re.M):
    tid = m.group(1)
    start = m.start()
    rest = text[m.end():]
    nxt = re.search(r"^###\s+", rest, re.M)
    end = m.end() + (nxt.start() if nxt else len(rest))
    block = text[start:end]
    blocks[tid] = {
        "block": block,
        "final_status_raw": label_value(block, "Final Status"),
        "final_commit_raw": label_value(block, "Final Commit"),
    }

for tid, info in blocks.items():
    st = norm_status(info["final_status_raw"])
    if st and st not in final_statuses:
        issues.append(f"{tid}: invalid Final Status '{info['final_status_raw']}'")
    if st == "done":
        if placeholder_commit(info["final_commit_raw"]):
            issues.append(f"{tid}: Final Status is done but Final Commit is placeholder")
        for q in section_quality(info["block"]):
            issues.append(f"{tid}: {q}")

project_tasks = [t for t in reg.get("tasks", []) if t.get("projectPath") == project_path]
for t in project_tasks:
    tid = t.get("taskId") or "<unknown>"
    rs = (t.get("status") or "").lower()
    if rs not in active_statuses:
        issues.append(f"{tid}: invalid active registry status '{rs}'")
    if tid not in blocks:
        issues.append(f"{tid}: missing detail block in TASKS.md")
        continue
    final_st = norm_status(blocks[tid]["final_status_raw"])
    if final_st == "done":
        issues.append(f"{tid}: active registry entry exists but Final Status is done")

passed = len(issues) == 0
summary = "Consistency passed" if passed else f"Consistency failed ({len(issues)} issue(s))"
print(json.dumps({"passed": passed, "summary": summary, "issues": issues}))
raise SystemExit(0 if passed else 1)
PY
