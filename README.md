# Builder Scaffold

Portable scaffolding for the Blue Builder orchestration system.

## What this repo contains
- Core orchestration contracts (`AGENTS.md`, `HEARTBEAT.md`, `TOOLS.md`, `BOOTSTRAP.md`)
- Deterministic automation scripts (`scripts/*.sh`)
- Project planning templates (`projects/_templates/*.md`)
- Project planning examples (`projects/examples/*`)
- Runtime state contract docs and schemas (`documentation/`, `state/schemas/`, `state/fixtures/`)

## What this repo intentionally excludes
- Runtime state files (`active-tasks.json`, `task-events.jsonl`)
- Personal memory/session files
- Secrets/auth tokens
- Project implementation code

## Bootstrap flow
1. Clone this repo.
2. Copy contents into your own workspace root.
3. Run `bash scripts/project-init.sh <projectName>` for a new project.
4. Use the workflow: banter -> PRD -> SPEC -> TASKS -> BUILD -> SYNC.

## Update from source workspace
If this scaffold is maintained from `/home/simon/.openclaw/workspace-builder`, sync curated files and commit updates here.
