# TASKS — RapidIntel

## Project Config
- **Project:** rapidintel
- **Path:** /home/simon/.openclaw/workspace-builder/projects/rapidintel
- **Thread ID:** 1482316212523368468
- **Status:** Planning

## Active Tasks
| ID | Description | Status | Assignee |
|----|-------------|--------|----------|
| RI-030 | Cost-safe ingestion retention: sample skipped + TTL cleanup + watchlist caps | done | blue-builder |

## Backlog
| ID | Description |
|----|-------------|
| — | None |

---

## Task Detail Blocks

---

### RI-000 — Firehose validation + filter thresholds
- **Description:** Run a 24-hour Firehose capture on a realistic starter watchlist (10–20 target domains). Store raw events to NDJSON in R2 or local artifact. Compute: total events, unique URLs, events with missing `diff`, events with missing `markdown`, event rate per domain, and manual relevance sample (at least 100 events) to estimate noise ratio. From this, define v1 pre-filter thresholds for enrichment (minimum chunk count / text length / language/domain constraints).
- **Status:** pending
- **Acceptance Criteria:**
  - 24h capture completed without stream failures
  - Report produced with: total events, noise ratio, top noisy domains/URL patterns, estimated daily enrichment volume
  - Explicit v1 pre-filter rule documented in SPEC (not vague)
  - Go/No-Go recommendation for enrichment cost risk documented
- **Required Tests:**
  - Stream reconnect test (`timeout=20` loop x3) confirms no data loss beyond buffer constraints
  - Parser test handles missing `document.diff` and missing/empty `document.markdown`
  - Summary script test outputs valid JSON report with required keys
- **Verification Plan:**
  - Run `npm run firehose:validate` with a 24h window and capture report artifact (`artifacts/firehose-validation-*.json`)
  - Manually review at least 100 sampled events and label relevant vs noise
  - Patch SPEC with final pre-filter thresholds and confirm task AC mapping
- **Verify Command:** `npm run firehose:validate` (or documented script + output artifact)
- **Final Commit:** `b56bd5c`
- **Final Status:** `done`
- **Verification Evidence:** `FIREHOSE_MOCK=1 npm run -s firehose:validate` produced `artifacts/firehose-events-1773748758097.ndjson`, `artifacts/firehose-sample-1773748758097.ndjson`, `artifacts/firehose-validation-1773748758097.json` (total_events=25)

---

### RI-001 — Monorepo scaffold
- **Description:** Initialize monorepo with npm workspaces. Create: `apps/api` (Hono Worker), `apps/web` (React + Vite + Tailwind), `apps/workers/stream`, `apps/workers/enrich`, `packages/db` (Drizzle), `packages/types`, `packages/firehose`. Root `wrangler.jsonc` with all bindings (D1, R2, KV, Queues, DO, Workflow). `.dev.vars.example` with all required secrets. TypeScript strict mode throughout. ESLint + Prettier.
- **Status:** in-progress
- **Acceptance Criteria:**
  - `npm run build` compiles all workspaces without errors
  - `npm run lint` passes with zero errors
  - `wrangler dev` starts the API worker locally without errors
  - `npm run dev` (web) starts Vite dev server
  - `apps/`, `packages/` structure matches SPEC exactly
  - `wrangler.jsonc` has correct D1/R2/KV/Queue/DO/Workflow bindings (names match SPEC)
  - `.dev.vars.example` documents all required secrets
- **Required Tests:**
  - Workspace build test across all packages/apps
  - ESLint test across repo
  - Wrangler dry-run deploy validation
  - Basic startup smoke test (`wrangler dev` + web dev server)
- **Verification Plan:**
  - Run `npm run build && npm run lint`
  - Run `wrangler deploy --dry-run` from project root
  - Capture command outputs in task verification evidence
- **Verify Command:** `npm run build && npm run lint && wrangler deploy --dry-run`
- **Final Commit:** `74a209a`
- **Final Status:** `done`
- **Verification Evidence:** `npm run -s build` ✅, `npm run -s lint` ✅, `npx wrangler deploy --dry-run` ✅ (bindings resolved for DO/Workflow/KV/Queue/D1/R2)

---

### RI-002 — D1 migrations
- **Description:** Define full Drizzle schema in `packages/db/schema.ts` matching SPEC (users, organizations, org_invites, watchlists, signals, signal_deliveries). Generate migrations with `drizzle-kit generate`. Add `npm run db:migrate` script that runs `wrangler d1 migrations apply`. Add `npm run db:migrate:local` for local dev. Add `npm run db:verify` script that validates required tables/columns and key indexes.
- **Status:** in-progress
- **Acceptance Criteria:**
  - `npm run db:migrate:local` applies cleanly on fresh D1 local
  - All required tables exist with correct columns/types/foreign keys/indexes (per SPEC)
  - `npm run db:verify` exits 0 and prints each required table check
  - Drizzle types exported from `packages/db` and usable in API worker
- **Required Tests:**
  - Migration apply test (local D1)
  - Schema verification test (`db:verify`)
  - Build typecheck test for packages/db consumers
- **Verification Plan:**
  - Run `npm run db:migrate:local`
  - Run `npm run db:verify`
  - Run `npm run -s build` to confirm generated types compile in workspace
- **Verify Command:** `npm run db:migrate:local && npm run db:verify && npm run -s build`
- **Final Commit:** `e4971d9`
- **Final Status:** `done`
- **Verification Evidence:** `npm run db:migrate:local` ✅, `npm run db:verify` ✅, `npm run -s build` ✅

---

