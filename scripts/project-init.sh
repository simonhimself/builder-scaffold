#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${1:?Usage: project-init.sh <projectName>}"
WORKSPACE_ROOT="/home/simon/.openclaw/workspace-builder"
PROJECTS_ROOT="$WORKSPACE_ROOT/projects"
PROJECT_PATH="$PROJECTS_ROOT/$PROJECT_NAME"
TEMPLATE_TASKS="$PROJECTS_ROOT/_templates/TASKS.md"
TEMPLATE_PRD="$PROJECTS_ROOT/_templates/PRD.md"
TEMPLATE_SPEC="$PROJECTS_ROOT/_templates/SPEC.md"
INSTALL_HOOKS="$WORKSPACE_ROOT/scripts/install-hooks.sh"
READY_SCRIPT="$WORKSPACE_ROOT/scripts/project-ready.sh"

mkdir -p "$PROJECT_PATH"

if [ ! -d "$PROJECT_PATH/.git" ]; then
  git -C "$PROJECT_PATH" init -q
fi

if [ ! -f "$PROJECT_PATH/TASKS.md" ]; then
  if [ -f "$TEMPLATE_TASKS" ]; then
    cp "$TEMPLATE_TASKS" "$PROJECT_PATH/TASKS.md"
  else
    cat > "$PROJECT_PATH/TASKS.md" <<"TASKS"
# TASKS.md

## Active Tasks

| ID | Title | Status | Owner | Notes |
|---|---|---|---|---|

## Task Detail Blocks
TASKS
  fi
fi

if [ ! -f "$PROJECT_PATH/PRD.md" ]; then
  if [ -f "$TEMPLATE_PRD" ]; then
    cp "$TEMPLATE_PRD" "$PROJECT_PATH/PRD.md"
  else
    cat > "$PROJECT_PATH/PRD.md" <<"PRD"
# PRD.md

## Vision

## Scope

### In scope

### Out of scope

## Feature Requirements

## Non-Functional Requirements

## Success Metrics

## Risks and Open Questions
PRD
  fi
fi

if [ ! -f "$PROJECT_PATH/SPEC.md" ]; then
  if [ -f "$TEMPLATE_SPEC" ]; then
    cp "$TEMPLATE_SPEC" "$PROJECT_PATH/SPEC.md"
  else
    cat > "$PROJECT_PATH/SPEC.md" <<"SPEC"
# SPEC.md

## Objective

## Current-State Findings

## Target Architecture

## Workstreams

## Acceptance and Test Strategy

## Exit Criteria
SPEC
  fi
fi

if [ -x "$INSTALL_HOOKS" ]; then
  "$INSTALL_HOOKS" "$PROJECT_PATH" >/dev/null
fi

READY_JSON="$($READY_SCRIPT scaffold "$PROJECT_PATH" || true)"
if ! echo "$READY_JSON" | jq -e ".passed == true" >/dev/null 2>&1; then
  echo "$READY_JSON"
  exit 1
fi

jq -n --arg project "$PROJECT_NAME" --arg projectPath "$PROJECT_PATH" --argjson ready "$READY_JSON" \
  "{passed:true, project:\$project, projectPath:\$projectPath, ready:\$ready, summary:\"project initialized\"}"
