# OpenClaw ACP + Codex Runbook (VPS)

This document describes the working ACP orchestration setup for `simon@openclaw-vps`, how to validate it, and how to recover when it breaks.

## Goal architecture

- OpenClaw gateway runs as systemd user service on VPS.
- ACP backend is `acpx`.
- Default ACP agent is `codex` (via `@zed-industries/codex-acp`, authenticated with **ChatGPT Plus OAuth**).
- Codex default model is `gpt-5.3-codex` with medium reasoning effort (set in `~/.codex/config.toml`).
- Blue-builder orchestrates ACP with **per-task persistent sessions by default** (`agentId: "codex"`, `mode: "session"`, `thread: true`). One-shot runs (`mode: run`, `thread: false`) are reserved for quick exploratory probes only.
- **Post-spawn required:** `acpx codex set-mode full-access --session <key>` before sending work (codex-acp defaults to read-only mode).

## Current canonical config locations

- OpenClaw config: `~/.openclaw/openclaw.json`
- ACPX config: `~/.acpx/config.json`
- OpenCode config: `~/.config/opencode/opencode.json`
- OpenCode auth store: `~/.local/share/opencode/auth.json`
- OpenClaw gateway log: `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
- Blue-builder sessions: `~/.openclaw/agents/blue-builder/sessions/*.jsonl`

## Known-good baseline

### 1) OpenClaw ACP defaults

In `~/.openclaw/openclaw.json`:

```json
{
  "acp": {
    "defaultAgent": "codex"
  },
  "plugins": {
    "entries": {
      "acpx": {
        "config": {
          "permissionMode": "approve-all",
          "nonInteractivePermissions": "deny",
          "cwd": "/home/simon/.openclaw/workspace-builder"
        }
      }
    }
  }
}
```

**Critical:** `nonInteractivePermissions` must be `"deny"` (NOT `"fail"`). `"fail"` causes silent session crashes on any permission prompt in non-interactive mode.

`permissionMode` must be one of: `approve-all`, `approve-reads`, `deny-all`. (`auto` is invalid.)

### 2) ACPX defaults

In `~/.acpx/config.json`:

```json
{
  "defaultAgent": "codex",
  "defaultPermissions": "approve-all",
  "nonInteractivePermissions": "deny",
  "agents": {
    "codex": {
      "command": "/home/simon/.local/bin/codex-acp-oauth"
    }
  },
  "auth": {
    "chatgpt": "<JWT token from ChatGPT Plus OAuth>"
  }
}
```

### 2b) Codex-acp OAuth wrapper

`/home/simon/.local/bin/codex-acp-oauth`:
```bash
#!/usr/bin/env bash
unset OPENAI_API_KEY
unset CODEX_API_KEY
exec /home/simon/.npm/_npx/<hash>/node_modules/@zed-industries/codex-acp-linux-x64/bin/codex-acp \
  -c 'sandbox_permissions=["disk-full-read-access","disk-write-access","network-full-access"]' "$@"
```

**Why:** Codex-acp defaults to `read-only` mode. The `-c sandbox_permissions` flag attempts to override, but currently codex-acp may not honor it — so `acpx codex set-mode full-access` after session creation is the reliable path.

### 2c) Codex CLI config

In `~/.codex/config.toml`:
```toml
model = "gpt-5.3-codex"
sandbox_permissions = [
  "disk-full-read-access",
  "disk-write-access",
  "network-full-access",
]
```

### 3) OpenCode default model

In `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.3-codex",
  "provider": {
    "openai": {
      "models": {
        "gpt-5.3-codex": {
          "options": {
            "reasoningEffort": "medium"
          }
        }
      }
    }
  }
}
```

## Model switching (Codex <-> Claude) for ACP

Important behavior for this stack:

- For `opencode` ACP, model selection is controlled by OpenCode config (`~/.config/opencode/opencode.json`).
- The OpenCode ACP command (`opencode acp`) does not expose a `--model` flag.
- The ACPX `/acp model ...` style session config change is not supported by OpenCode ACP in this setup (`session/set_config_option` is not available).

So the reliable switch method is: update OpenCode config, then start a new ACP run.

### Switch to Codex 5.3 (medium)

```bash
python3 -c 'import json; from pathlib import Path; p=Path.home()/".config"/"opencode"/"opencode.json"; o=json.loads(p.read_text()); o["model"]="openai/gpt-5.3-codex"; o.setdefault("provider",{}).setdefault("openai",{}).setdefault("models",{}).setdefault("gpt-5.3-codex",{}).setdefault("options",{})["reasoningEffort"]="medium"; p.write_text(json.dumps(o,indent=2)+"\n")'
npx -y opencode-ai debug config
```

### Switch to Claude Opus 4.6 (medium-like)

Anthropic does not use OpenAI-style `reasoningEffort=medium`. Use thinking budget as an equivalent control.

```bash
python3 -c 'import json; from pathlib import Path; p=Path.home()/".config"/"opencode"/"opencode.json"; o=json.loads(p.read_text()); o["model"]="anthropic/claude-opus-4-6"; o.setdefault("provider",{}).setdefault("anthropic",{}).setdefault("models",{}).setdefault("claude-opus-4-6",{}).setdefault("options",{})["thinking"]={"type":"enabled","budgetTokens":8000}; p.write_text(json.dumps(o,indent=2)+"\n")'
npx -y opencode-ai debug config
```

### How to instruct blue-builder to use a specific model

For deterministic behavior, instruct blue-builder in two steps:

1. Update `~/.config/opencode/opencode.json` model first.
2. Then spawn ACP one-shot task.

Because agent-to-agent readback is policy-restricted in this environment, use an artifact handoff pattern for verification:

- Ask ACP task to write output to a known file (for example `/tmp/acp_probe.txt`).
- Have blue-builder read the file and return contents.

### Helper scripts (installed on VPS)

Installed in:

- `/home/simon/.openclaw/workspace-builder/scripts/set-model-codex.sh`
- `/home/simon/.openclaw/workspace-builder/scripts/set-model-claude.sh`

Usage:

```bash
/home/simon/.openclaw/workspace-builder/scripts/set-model-codex.sh
/home/simon/.openclaw/workspace-builder/scripts/set-model-claude.sh
```

What they do:

- Update `~/.config/opencode/opencode.json` model defaults.
- Preserve other config keys.
- Print `opencode-ai debug config` so callers can verify active model.

How to use from blue-builder prompts:

- "Run `/home/simon/.openclaw/workspace-builder/scripts/set-model-codex.sh`, then spawn ACP one-shot and write result to `/tmp/...`"
- "Run `/home/simon/.openclaw/workspace-builder/scripts/set-model-claude.sh`, then spawn ACP one-shot and write result to `/tmp/...`"

## Auth model (important)

- This VPS is headless, but OAuth still works via device/browser flow over SSH TTY.
- OpenCode stores OAuth credentials in `~/.local/share/opencode/auth.json`.

### Authenticate providers (headless)

```bash
ssh -t simon@openclaw-vps
npx -y opencode-ai
# then inside TUI:
# /connect
# choose OpenAI -> ChatGPT Plus/Pro
# choose Anthropic -> OAuth if desired
```

Then verify:

```bash
npx -y opencode-ai auth list
```

Expected: credentials listed (for example OpenAI oauth, Anthropic oauth).

## Blue-builder ACP orchestration policy

Default (AGENTS.md contract):

- `runtime: "acp"`, `agentId: "codex"`, `mode: "session"`, `thread: true`
- Registry → spawn → attach → brief → follow-up in same session → close-task.sh → close session
- One-shot (`mode: run`, `thread: false`) only for quick exploratory probes outside task scope

Agent-to-agent policy note:

- `~/.openclaw/openclaw.json` now allows `opencode` in `tools.agentToAgent.allow`.
- This removes allowlist blocking for blue-builder <-> opencode readback.
- However, direct text readback still depends on session semantics (see caveats below).

## Validation checklist (run after any change)

1) Gateway health

```bash
~/.npm-global/bin/openclaw gateway restart
~/.npm-global/bin/openclaw gateway status
~/.npm-global/bin/openclaw doctor
```

2) Config sanity

```bash
python3 -c 'import json; from pathlib import Path; o=json.loads((Path.home()/".openclaw"/"openclaw.json").read_text()); print(o.get("acp",{}).get("defaultAgent"))'
/home/simon/.npm-global/lib/node_modules/openclaw/extensions/acpx/node_modules/.bin/acpx config show
npx -y opencode-ai debug config
```

3) Model/provider availability

```bash
npx -y opencode-ai auth list
npx -y opencode-ai models | grep -E 'openai/gpt-5.3-codex|anthropic/'
```

4) ACP end-to-end smoke test

```bash
/home/simon/.npm-global/lib/node_modules/openclaw/extensions/acpx/node_modules/.bin/acpx --format json exec "Reply with ACP_OK only."
```

Expected output stream includes `ACP_OK` and ends with `stopReason: end_turn`.

5) Blue-builder orchestrator path smoke test (exact path)

```bash
~/.npm-global/bin/openclaw agent --agent blue-builder --message "Run ACP one-shot with default ACP agent. Have it write exactly BLUE_BUILDER_ACP_OK to /tmp/blue_builder_acp_probe.txt. Then read and return the exact file contents." --json --timeout 240
```

Expected: returned text and file contents equal `BLUE_BUILDER_ACP_OK`.

## Common failure modes and fixes

### A) "permissionMode must be equal to one of the allowed values"

- Cause: invalid `plugins.entries.acpx.config.permissionMode` in `~/.openclaw/openclaw.json`.
- Fix: set to `approve-all`, `approve-reads`, or `deny-all`; restart gateway.

### B) ACP feels "stuck" / fragmented

- Common cause: stale registry entries, dead sessions, or rate-limited providers.
- Fix: run `check.sh`, fail stale registry entries, restart gateway to clear accounting, then retry.

### B2) ACP one-shot succeeded but no text result visible to blue-builder

- Cause: agent-to-agent history/messaging is restricted by policy (`tools.agentToAgent.allow`).
- Fix: add `opencode` to `tools.agentToAgent.allow` and restart gateway.
- Caveat: even with allowlist open, one-shot runs (`mode: run`) still do not provide durable conversational history for readback.

### B4) Direct readback still fails after allowlist update

- Cause: current channel/session context is webchat where thread-bound ACP sessions are unavailable.
- In this environment:
  - `mode: session` requires `thread: true`.
  - thread binding is unavailable on webchat.
- Practical options:
  - Keep one-shot + file artifact handoff (recommended on webchat).
  - Run orchestrator from a thread-capable channel (for example Discord) if direct conversational readback is required.

### B3) Attempted `/acp model` switch does nothing for OpenCode

- Cause: OpenCode ACP adapter does not support `session/set_config_option` in this setup.
- Fix: switch model in `~/.config/opencode/opencode.json` before spawning new ACP runs.

### C) Quota/rate errors while ACP path is healthy

- Symptoms in session logs:
  - OpenAI usage/quota limit messages
  - Anthropic overloaded/rate limit messages
- Fix:
  - verify provider auth
  - reduce concurrent orchestration
  - use fallback model/provider strategy

### D) OpenCode auth not present

- `npx -y opencode-ai auth list` shows `0 credentials`.
- Fix: rerun `/connect` in OpenCode and complete OAuth.

## Logging and diagnosis commands

```bash
# Gateway log scan
grep -niE "acp|acpx|permission|runtime|error|quota|rate" /tmp/openclaw/openclaw-$(date +%F).log

# Blue-builder ACP/session errors
grep -RniE "AcpRuntimeError|permission|timeout|usage limit|overloaded|rate_limit|quota" ~/.openclaw/agents/blue-builder/sessions --include="*.jsonl"
```

## Safe change workflow

1. Backup any config before edit.
2. Apply one change at a time.
3. Restart gateway.
4. Run validation checklist.
5. Keep a short change note in this document.

## Change notes

- 2026-03-03:
  - Fixed invalid `permissionMode` causing gateway config rejection.
  - Switched ACP defaults to `opencode`.
  - Set OpenCode default model to `openai/gpt-5.3-codex` with `reasoningEffort: medium`.
  - Updated ACP router skill defaults to one-shot orchestration (`thread: false`, `mode: run`).
  - Verified OpenAI and Anthropic OAuth credentials present.
  - Validated direct OpenCode ACP and blue-builder orchestrator ACP path with OpenAI model.
  - Validated Claude path by temporarily switching model to `anthropic/claude-opus-4-6` with thinking `{type: enabled, budgetTokens: 8000}` and running both direct ACP and blue-builder artifact tests.
  - Added `opencode` to `tools.agentToAgent.allow` and confirmed gateway restart.
  - Confirmed that direct text readback still fails in current webchat context because thread-bound ACP sessions are unavailable there.
