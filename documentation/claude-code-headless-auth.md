# Claude Code Headless Auth (Max Subscription on VPS)

## Problem

Claude Code OAuth login requires a browser. Headless VPS has no browser.
`claude auth login` opens a URL → polls Anthropic servers → never completes on headless.

## Solution: Credential Transfer from Laptop

On macOS, Claude Code stores OAuth tokens in the **macOS Keychain**, not in `~/.claude.json`.
The `.claude.json` file only has account metadata — the actual tokens are in keychain.

### Steps

1. **Export credentials from laptop keychain:**
```bash
security find-generic-password -s "Claude Code-credentials" -w
```
This outputs a JSON blob with `claudeAiOauth` containing `accessToken`, `refreshToken`, `expiresAt`, etc.

2. **Transfer to VPS (don't paste in chat — tokens are sensitive):**
```bash
security find-generic-password -s "Claude Code-credentials" -w | \
  ssh simon@openclaw-vps.tail084988.ts.net 'cat > /tmp/claude-creds.txt'
```

3. **Merge into VPS `.claude.json`:**
```python
import json

with open('/home/simon/.claude.json') as f:
    config = json.load(f)

with open('/tmp/claude-creds.txt') as f:
    creds = json.load(f)

config.update(creds)

with open('/home/simon/.claude.json', 'w') as f:
    json.dump(config, f, indent=2)
```

4. **Clean up and verify:**
```bash
rm /tmp/claude-creds.txt
npx @anthropic-ai/claude-code@latest auth status
# Should show: loggedIn: true, authMethod: oauth_token
```

### Token Refresh

If tokens expire, repeat steps 1-4. The laptop's Claude Code app refreshes tokens automatically via keychain.

## What Didn't Work

| Approach | Why it failed |
|----------|--------------|
| `claude auth login` on VPS | No browser to complete OAuth redirect |
| SSH port forwarding (`ssh -L 8080:localhost:8080`) | Redirect goes to `platform.claude.com`, not localhost |
| `CLAUDE_CODE_OAUTH_TOKEN` env var | Wrong scope — `sk-ant-oat01-*` tokens lack `user:profile` scope |
| Copying only `~/.claude.json` from laptop | Tokens are in macOS Keychain, not the JSON file |
| Browser-based code flow (paste code into terminal) | CLI polls server, doesn't accept stdin input |

## Config Notes

- No need for `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` in env vars
- Auth lives in `~/.claude.json` under `claudeAiOauth` key
- ACP uses this automatically: `sessions_spawn(runtime: "acp", agentId: "claude")`
- Uses Max subscription quota (not API billing)

## Date

2026-03-02 — tested and verified on clawdbot-ubuntu-4gb-nbg1-1
