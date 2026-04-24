# SPEC.md — SMB Scheduler Customer Readiness

**Date:** 2026-03-01  
**Owner:** Blue Builder (orchestrator) + ACP Codex workers (implementation)

## 1) Objective

Move SMB Scheduler from "codebase with strong internals" to "customer-usable SaaS" with:

1. secure production operation,
2. reliable end-to-end booking/admin UX,
3. Cloudflare-first deployment,
4. business subscription billing (businesses pay to use platform).

## 2) Current-State Findings (Validated)

Critical launch blockers identified in code:

- Production auth bootstrap gap (no valid first-admin path)
- CORS configured for localhost only
- SQL mismatch: `appointments.deleted_at` referenced but column missing
- Unsafe demo/development affordances still exposed in admin UX/API
- No business self-onboarding flow
- No SaaS billing implementation
- Email provider path not production-ready by default

## 3) Target Architecture (Launch)

### Runtime/Data (Cloudflare-first)
- API: Cloudflare Workers (Hono)
- DB: Cloudflare D1
- Cache/idempotency/rate-limits: Cloudflare KV
- Async notifications: Cloudflare Queues when enabled; safe fallback path preserved
- Frontends: Cloudflare Workers + Static Assets (`web`, `admin`) — `[assets]` binding with `not_found_handling = "single-page-application"` (migrated from Cloudflare Pages on 2026-03-02)
- Optional assets: R2 for binary media (defer unless needed in launch path)

### Billing Model
- Stripe Billing (subscriptions)
- No end-customer checkout in booking flow
- Business-level subscription entities linked to `businesses` table

## 4) Workstreams

## WS-A — Launch Safety & Production Baseline
Scope:
- CORS env-driven allowlist
- Auth bootstrap for first admin
- Remove exposed demo credentials in UI
- Gate/remove demo-seed endpoint from production
- Add migration for `appointments.deleted_at` (or remove invalid filters where not needed)
- Fix timezone-safe email date/time rendering

Acceptance:
- Production tenant can log in without dev shortcuts
- No localhost-only CORS assumptions
- Reminder/dashboard SQL paths execute without schema errors
- No demo creds displayed in admin login

Test strategy:
- API route unit/integration tests for bootstrap/auth/cors behavior
- Migration apply + smoke query
- Existing unit/e2e suite remains green

## WS-B — End-to-End UX Correctness
Scope:
- Preserve tenant slug routing in customer actions (book again, back links)
- Resolve stale/staff assignment edge cases in booking flow
- Validate booking conflict behavior when staff is optional
- Admin token-expiry/session UX hardening

Acceptance:
- Customer remains in the right tenant route across full flow
- No double-booking path from optional-staff edge case
- Expired admin sessions recover cleanly

Test strategy:
- Playwright flow tests per slug route
- Booking conflict regression tests
- Auth/session UI tests

## WS-C — Onboarding & Access to Product
Scope:
- Business signup API + first admin creation
- Onboarding UI (business profile, initial services/staff/schedule)
- Initial status page for setup completion

Acceptance:
- New business can self-create account and reach functional dashboard
- Booking page works for newly created business slug

Test strategy:
- API integration tests for registration + uniqueness checks
- E2E onboarding path test

## WS-D — SaaS Billing (Businesses pay for platform)
Scope:
- Plan model + business subscription state
- Stripe Checkout session creation
- Stripe webhook processing (idempotent)
- Billing portal in admin settings
- Access control based on subscription status

Acceptance:
- Trial -> active subscription lifecycle works
- Webhooks reliably update business state
- Billing actions available from admin settings

Test strategy:
- Contract tests for billing state transitions
- Webhook signature/idempotency tests
- E2E sandbox checkout smoke test

## 5) Delivery Model

Builder protocol:
- Builder owns plan, quality gate, integration, and release decisions.
- ACP Codex workers execute scoped tasks with explicit acceptance/tests.
- One active BUILD slice at a time from `TASKS.md`.

Worker return contract (enforced):
- scope completed
- files changed
- tests updated/written
- checks run + concise evidence
- commit hash (or explicit no-commit reason)
- unresolved risks/todos

## 6) Definition of Customer-Usable (Launch Exit)

All must be true:
1. New business can register and become operational without manual DB surgery.
2. Business can complete end-to-end booking and admin management flows on production infra.
3. Security baseline passes (no demo shortcuts, safe auth/session behavior, CORS+secrets correct).
4. Transactional email works in deployed environment.
5. SaaS billing for businesses is active (trial + paid lifecycle).
6. Required tests pass with documented evidence.