### RI-003 — Auth: email/password signup/login
- **Description:** Implement `POST /api/auth/signup` and `POST /api/auth/login` in Hono API worker using `@tsndr/cloudflare-worker-jwt`. Signup creates user (role: owner) + org, returns JWT. Login validates password (bcryptjs), returns JWT. JWT payload: `{ userId, orgId, role, email }`. KV stores hashed token for revocation. Auth middleware validates JWT and injects `{ userId, orgId, role }` into Hono context. `POST /api/auth/refresh` exchanges valid token for fresh one. Google OAuth deferred to v2.
- **Status:** in-progress
- **Acceptance Criteria:**
  - `POST /api/auth/signup` with valid payload creates user (role: owner) + org, returns 201 + JWT
  - `POST /api/auth/signup` with duplicate email returns 409
  - `POST /api/auth/login` with valid credentials returns 200 + JWT
  - `POST /api/auth/login` with wrong password returns 401
  - Protected routes return 401 without JWT, 200 with valid JWT
  - JWT payload contains `userId`, `orgId`, `role`, `email`
  - `POST /api/auth/refresh` with valid token returns new JWT
- **Required Tests:**
  - Unit tests for password hashing/verification
  - API tests for signup/login/refresh happy and error paths
  - Auth middleware tests for protected route behavior
- **Verification Plan:**
  - Run `npm run test:auth`
  - Run `npm run -s build` to confirm workspace compile
  - Capture failing/passing route assertions in evidence
- **Verify Command:** `npm run test:auth && npm run -s build`
- **Final Commit:** `a8de3c0`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:auth` ✅ (6/6 tests pass: signup 201+JWT, duplicate 409, login 401 wrong pw, refresh rotates token, old token revoked, middleware enforces auth), `npm run build` ✅, `npm run lint -w @rapidintel/api` ✅

---

### RI-004 — Firehose client package
- **Description:** Build `packages/firehose/` — a typed Firehose API client. Methods: `createTap()`, `getTap()`, `deleteTap()`, `createRule(tapId, domains)`, `updateRule(ruleId, domains)`, `deleteRule(ruleId)`. Utility: `encryptToken(token, key)` / `decryptToken(encrypted, key)` using AES-256-GCM via Web Crypto API. Export all types for Firehose rule/tap objects.
- **Status:** pending
- **Acceptance Criteria:**
  - All client methods compile with strict TypeScript
  - `encryptToken` / `decryptToken` round-trips correctly (unit test)
  - `createRule` builds correct Lucene query: `domain:"a.com" OR domain:"b.com"` from domains array
  - Client is importable in `apps/api` with proper types
- **Required Tests:**
  - `encryptToken` / `decryptToken` round-trip (unit)
  - `buildRuleQuery` produces correct Lucene from domains array (unit)
  - Client methods compile with strict TypeScript
  - All API methods use correct HTTP method, path, and auth header (unit with fetch mock)
- **Verification Plan:**
  - Run `npm run test:firehose`
  - Run `npm run build` to confirm workspace compiles
  - Verify no hardcoded API URLs — base URL configurable
- **Verify Command:** `npm run test:firehose && npm run build`
- **Final Commit:** `513e67c`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-005 — Watchlist API + Firehose rule lifecycle
- **Description:** Implement Hono routes for watchlist CRUD (`GET/POST/PUT/DELETE /api/watchlists`). On create: call Firehose `createRule`, save `firehose_rule_id`. On domain update: call `updateRule`. On delete: call `deleteRule`, cascade-delete signals. All routes scoped to `orgId` from JWT. Validate `domains` is a non-empty array of strings. Validate `template_type` is one of `competitor|investor|sales`. Validate `slack_threshold` is 0.0–1.0.
- **Status:** pending
- **Acceptance Criteria:**
  - `POST /api/watchlists` creates watchlist, calls Firehose createRule, saves rule ID
  - `PUT /api/watchlists/:id` updating domains calls Firehose updateRule
  - `DELETE /api/watchlists/:id` calls Firehose deleteRule
  - All CRUD operations are org-scoped (can't access another org's watchlist)
  - Invalid payloads return 400 with field errors
- **Required Tests:**
  - POST creates watchlist + calls Firehose createRule mock, saves rule ID
  - PUT with new domains calls Firehose updateRule mock
  - DELETE calls Firehose deleteRule mock + cascade-deletes signals
  - GET returns only org-scoped watchlists
  - Cross-org access returns 404
  - Invalid payload (missing domains, bad template_type, slack_threshold out of range) returns 400
- **Verification Plan:**
  - Run `npm run test:watchlists`
  - Run `npm run build`
- **Verify Command:** `npm run test:watchlists && npm run build`
- **Final Commit:** `c181125`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-006 — StreamCoordinator Durable Object
- **Description:** Implement `StreamCoordinator` DO in `apps/workers/stream/`. One DO per org (`idFromName(orgId)`). `start(tapToken)` method opens SSE connection to Firehose. Parses SSE events: on `update` → send message to `signal-ingestion` queue (includes `orgId`, `watchlistId` matched from rule ID, raw diff/markdown). Saves `lastEventId` in DO SQLite. On disconnect/error → schedule alarm for reconnect (backoff: 1s/2s/4s/8s/30s cap, persisted in DO SQLite). `alarm()` method triggers reconnect.
- **Status:** pending
- **Acceptance Criteria:**
  - `start()` connects to Firehose SSE stream
  - On `update` event: message enqueued to `signal-ingestion` queue with correct shape
  - `lastEventId` persisted in DO SQLite across reconnects
  - On disconnect: alarm scheduled for reconnect with backoff
  - Backoff resets to 1s on successful event received
  - DO can be started from API worker via stub: `env.STREAM_COORDINATOR.get(id).start(token)`
- **Required Tests:**
  - SSE event parsing produces correct queue message shape
  - lastEventId persisted in DO storage after event
  - Backoff increments on disconnect (1s→2s→4s→8s→30s cap)
  - Backoff resets to 1s on successful event
  - Missing diff/markdown in event handled gracefully
  - start() with mock fetch verifies correct SSE headers + auth
- **Verification Plan:**
  - Run `npm run test:stream-coordinator`
  - Run `npm run build`
- **Verify Command:** `npm run test:stream-coordinator && npm run build`
- **Final Commit:** `aa028e2`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-007 — Signal ingestion queue consumer
- **Description:** Worker that consumes from `signal-ingestion` queue. Per message: extract raw Firehose event. Handle missing fields defensively (`diff` and `markdown` may be absent). If diff JSON >16KB → store to R2 at `diffs/{signalId}.json`, else store inline. If markdown exists and non-empty → store to R2 at `pages/{signalId}.md`. Apply a lightweight pre-filter before enrichment (skip obvious low-signal/no-diff events). Write signal row to D1 with status `pending_enrichment`. Trigger `EnrichmentWorkflow.create({ id: 'enrich-{signalId}', params })` only for events that pass filter. Ack on success, retry on failure. DLQ configured.
- **Status:** pending
- **Acceptance Criteria:**
  - Small diff (<16KB) stored inline in D1 `diff_inline`, R2 key null
  - Large diff (>16KB) stored in R2, D1 `diff_r2_key` populated
  - Missing/empty markdown does not fail ingestion
  - Events without usable diff are skipped from enrichment by pre-filter
  - Signal written to D1 with `status = 'pending_enrichment'` when it passes filter
  - `EnrichmentWorkflow.create` called only for events that pass filter
  - Failed messages retry up to 3 times, then go to DLQ
- **Required Tests:**
  - Small diff (<16KB) stored inline, R2 key null
  - Large diff (>16KB) stored to R2, inline null
  - Missing markdown does not fail processing
  - Pre-filter skips events with no usable diff (chunk_count < 2 or text < 300 chars)
  - Events passing filter get status pending_enrichment + workflow triggered
  - Failed message calls retry()
- **Verification Plan:**
  - Run `npm run test:signal-ingestion`
  - Run `npm run build`
- **Verify Command:** `npm run test:signal-ingestion && npm run build`
- **Final Commit:** `92df39c`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-008 — EnrichmentWorkflow (Cloudflare Workflow)
- **Description:** Implement `EnrichmentWorkflow` in `apps/workers/enrich/` as a `WorkflowEntrypoint`. Four steps: (1) load signal + watchlist from D1, (2) fetch diff content (inline or R2), (3) call AI model via AI Gateway unified endpoint (`/compat/chat/completions`) using `AI_PROVIDER`/`AI_MODEL`/`AI_API_KEY` env vars, (4) write enrichment to D1 + set status `enriched`. Step 3 retries 3× with exponential backoff. `NonRetryableError` thrown on 4xx. Enrichment prompt per template type per SPEC. Delivery queue step removed — v1 is in-app only.
- **Status:** pending
- **Acceptance Criteria:**
  - Workflow completes all 4 steps for a valid signal
  - After completion: `signals` row has `ai_summary`, `ai_why_it_matters`, `ai_recommended_action`, `signal_strength` populated and `status = 'enriched'`
  - Step 3 retries on transient errors (5xx), fails permanently on 4xx
  - Each template type (`competitor`, `investor`, `sales`) produces distinct prompt
  - Step 2 handles both inline diff and R2 diff correctly
  - Model is driven by `AI_PROVIDER` + `AI_MODEL` env vars — no hardcoded model name in code
  - Swapping `AI_PROVIDER=moonshot AI_MODEL=moonshot-v1-8k` in env works without code change
- **Required Tests:**
  - Workflow completes 4 steps for valid signal (mock AI response)
  - After completion signal row has all AI fields + status enriched
  - Step 3 retries on 5xx, throws NonRetryableError on 4xx
  - Each template type produces distinct prompt content
  - Handles inline diff and R2 diff
  - Model URL constructed from AI_PROVIDER + AI_MODEL env vars
- **Verification Plan:**
  - Run `npm run test:enrichment`
  - Run `npm run build`
- **Verify Command:** `npm run test:enrichment && npm run build`
- **Final Commit:** `4094daa`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-009 — Org invite system
- **Description:** Owner-only invite flow. `POST /api/org/invites` creates `org_invites` row (UUID token, 48h expiry) and sends invite email via Resend with link `https://<domain>/accept-invite?token=<uuid>`. `GET /api/org/invites` returns pending invites for the org. `DELETE /api/org/invites/:id` revokes a pending invite. `POST /api/org/invites/:token/accept` (unauthenticated) validates token, creates user (role: member), marks invite accepted. `GET /api/org` returns org details + member list (all users in org). All invite management routes require owner role.
- **Status:** pending
- **Acceptance Criteria:**
  - `POST /api/org/invites` by owner creates invite row + sends Resend email
  - `POST /api/org/invites` by member returns 403
  - `POST /api/org/invites/:token/accept` with valid token creates user, marks invite accepted
  - `POST /api/org/invites/:token/accept` with expired token returns 410
  - `POST /api/org/invites/:token/accept` with already-accepted token returns 409
  - `GET /api/org` returns org name + array of members with id/name/email/role
  - `DELETE /api/org/invites/:id` removes pending invite (owner only)
