# TOOLS.md - Builder Local Notes

## Core Host
- **Host:** clawdbot-ubuntu-4gb-nbg1-1 (Ubuntu 24.04)
- **OpenClaw:** 2026.2.x
- **Workspace:** `/home/simon/.openclaw/workspace-builder`
- **Main workspace:** `/home/simon/.openclaw/workspace`

## Dashboard / Gateway
- URL: `https://openclaw-vps.tail084988.ts.net/`
- Access via Tailscale Serve
- `allowTailscale: true`

## Browser
- Google Chrome Stable: `/usr/bin/google-chrome-stable`
- headless + noSandbox
- default profile: `openclaw`

## ACP / Multi-Agent Build Runtime
- ACP backend: `acpx`
- default agent: `codex` (via `@zed-industries/codex-acp`, ChatGPT Plus OAuth)
- allowed agents: `pi`, `claude`, `codex`, `opencode`, `gemini`
- override behavior: explicit agentId in sessions_spawn overrides the default agent
- codex wrapper: `/home/simon/.local/bin/codex-acp-oauth` (unsets API keys, calls binary directly with sandbox_permissions)
- **Post-spawn required:** `acpx codex set-mode full-access --session <key>` before sending work
- Permission config: `permissionMode=approve-all`, `nonInteractivePermissions=deny`

## Models & Aliases
- **opus** → anthropic/claude-opus-4-6
- **sonnet** → anthropic/claude-sonnet-4-6
- **gpt** → openai-codex/gpt-5.2
- **codex** → openai-codex/gpt-5.3-codex


## Model Switch Helpers (ACP)
- Codex medium: /home/simon/.openclaw/workspace-builder/scripts/set-model-codex.sh
- Claude Opus 4.6 thinking: /home/simon/.openclaw/workspace-builder/scripts/set-model-claude.sh
- Pattern: run one helper first, then spawn ACP per-task persistent session (`agentId: codex`, `mode: session`, `thread: true`) when Builder needs mid-task dialogue/steering.

## Auth (Builder-relevant)
- **Builder model (gpt-5.3-codex / claude-opus-4-6):** OpenClaw gateway OAuth profiles (`openai-codex:default`, `anthropic:default`)
- **ACP codex agent:** ChatGPT Plus OAuth via `~/.acpx/config.json` `auth.chatgpt` token. NOT API key.
- **OpenCode (if used):** OAuth via `~/.local/share/opencode/auth.json`
- **OpenAI API key** (`~/.codex/auth.json`): exists but NOT used for ACP codex. Only for direct API calls (e.g., app LLM_API_KEY in .dev.vars).

## Bird / X (kept for market research)
- Authenticated as **@simonhimself**
- X can block fresh VPS logins; existing cookies/session injection works
- Use for market/competitor signal collection and narrative trend checks

## Useful Rule
- For large coding tasks: one Builder orchestrator + ACP workers.
- Keep implementation commands deterministic and reproducible.
