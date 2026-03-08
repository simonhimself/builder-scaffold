#!/usr/bin/env bash
set -euo pipefail

CFG="$HOME/.config/opencode/opencode.json"
mkdir -p "$(dirname "$CFG")"

python3 - <<'PY'
import json
from pathlib import Path

p = Path.home() / ".config" / "opencode" / "opencode.json"
if p.exists():
    o = json.loads(p.read_text())
else:
    o = {"$schema": "https://opencode.ai/config.json"}

o["model"] = "openai/gpt-5.3-codex"
opts = (
    o.setdefault("provider", {})
     .setdefault("openai", {})
     .setdefault("models", {})
     .setdefault("gpt-5.3-codex", {})
     .setdefault("options", {})
)
opts["reasoningEffort"] = "medium"

p.write_text(json.dumps(o, indent=2) + "\n")
print("set model:", o["model"])
print("reasoningEffort:", opts.get("reasoningEffort"))
PY

npx -y opencode-ai debug config | sed -n "1,120p"
echo "[ok] OpenCode default set to openai/gpt-5.3-codex (medium)"