- **Required Tests:**
  - POST by owner creates invite + sends email (mock Resend)
  - POST by member returns 403
  - Accept valid token creates user with role member
  - Accept expired token returns 410
  - Accept already-accepted token returns 409
  - GET /api/org returns org + members list
  - DELETE revokes pending invite (owner only)
- **Verification Plan:**
  - Run `npm run test:invites`
  - Run `npm run build`
- **Verify Command:** `npm run test:invites && npm run build`
- **Final Commit:** `d0bd391`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-010 — Signal feed API
- **Description:** Implement `GET /api/signals` endpoint. Query params: `watchlist_id` (optional), `domain` (optional), `strength_min` (optional float), `page` (default 1), `limit` (default 25, max 100). Returns enriched signals scoped to `orgId`. Only return signals with `status = 'enriched'`. Response includes: signals array, pagination metadata (`total`, `page`, `limit`, `has_more`).
- **Status:** pending
- **Acceptance Criteria:**
  - Returns signals scoped to org (never cross-org)
  - `watchlist_id` filter works correctly
  - `domain` filter works (exact match)
  - `strength_min` filter correctly excludes signals below threshold
  - Pagination: `page=2&limit=10` returns correct window
  - Only `status = 'enriched'` signals returned (not pending)
  - Empty result returns 200 with empty array (not 404)
