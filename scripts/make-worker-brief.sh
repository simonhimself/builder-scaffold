#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:?Usage: make-worker-brief.sh <projectPath> <taskId>}"
TASK_ID="${2:?Usage: make-worker-brief.sh <projectPath> <taskId>}"

TASKS_FILE="$PROJECT_PATH/TASKS.md"
SPEC_FILE="$PROJECT_PATH/SPEC.md"
PRD_FILE="$PROJECT_PATH/PRD.md"

[ -d "$PROJECT_PATH" ] || { echo "ERROR: project path missing: $PROJECT_PATH" >&2; exit 1; }
[ -f "$TASKS_FILE" ] || { echo "ERROR: TASKS.md missing: $TASKS_FILE" >&2; exit 1; }

python3 - "$PROJECT_PATH" "$TASK_ID" "$TASKS_FILE" "$SPEC_FILE" "$PRD_FILE" <<'PY'
import re, sys
from pathlib import Path

project_path = Path(sys.argv[1])
task_id = sys.argv[2]
tasks_file = Path(sys.argv[3])
spec_file = Path(sys.argv[4])
prd_file = Path(sys.argv[5])

tasks_text = tasks_file.read_text(errors='ignore')

m = re.search(rf'^###\s+{re.escape(task_id)}\b.*$', tasks_text, re.M)
if not m:
    print(f"ERROR: task detail block missing for {task_id}", file=sys.stderr)
    raise SystemExit(1)

start = m.start()
rest = tasks_text[m.end():]
nxt = re.search(r'^###\s+', rest, re.M)
end = m.end() + (nxt.start() if nxt else len(rest))
task_block = tasks_text[start:end].strip() + "\n"

# Attempt to extract a verification command hint from the task block
verify_cmd = None
mm = re.search(r'^-\s*Verification Plan:\s*(.*)$', task_block, re.M)
if mm:
    verify_cmd = mm.group(1).strip()

spec_snip = ""
if spec_file.exists():
    spec_text = spec_file.read_text(errors='ignore')
    # Heuristic: if this is a match-score task, include D3 section if present
    d3 = re.search(r'^###\s+D3:.*$', spec_text, re.M)
    if d3:
        rest2 = spec_text[d3.end():]
        nxt2 = re.search(r'^###\s+', rest2, re.M)
        end2 = d3.end() + (nxt2.start() if nxt2 else len(rest2))
        spec_snip = spec_text[d3.start():end2].strip() + "\n"

import subprocess

def sh(cmd):
    return subprocess.check_output(cmd, cwd=project_path, text=True, stderr=subprocess.DEVNULL).strip()

git_status = "(git status unavailable)"
git_log = "(git log unavailable)"
try:
    git_status = sh(["git","status","-sb"]) 
    git_log = sh(["git","log","-5","--oneline"]) 
except Exception:
    pass

print(f"# Worker Brief — {project_path.name} {task_id}\n")
print("## Project")
print(f"- Path: `{project_path}`")
if prd_file.exists():
    print(f"- PRD: `{prd_file}`")
if spec_file.exists():
    print(f"- SPEC: `{spec_file}`")
print(f"- TASKS: `{tasks_file}`\n")

print("## Current git state")
print("```")
print(git_status)
print("\n" + git_log)
print("```\n")

print("## Task detail block (source of truth)")
print(task_block)

if spec_snip:
    print("## Relevant SPEC section")
    print(spec_snip)

print("## Execution instructions")
print("- Implement the task with minimal, high-quality diffs.")
print("- Update/add tests as required by the task block.")
print("- Run the repo verification command and ensure it passes (see Verification Plan in TASKS).")
print("- Produce a single commit (or a small coherent series) with a clear message.")
print("\n## Output contract (must include)")
print("- What you changed (short bullet summary)")
print("- Files changed")
print("- Commands run + results (esp. verification)")
print("- Commit hash(es)")
PY
