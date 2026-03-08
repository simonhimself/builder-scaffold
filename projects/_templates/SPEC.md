# SPEC.md - <Project Name>

**Version:** 0.1
**Date:** YYYY-MM-DD
**Owner:** Blue Builder
**Status:** Draft
**Depends on:** PRD.md

---

## 1) Objective

Translate PRD scope into an executable technical plan with clear acceptance and tests.

## 2) Current-State Findings (Validated)

- Existing assets/repo state:
- Known constraints:
- Known blockers:

## 3) Target Architecture

### Runtime and deployment
- Platform/runtime:
- Data/storage:
- Queue/background processing:
- Environment strategy (dev/staging/prod):

### System boundaries
- External integrations:
- Auth/security boundaries:
- Data ownership boundaries:

## 4) Workstreams

## WS-A - <Name>
Scope:
- 

Acceptance:
- 

Test strategy:
- 

## WS-B - <Name>
Scope:
- 

Acceptance:
- 

Test strategy:
- 

## WS-C - <Name>
Scope:
- 

Acceptance:
- 

Test strategy:
- 

## 5) Cross-Cutting Requirements

- Observability/monitoring:
- Error handling and retries:
- Data migration/backfill strategy:
- Security controls:
- Performance/cost guardrails:

## 6) Delivery Model

- PLAN -> BUILD -> SYNC
- One BUILD slice at a time from TASKS.md
- ACP workers implement scoped slices; Builder verifies and closes

## 7) Definition of Done / Exit Criteria

All must be true:
1. Workstream acceptance criteria are met.
2. Required tests pass with evidence.
3. `verify.sh` passes for the project.
4. TASKS detail blocks capture final status, commit, and verification evidence.

## 8) Task Extraction Guidance

When generating TASKS.md:
- Create task IDs mapped to workstreams (e.g., WS-A -> T001-T00N).
- Each task must include explicit acceptance criteria, required tests, verification plan, and evidence placeholder.
- Keep tasks independently verifiable and small enough for one BUILD slice.

---

## Optional Appendix (Only if needed)

Include only when necessary for implementation clarity:
- Data schema details
- API contracts
- Infra/config snippets
- Cost model details