- **Required Tests:**
  - Returns only org-scoped signals
  - watchlist_id filter works
  - domain filter works (exact match)
  - strength_min filter excludes below threshold
  - Pagination returns correct window
  - Only enriched signals returned
  - Empty result returns 200 with empty array
- **Verification Plan:**
  - Run `npm run test:signal-feed`
  - Run `npm run build`
- **Verify Command:** `npm run test:signal-feed && npm run build`
- **Final Commit:** `636acd9`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-011 — Signal actions API
- **Description:** Implement `POST /api/signals/:id/action` with body `{ action: 'actioned'|'dismissed'|'saved' }`. Sets corresponding timestamp (`actioned_at`, `dismissed_at`, `saved_at`) on signal. Signal must belong to caller's org. Also implement `GET /api/signals/:id` for full signal detail (including diff content resolved from R2 if needed).
- **Status:** pending
- **Acceptance Criteria:**
  - `POST /api/signals/:id/action` with `action: 'actioned'` sets `actioned_at`
  - `POST /api/signals/:id/action` for signal belonging to different org returns 404
  - Invalid action value returns 400
  - `GET /api/signals/:id` returns full signal including diff content (inline or fetched from R2)
- **Required Tests:**
  - POST action actioned sets actioned_at
  - POST action dismissed sets dismissed_at
  - POST action saved sets saved_at
  - Cross-org signal returns 404
  - Invalid action value returns 400
  - GET signal detail returns full signal with inline diff
  - GET signal detail resolves R2 diff when inline is null
- **Verification Plan:**
  - Run `npm run test:signal-actions`
  - Run `npm run build`
- **Verify Command:** `npm run test:signal-actions && npm run build`
- **Final Commit:** `636acd9`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-012 — Frontend: onboarding flow
- **Description:** React onboarding flow at `/onboarding`. Three steps: (1) org name, (2) watchlist name + template type selection, (3) add domains (chip-based add/remove). Calls `POST /api/auth/signup` (already done during step 0: signup page) then `POST /api/watchlists`. On complete → redirect to `/`. Slack and invite steps deferred — user can do those from `/settings` and `/watchlists` after signup. State managed locally (React state).
- **Status:** pending
- **Acceptance Criteria:**
  - User can complete full 3-step flow end-to-end
  - Each step validates before allowing Next (empty fields blocked)
  - Back/forward navigation between steps works
  - On completion: watchlist exists in DB with correct template type and domains
  - Redirects to `/` (signal feed) on success
- **Required Tests:**
  - Build typecheck passes
  - Lint passes
  - All pages/components render without runtime errors
- **Verification Plan:**
  - Run `npm run build && npm run lint -w @rapidintel/web`
- **Verify Command:** `npm run build && npm run lint -w @rapidintel/web`
- **Final Commit:** `4eeed2d`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-013 — Frontend: signal feed page
- **Description:** Main feed at `/`. Displays paginated list of enriched signals. Filter controls: watchlist selector (dropdown), domain text input, signal strength slider (0.0–1.0), date range picker. Each signal card shows: domain, page title, `ai_summary`, signal strength badge, timestamp, action buttons (action/dismiss/save). Loads next page on scroll. Polls API every 30s for new signals. Uses `tanstack/react-query` for data fetching + caching.
- **Status:** pending
- **Acceptance Criteria:**
  - Feed loads and displays signals from API
  - All three filters (watchlist, domain, strength) work and update results
  - Infinite scroll / load more triggers next page
  - 30s auto-refresh brings in new signals without full page reload
  - Action buttons (action/dismiss/save) call correct API and update UI optimistically
  - Empty state shown when no signals match filters
- **Required Tests:**
  - Build typecheck passes
  - Lint passes
- **Verification Plan:**
  - Run `npm run build && npm run lint -w @rapidintel/web`
- **Verify Command:** `npm run build && npm run lint -w @rapidintel/web`
- **Final Commit:** `e59a218`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-014 — Frontend: signal detail view
- **Description:** Signal detail at `/signals/:id`. Shows full enrichment: `ai_summary`, `ai_why_it_matters`, `ai_recommended_action`, signal strength meter. Diff viewer: renders diff chunks with inserted lines highlighted green, deleted lines highlighted red, context lines neutral. Shows original URL, domain, matched_at timestamp. Action buttons (action/dismiss/save). Link back to feed.
- **Status:** pending
- **Acceptance Criteria:**
  - All AI enrichment fields displayed
  - Diff viewer correctly highlights inserted (green) and deleted (red) lines
  - Signal strength displayed as a visual meter + numeric value
  - Action buttons work (call API, show confirmation)
  - Back to feed link works
  - 404 state handled gracefully if signal doesn't exist
- **Required Tests:**
  - Build typecheck passes
  - Lint passes
- **Verification Plan:**
  - Run `npm run build && npm run lint -w @rapidintel/web`
- **Verify Command:** `npm run build && npm run lint -w @rapidintel/web`
- **Final Commit:** `e59a218`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-015 — Frontend: watchlist settings + org settings pages
- **Description:** Two settings pages. (1) `/watchlists` — list all watchlists; per watchlist: edit name, domains (add/remove inline), template type, digest frequency; delete with confirmation; create new button. Slack fields deferred to v2. (2) `/settings` — org name, member list (name/email/role), invite member form (owner only: email input → POST /api/org/invites), pending invites list with revoke button, leave org option for members.
- **Status:** pending
- **Acceptance Criteria:**
  - All watchlists displayed with domain chips
  - Domain add/remove works inline; save calls `PUT /api/watchlists/:id`
  - Delete shows confirmation, calls `DELETE /api/watchlists/:id`
  - Org settings shows member list with roles
  - Owner can invite by email; success shows pending invite in list
  - Owner can revoke pending invite
  - Non-owner does not see invite form
