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

o["model"] = "anthropic/claude-opus-4-5"
opts = (
    o.setdefault("provider", {})
     .setdefault("anthropic", {})
     .setdefault("models", {})
     .setdefault("claude-opus-4-5", {})
     .setdefault("options", {})
)
opts["thinking"] = {"type": "enabled", "budgetTokens": 8000}

p.write_text(json.dumps(o, indent=2) + "\n")
print("set model:", o["model"])
print("thinking:", opts.get("thinking"))
PY

npx -y opencode-ai debug config | sed -n "1,140p"
echo "[ok] OpenCode default set to anthropic/claude-opus-4-5 (thinking budget 8000)"