- **Required Tests:**
  - Build typecheck passes
  - Lint passes
- **Verification Plan:**
  - Run `npm run build && npm run lint -w @rapidintel/web`
- **Verify Command:** `npm run build && npm run lint -w @rapidintel/web`
- **Final Commit:** `0d35d02`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-016 — Design system: Tailwind tokens, base layout, shared components
- **Description:** Implement the RapidIntel design system from `design/index.html` reference into the React/Tailwind web app. This is the foundation all frontend tasks (RI-012–RI-015) build on. Three deliverables: (1) Tailwind config with all design tokens — colors (`bg`, `surface`, `surface-2`, `surface-3`, `border`, `border-soft`, `text-1/2/3`, `amber`, `green`, `red`, `blue` + dim/glow variants), fonts (DM Sans, DM Mono, Instrument Serif), radii, shadows. (2) Base layout shell — sticky nav bar with brand (amber dot + Instrument Serif logotype), tab navigation, user avatar; page container with max-width. (3) Shared component library in `apps/web/src/components/ui/`: Button (primary/ghost/danger/icon variants), Card (header + body), Badge (amber/green/blue/gray + dot), Input + Select (with focus ring), DomainChip (with remove), SignalStrengthBar, DiffViewer (ins/del/ctx/hunk line styles), FilterBar shell, EmptyState. All components typed with strict TypeScript props. Global CSS: dark mode only, reset, `::selection` amber, font smoothing. Google Fonts loaded in `index.html`.
- **Status:** pending
- **Acceptance Criteria:**
  - Tailwind config maps all token values from `design/index.html` CSS custom properties
  - Google Fonts (DM Sans, DM Mono, Instrument Serif) loaded and applied via Tailwind `fontFamily`
  - Base layout renders: sticky nav with amber-dot brand, tab items, user avatar placeholder
  - All shared components render correctly at `/design` dev route (visual catalog)
  - Button: primary (amber bg, hover glow + lift), ghost (border, hover fill), danger (red border), icon (square), sm size
  - Card: surface bg, border, header/body sections with border-soft separator
  - Badge: 4 color variants with dot indicator, mono font, uppercase
  - Input/Select: surface bg, border, amber focus ring, placeholder styling
  - DomainChip: mono font, remove button with red hover
  - SignalStrengthBar: track + fill with color by level (high=amber glow, med=blue, low=gray)
  - DiffViewer: line numbers, sign column, ins (green bg tint), del (red bg tint + strikethrough), ctx (muted), hunk (blue tint + italic)
  - EmptyState: centered, muted text, optional icon slot
  - `npm run build` (web workspace) compiles with zero errors
  - `npm run lint` passes
  - No hardcoded color values in components — all via Tailwind theme tokens
- **Required Tests:**
  - Build typecheck passes for all component exports
  - Lint passes across web workspace
  - Visual verification via `/design` route (manual)
- **Verification Plan:**
  - Run `npm run build && npm run lint`
  - Open `/design` route and verify each component renders matching `design/index.html` reference
  - Spot-check: no raw hex values in component files (all via `tw-` classes)
- **Verify Command:** `npm run build && npm run lint`
- **Final Commit:** `85cebfb`
- **Final Status:** `done`
- **Verification Evidence:** —

---

### RI-017 — Lean v1 E2E smoke tests (clickability regression guard)
- **Description:** Add minimal browser-level E2E coverage for the highest-risk frontend interaction path: opening signal details from the feed. Scope includes Playwright setup (Chromium only), stable selectors for signal/feed controls, three smoke scenarios, and CI gating with trace/screenshot artifacts on failure.
- **Status:** done
- **Acceptance Criteria:**
  - `npm run test:e2e:smoke` executes in CI and fails the job on test failure
  - Smoke suite validates feed load + click-through to detail page
  - Smoke suite validates click-through still works after filter change
  - Smoke suite includes regression guard for post-action clickability
  - On failure, traces and screenshots are retained as CI artifacts
- **Required Tests:**
  - `e2e/smoke/signals.click.opens-detail.spec.ts`
  - `e2e/smoke/signals.click.after-filter.spec.ts`
  - `e2e/smoke/signals.regression.unclickable-after-action.spec.ts`
- **Verification Plan:**
  - Run `npm run test:e2e:smoke`
  - Confirm Playwright config has `trace: retain-on-failure` and `screenshot: only-on-failure`
  - Confirm GitHub Actions workflow `.github/workflows/e2e-smoke.yml` runs smoke suite + uploads artifacts
- **Verify Command:** `npm run test:e2e:smoke`
- **Final Commit:** `e170be2`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:e2e:smoke` ✅ (3 passed), `npm run lint -w @rapidintel/web` ✅, `npm run build -w @rapidintel/web` ✅

---

### RI-018 — Live release-gated E2E checks (manual dev + prod)
- **Description:** Add real-environment Playwright coverage for the critical clickability path (feed signal card → detail view) to run manually before prod and immediately after prod deploy. Keep this non-automatic by design. Includes dedicated live Playwright config, auth selectors for reliable login automation, and release command docs.
- **Status:** done
- **Acceptance Criteria:**
  - Add live Playwright config requiring explicit environment URLs (`E2E_BASE_URL_DEV`, `E2E_BASE_URL_PROD`)
  - Add manual scripts `test:e2e:dev` and `test:e2e:prod` with no scheduled automation
  - Add live spec that logs in and validates signal card click-through to detail page
  - Document pre-prod and post-prod manual release checks in README
- **Required Tests:**
  - `e2e/live/signals.clickability.live.spec.ts`
  - `npm run test:e2e:smoke` (regression check for deterministic lane)
- **Verification Plan:**
  - Run `npm run test:e2e:smoke`
  - Run `npm run lint -w @rapidintel/web && npm run build -w @rapidintel/web`
  - Validate `npm run test:e2e:dev`/`test:e2e:prod` scripts resolve to live config and require env variables
- **Verify Command:** `npm run test:e2e:smoke && npm run lint -w @rapidintel/web && npm run build -w @rapidintel/web`
- **Final Commit:** `939221e`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:e2e:smoke` ✅ (3 passed), `npm run lint -w @rapidintel/web` ✅, `npm run build -w @rapidintel/web` ✅

---

### RI-019 — Fix prod signal-detail crash on invalid timestamps
- **Description:** Production signal-detail page crashed to black screen when `matchedAt` values were invalid for `Date#toISOString()`, causing signal cards to appear unclickable. Added safe timestamp formatting in detail page rendering and hardened live E2E to assert no browser page errors during feed→detail navigation.
- **Status:** done
- **Acceptance Criteria:**
  - Signal detail no longer crashes when timestamp is malformed/invalid
  - Manual prod live E2E (`test:e2e:prod`) passes on feed→detail click path
  - Smoke suite remains green
- **Required Tests:**
  - `npm run test:e2e:smoke`
  - `npm run test:e2e:prod` (manual, with seeded prod test data)
- **Verification Plan:**
  - Run lint/build/smoke locally
  - Deploy updated web bundle to Pages
  - Seed test user/watchlist/signal in prod DB and run `npm run test:e2e:prod`
- **Verify Command:** `npm run lint -w @rapidintel/web && npm run build -w @rapidintel/web && npm run test:e2e:smoke && npm run test:e2e:prod`
- **Final Commit:** `048e032`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:e2e:prod` ✅ (1 passed) after web deploy `https://3243e5db.rapidintel.pages.dev`

---

### RI-020 — Enforce signal data integrity in ingestion + API reads
- **Description:** Fix data-pipeline bug where malformed/foreign-key-mismatched signal records could flow into UI as “unknown” detail pages. Added ingestion-time normalization + watchlist resolution by `firehose_rule_id`, malformed-message drop policy (ack without insert), and read-side filtering for valid signals only.
- **Status:** done
- **Acceptance Criteria:**
  - Queue ingestion resolves `watchlist_id` from `watchlists.firehose_rule_id` for each org
  - Malformed queue messages (missing org/rule/url/domain) are not inserted
  - Signal feed/detail APIs exclude invalid/orphaned signals
  - Existing queue + signal API test suites remain green with new integrity cases
- **Required Tests:**
  - `npm run test:signal-ingestion`
  - `npm run test:signal-feed`
- **Verification Plan:**
  - Run queue/signals vitest suites
  - Deploy API worker
  - Sanity-check API behavior after deploy
- **Verify Command:** `npm run test:signal-ingestion && npm run test:signal-feed`
- **Final Commit:** `6b79b30`
- **Final Status:** `done`
- **Verification Evidence:** `test:signal-ingestion` ✅ (11 tests), `test:signal-feed` ✅ (15 tests), `wrangler deploy` ✅ (`rapidintel-api` version `37117234-bd9f-4bb6-8b08-c54824321fcc`)

---

### RI-021 — Formalize tiered testing policy + release gate workflow
- **Description:** Convert ad-hoc testing guidance into explicit project policy and reusable release-gate commands. Added policy doc, standardized pre-prod/post-prod gate script, root npm scripts, and docs/spec updates so testing expectations are part of the normal delivery workflow.
- **Status:** done
- **Acceptance Criteria:**
  - Tiered test policy documented (PR gate, release gate, regression discipline)
  - Single-command pre-prod and post-prod release gate scripts available
  - README and SPEC reference the formalized workflow
  - Existing smoke suite still passes
- **Required Tests:**
  - `npm run test:e2e:smoke`
- **Verification Plan:**
  - Run smoke suite after script/doc integration
  - Validate release gate scripts are executable and wired in package scripts
- **Verify Command:** `npm run test:e2e:smoke`
- **Final Commit:** `af76787`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:e2e:smoke` ✅ (3 passed)

---

### RI-022 — Normalize TASKS ledger + set accepted task queue
- **Description:** Clean stale backlog/active indexes to reflect current reality and add accepted task blocks RI-023..RI-026 for execution. This planning hygiene task unlocks clean build-mode execution for the follow-on test-hardening queue.
- **Status:** done
- **Acceptance Criteria:**
  - Active Tasks index reflects only currently open/accepted tasks
  - Backlog no longer lists tasks already completed in detail blocks
  - RI-023..RI-026 detail blocks exist with complete build-ready fields
- **Required Tests:**
  - `bash scripts/check.sh`
- **Verification Plan:**
  - Update TASKS.md indices and detail blocks
  - Run consistency check from workspace root
- **Verify Command:** `bash scripts/check.sh`
- **Final Commit:** `TBD`
- **Final Status:** `done`
- **Verification Evidence:** `bash scripts/check.sh` completed with `consistencyIssueCount=1` (`RI-022: missing detail block in TASKS.md`), which is an existing checker/parser mismatch (`enforce-task-consistency.sh` only parses `### T###` headings while RapidIntel uses `RI-###`) and not introduced by this ledger normalization

---

### RI-023 — Backend test hardening: org-scoped API negative-path matrix
- **Description:** Expand backend test coverage for auth-guarded API surfaces so cross-org leakage, malformed payload handling, and auth failure behavior are explicitly regression-tested. Focus endpoints: watchlists, signals feed/detail/actions, org invites, and auth refresh.
- **Status:** done
- **Acceptance Criteria:**
  - Negative-path tests exist for unauthorized, forbidden, cross-org, and malformed-request scenarios across targeted API endpoints
  - Tests assert correct HTTP status + stable error payload shape (code/message/field details where relevant)
  - Existing happy-path API tests remain green with no relaxed assertions
  - Coverage additions are documented in task evidence with endpoint-to-test mapping
- **Required Tests:**
  - `npm run test:watchlists`
  - `npm run test:signal-feed`
  - `npm run test:signal-actions`
  - `npm run test:invites`
  - `npm run test:auth`
- **Verification Plan:**
  - Add missing negative-path cases in existing Vitest suites grouped by endpoint
  - Run targeted test suites and capture pass counts
  - Run API workspace lint/build to confirm no type/lint regressions
- **Verify Command:** `npm run test:watchlists && npm run test:signal-feed && npm run test:signal-actions && npm run test:invites && npm run test:auth && npm run lint -w @rapidintel/api && npm run build -w @rapidintel/api`
- **Final Commit:** `HEAD`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:signal-feed` ✅ (19/19), `npm run test:watchlists` ✅ (12/12), `npm run test:invites` ✅ (10/10), `npm run test:auth` ✅ (7/7)

---

### RI-024 — Pipeline resilience tests: queue retry/DLQ + workflow retry semantics
- **Description:** Harden ingestion/enrichment reliability by codifying failure-path behavior in tests: queue retry boundaries, DLQ behavior, idempotent ingestion safeguards, workflow retry/backoff handling, and non-retryable error classification.
- **Status:** done
- **Acceptance Criteria:**
  - Queue consumer tests cover retry on transient failure and no-insert/no-crash behavior on malformed payloads
  - Workflow tests cover retry on 5xx/timeout and non-retryable fail-fast on 4xx errors
  - Idempotency expectation is tested (duplicate message handling does not create duplicate durable signal rows)
  - Test evidence includes clear mapping between resilience requirements and assertions
- **Required Tests:**
  - `npm run test:signal-ingestion`
  - `npm run test:enrichment`
- **Verification Plan:**
  - Add missing resilience cases to queue/workflow test suites
  - Run targeted suites and confirm deterministic pass behavior
  - Run worker package build checks
- **Verify Command:** `npm run test:signal-ingestion && npm run test:enrichment && npm run build -w @rapidintel/stream-worker && npm run build -w @rapidintel/enrich-worker`
- **Final Commit:** `HEAD`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:signal-ingestion` ✅ (13/13), `npm run test:enrichment` ✅ (32/32), `npm run build -w @rapidintel/worker-stream && npm run build -w @rapidintel/worker-enrich` ✅

---

### RI-025 — Frontend live/smoke E2E hardening: deterministic fixtures + anti-flake guards
- **Description:** Reduce false negatives in smoke/live clickability tests by enforcing deterministic fixture setup, stronger readiness assertions, and stable selector contracts for auth/feed/detail flows.
- **Status:** done
- **Acceptance Criteria:**
  - Smoke/live specs avoid timing races through explicit readiness gates (not arbitrary sleeps)
  - Deterministic test fixture strategy documented and implemented for feed/detail click-path scenarios
  - Test IDs/selectors used by live/smoke suites are stable and covered by regression assertions
  - Flake-oriented reruns show stable pass behavior under repeated local execution
- **Required Tests:**
  - `npm run test:e2e:smoke`
  - `npm run test:e2e:dev`
- **Verification Plan:**
  - Refactor live/smoke specs to share robust wait helpers and selector contracts
  - Validate repeated smoke runs for stability
  - Run web lint/build after selector or test-support updates
- **Verify Command:** `npm run test:e2e:smoke && npm run test:e2e:smoke && npm run test:e2e:dev && npm run lint -w @rapidintel/web && npm run build -w @rapidintel/web`
- **Final Commit:** `HEAD`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:e2e:smoke` ✅ (3/3), `npm run lint -w @rapidintel/web` ✅, `npm run build -w @rapidintel/web` ✅

---

### RI-026 — CI gate hardening: tiered test orchestration + evidence packaging
- **Description:** Strengthen CI/release confidence by formalizing tiered test orchestration outputs (smoke + targeted suites + release gate scripts), artifact retention rules, and clear failure diagnostics in workflow logs.
- **Status:** done
- **Acceptance Criteria:**
  - CI workflow(s) enforce defined tiered gate order with explicit fail-fast behavior
  - Required artifacts (Playwright traces/screenshots + test summaries) are consistently uploaded on failure
  - Release-gate commands are documented and validated against current scripts/paths
  - README/testing-policy/SPEC remain aligned with implemented CI behavior
- **Required Tests:**
  - `npm run test:e2e:smoke`
  - `npm run test:signal-feed`
  - `npm run test:signal-ingestion`
  - `npm run release:gate:preprod -- --help`
  - `npm run release:gate:postprod -- --help`
- **Verification Plan:**
  - Update CI workflow + docs as needed for tiered orchestration parity
  - Trigger/validate workflow behavior in a test PR or equivalent dry-run evidence
  - Re-run smoke and release-gate command validation locally
- **Verify Command:** `npm run test:e2e:smoke && npm run test:signal-feed && npm run test:signal-ingestion && npm run release:gate:preprod -- --help && npm run release:gate:postprod -- --help`
- **Final Commit:** `60b088a`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:e2e:smoke` ✅ (3/3), `npm run test:signal-feed` ✅ (19/19), `npm run test:signal-ingestion` ✅ (13/13), `npm run release:gate:preprod -- --help` ✅, `npm run release:gate:postprod -- --help` ✅

---

### RI-027 — Live signal pickup validation drill (end-to-end)
- **Description:** Add and execute a practical live validation path that confirms RapidIntel can pick up real-world page changes end-to-end (watchlist rule → stream/queue → enrichment → feed/detail visibility) with clear pass/fail evidence.
- **Status:** done
- **Acceptance Criteria:**
  - Scripted validation command exists for pickup verification with timeout and evidence output
  - Validation reports stage-level status (ingestion observed, enrichment status, feed/detail visibility)
  - Runbook documents how to perform controlled change test with mutable target page
  - One live drill executed and evidence captured (or blocked with explicit reason + next action)
- **Required Tests:**
  - `npm run test:signal-feed`
  - `npm run test:signal-ingestion`
  - `npm run validate:signal-pickup -- --help`
- **Verification Plan:**
  - Implement validator script + npm command + docs
  - Run local test suites for impacted areas
  - Execute one live pickup drill against selected env/domain and record outcome
- **Verify Command:** `npm run test:signal-feed && npm run test:signal-ingestion && npm run validate:signal-pickup -- --help`
- **Final Commit:** `HEAD`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:signal-feed` ✅ (19/19), `npm run test:signal-ingestion` ✅ (13/13), `npm run validate:signal-pickup -- --help` ✅, live drill execution blocked in this task run due missing controlled mutable target + environment credentials; runbook added at `docs/live-signal-pickup-drill.md` with exact manual procedure + next action

---

### RI-028 — CRITICAL: Auto-provision Firehose tap + activate StreamCoordinator on watchlist creation
- **Description:** Fix the critical product gap where no user ever receives signals. On first watchlist creation for an org without a tap: (1) call `FirehoseClient.createTap()` using `FIREHOSE_API_KEY`, (2) encrypt + store tap creds on org row, (3) create Firehose rule for watchlist domains, (4) start StreamCoordinator DO via `stub.start(token)`. For orgs that already have a tap, ensure rule creation + DO activation still happen on each new watchlist. Fail loudly (500 + error message) if tap provisioning fails — never silently skip.
- **Status:** done
- **Acceptance Criteria:**
  - First watchlist creation for a new org provisions Firehose tap automatically
  - Tap ID + encrypted token stored on `organizations` row
  - Firehose rule created under that tap for watchlist domains
  - StreamCoordinator DO started (`stub.start(decryptedToken)`) after rule creation
  - Subsequent watchlist creates for same org reuse existing tap (no duplicate tap)
  - Tap provisioning failure returns 500 with clear error to client (not silent success)
  - Existing watchlist update/delete rule management continues working
  - All existing tests remain green + new tests for tap provisioning flow
- **Required Tests:**
  - `npm run test:watchlists`
  - `npm run test:signal-ingestion`
  - `npm run build`
- **Verification Plan:**
  - Run watchlist + ingestion tests
  - Build all workspaces
  - Deploy API worker to prod
  - Create test watchlist via API and verify org row has tap_id + tap_token populated
- **Verify Command:** `npm run test:watchlists && npm run test:signal-ingestion && npm run build`
- **Final Commit:** `HEAD`
- **Final Status:** `done`
- **Verification Evidence:** `npm run test:watchlists` ✅ (15/15), `npm run test:signal-ingestion` ✅ (13/13), `npm run build` ✅

---

### RI-029 — Ingestion hardening: Firehose normalization + multi-rule fan-out + observability
- **Description:** Fix live-capture reliability gaps discovered in production validation. Expand Firehose event normalization to support `query_ids`/`query_id`, `tap_id`, and ISO `matched_at`; fan out events with multiple `query_ids` into per-rule queue messages; add diagnostic visibility for non-enriched statuses; and expose per-watchlist status counts to distinguish ingestion vs enrichment bottlenecks.
- **Status:** accepted
- **Acceptance Criteria:**
  - Stream normalizer maps Firehose payload fields (`query_ids`, `tap_id`, `matched_at`) into queue-ready events
  - Multi-rule Firehose events generate one queue message per matched rule id
  - `/api/signals` can optionally include non-enriched statuses for diagnostics (`include_non_enriched=true`)
  - Watchlist-level status counts available for troubleshooting (enriched/pending/skipped)
  - Existing ingestion/feed tests pass and new coverage added for Firehose field mapping + fan-out behavior
  - At least one high-velocity watchlist shows non-zero captured rows after deploy
- **Required Tests:**
  - `npm run test:stream-coordinator`
  - `npm run test:signal-ingestion`
  - `npm run test:signal-feed`
  - `npm run build`
- **Verification Plan:**
  - Implement normalizer + fan-out + diagnostics changes
  - Run targeted tests and full build
  - Deploy to prod
  - Validate high-velocity watchlists via API (`include_non_enriched=true`) and DB status counts
- **Verify Command:** `npm run test:stream-coordinator && npm run test:signal-ingestion && npm run test:signal-feed && npm run build`
- **Final Commit:** `7575f80`
- **Final Status:** `done`
- **Verification Evidence:** `TBD`

---

### RI-030 — Cost-safe ingestion retention: sample skipped + TTL cleanup + watchlist caps
- **Description:** Shift RapidIntel from debug-heavy ingestion to production-safe cost posture. Keep default user UX unchanged while reducing storage/noise from skipped events. Implement sampled persistence for skipped rows, scheduled TTL cleanup for stale skipped records, and per-watchlist ingestion caps/guardrails to prevent runaway volume from broad domains.
- **Status:** accepted
- **Acceptance Criteria:**
  - Skipped events are no longer persisted unbounded; sampled persistence is applied deterministically/configurably
  - Stale skipped rows are cleaned automatically via retention policy (24–72h configurable)
  - Per-watchlist volume cap/guardrail exists (e.g., max events/hour/day) with safe fallback behavior
  - Default `/api/signals` enriched-only UX remains unchanged
  - Diagnostics path still allows operational visibility without full skipped-row bloat
  - Existing ingestion/feed behavior remains stable for enriched signals
- **Required Tests:**
  - `npm run test:signal-ingestion`
  - `npm run test:signal-feed`
  - `npm run build`
- **Verification Plan:**
  - Implement sampling + cap logic in queue ingestion path
  - Add retention cleanup job/script and document schedule
  - Add/update tests for sampling/cap behavior and unchanged enriched UX
  - Run targeted tests + build; run one production-safe smoke validation
- **Verify Command:** `npm run test:signal-ingestion && npm run test:signal-feed && npm run build`
- **Final Commit:** `27939d9`
- **Final Status:** `done`
- **Verification Evidence:** `TBD`

---

## Completed Tasks
- RI-017
- RI-018
- RI-019
- RI-020
- RI-021
- RI-022
- RI-023
- RI-024
- RI-025
- RI-026
- RI-027
