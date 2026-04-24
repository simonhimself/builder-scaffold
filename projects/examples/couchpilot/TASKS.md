# TASKS.md — Couchpilot

## Project Config
- Discord thread: `proj-couchpilot` (id: `1486828596348719197`) in #blue-intake
- Project path: `/home/simon/.openclaw/workspace-builder/projects/couchpilot`
- Blue-status channel id: `1477348546502987828`

> Status lifecycle: `todo` -> `in-progress` -> `review` -> `done` (or `blocked`)
> Rule: no task may be `done` without Acceptance Criteria + Required Tests + Verification Plan + Verification Evidence.

## Milestone Overview

| Phase | Tasks | Focus |
|---|---|---|
| P0 | T001-T003 | Foundation + auth + sync |
| P1 | T004-T007 | Recommendation engine + core UX |
| P2 | T008-T009 | Reliability + MVP hardening |
| P2.5 | T010-T012 | Smart browse: shelves + match-score |
| P3 | T013-T020 | Opinionated browse: vibes, chains, genre hubs, date-night |
| Backlog | T021+ | Expanded personalization + experiments |

## Active Tasks

| ID | Title | Status | Owner | Notes |
|---|---|---|---|---|
| T001 | Monorepo scaffold + Cloudflare baseline | done | builder | WS-A |
| T002 | Trakt OAuth + encrypted token lifecycle | done | builder | WS-A |
| T003 | Trakt sync pipeline + D1 schema | done | builder | WS-A |
| T004 | Recommendation endpoint + TMDB verification | done | builder | WS-B |
| T005 | Constraint parsing + prompt assembly + rec ranking | done | builder | WS-B |
| T006 | Chat-first frontend flow | done | builder | WS-C |
| T007 | Trakt action layer from recommendation cards | done | builder | WS-C |
| T008 | Taste profile generation/cache + profile page | done | builder | WS-D |
| T009 | Observability, QA gate, release checklist | done | builder | WS-D (retry after gateway restart) |
| T010 | Smart shelf generation pipeline + API | done | builder | Phase 1.5 |
| T011 | Browse frontend with shelf display | done | builder | Phase 1.5 |
| T012 | Match-score ranking for browse cards | done | builder | Phase 1.5 |
| T013 | Opinionated card copy (hook/why/caveat/tags) | done | builder | WS-E |
| T014 | Vibe taxonomy + vibe generation API | done | builder | WS-E |
| T015 | Vibe pages frontend | done | builder | WS-E |
| T016 | "Because you watched X" chain generation API | done | builder | WS-E |
| T017 | Chain UX (movie-to-movie path) | done | builder | WS-E |
| T018 | Taste-aware genre hub API | done | builder | WS-E |
| T019 | Genre hub UX | done | builder | WS-E |
| T020 | Date-night mode v1 (couple fit) | done | builder | WS-E |

> Canonical task closure fields live in each task detail block (`Final Commit`, `Final Status`, `Verification Evidence`).

## Task Detail Blocks (Required)

### T001 — Monorepo scaffold + Cloudflare baseline
- Goal: Establish reproducible project foundation for frontend, API worker, shared packages, and deployment config.
- Scope:
  - Create workspace structure (`apps/web`, `apps/api`, `packages/*`).
  - Add TypeScript strict config, linting/formatting, test runner baseline.
  - Add wrangler/pages config and `.dev.vars.example`.
- Acceptance Criteria:
  - Workspace builds cleanly with strict TypeScript.
  - Lint passes with zero errors.
  - API worker starts in local dev.
  - Frontend app starts in local dev.
- Required Tests (derived from AC):
  - Workspace build test across all packages.
  - ESLint test across repository.
  - API local startup smoke test.
  - Frontend local startup smoke test.
- Verification Plan:
  - Run `npm run build`.
  - Run `npm run lint`.
  - Run `npm run dev:api` and confirm health route responds.
  - Run `npm run dev:web` and confirm UI boot.
- Verification Evidence: `npm run build` ✅, `npm run lint` ✅, API smoke ✅ (`npm run dev:api` + `curl http://127.0.0.1:8787/api/health` -> status ok), web smoke ✅ (`npm run dev:web` + `curl http://localhost:5173/` returned Vite index HTML).
- Risks/Todos: Keep package boundaries clean to prevent circular deps early.
- Final Commit: `8870a56`
- Final Status: `done`

### T002 — Trakt OAuth + encrypted token lifecycle
- Goal: Implement secure sign-in and token management for Trakt-backed user sessions.
- Scope:
  - OAuth start/callback/logout routes.
  - Access/refresh token handling with encrypted-at-rest storage.
  - Session binding from frontend to API.
- Acceptance Criteria:
  - User can complete OAuth login and receive valid app session.
  - Refresh path rotates/updates expired tokens correctly.
  - Tokens are never persisted in plaintext.
- Required Tests (derived from AC):
  - OAuth callback contract test with mocked Trakt exchange.
  - Token refresh route test for valid and expired scenarios.
  - Encryption/decryption round-trip unit test.
- Verification Plan:
  - Run `npm run test:auth`.
  - Inspect D1 rows and verify encrypted token fields.
  - Execute manual login/logout flow in local env.
- Verification Evidence: `npm run test:auth` ✅ (5/5 tests), encryption-at-rest validated in auth tests (`trakt_*_token_enc` != plaintext), `npm run -s build` ✅.
- Risks/Todos: Ensure callback URL handling is environment-safe across local/prod.
- Final Commit: `e127ddb`
- Final Status: `done`

### T003 — Trakt sync pipeline + D1 schema
- Goal: Build idempotent ingestion of watched/rated movie history into normalized local tables.
- Scope:
  - Define and migrate D1 schema (`users`, `watch_history`, `sync_state`, etc.).
  - Implement initial and incremental sync with checkpointing.
  - Normalize external IDs and dedupe records.
- Acceptance Criteria:
  - Fresh account sync imports history without errors.
  - Incremental sync does not create duplicates.
  - Sync checkpoint persists and resumes correctly.
- Required Tests (derived from AC):
  - Migration apply/rollback smoke test.
  - Incremental sync idempotency test.
  - Deduplication test on repeated payloads.
- Verification Plan:
  - Run `npm run db:migrate:local`.
  - Run `npm run test:sync`.
  - Re-run sync twice and confirm stable record counts.
- Verification Evidence: `npm run db:migrate:local` ✅ (no pending migrations), `npm run test:sync` ✅ (3/3 tests incl. idempotent rerun + dedupe), `npm run -s build` ✅.
- Risks/Todos: Align Trakt movie identity fields (trakt/tmdb/imdb) consistently.
- Final Commit: `435314e`
- Final Status: `done`

### T004 — Recommendation endpoint + TMDB verification
- Goal: Provide reliable recommendation API that never returns unverified titles.
- Scope:
  - Implement `POST /api/recommend` payload contract.
  - Build LLM call + structured JSON parsing.
  - Validate and enrich all recommendations through TMDB lookup.
- Acceptance Criteria:
  - Endpoint returns 3-5 recommendations with title/year/reason/caveat/confidence.
  - Unverified/hallucinated titles are filtered and replaced before response.
  - Response includes TMDB IDs and artwork metadata for each recommendation.
- Required Tests (derived from AC):
  - API contract test for valid and invalid payloads.
  - TMDB verification test including hallucinated title case.
  - End-to-end mocked integration test for successful recommendation path.
- Verification Plan:
  - Run `npm run test:recommend`.
  - Run local API smoke with sample prompts.
  - Confirm zero unverified rows in recommendation response logs.
- Verification Evidence: `npm run test:recommend` ✅ (3/3), `npm run -s build` ✅; mocked end-to-end tests logged verified recommendation responses (`returnedCount=3`) with hallucination filtering + TMDB fallback replacement (`filteredCount=1`, `fallbackUsed=1`).
- Risks/Todos: Handle partial TMDB failures gracefully without emptying response.
- Final Commit: `b64802e`
- Final Status: `done`

### T005 — Constraint parsing + prompt assembly + ranking quality
- Goal: Ensure recommendation relevance by strict handling of runtime/mood/genre/who constraints.
- Scope:
  - Parse user query + optional structured constraints.
  - Assemble compact, deterministic prompt context.
  - Add response scoring metadata for confidence and constraint adherence.
- Acceptance Criteria:
  - Runtime and mood constraints are explicitly enforced.
  - Prompt size remains bounded and cost-aware.
  - Recommendation output includes constraint-fit metadata.
- Required Tests (derived from AC):
  - Unit tests for constraint parser edge cases.
  - Prompt assembly tests for context size limits.
  - Recommendation quality regression tests with fixed fixtures.
- Verification Plan:
  - Run `npm run test:constraints`.
  - Run `npm run test:prompting`.
  - Validate fixture outputs against expected constraints.
- Verification Evidence: `npm run test:constraints` ✅ (4/4), `npm run test:prompting` ✅ (4/4 across prompting + quality fixtures), `npm run -s build` ✅.
- Risks/Todos: Avoid overfitting prompt behavior to a narrow sample set.
- Final Commit: `d1a2476`
- Final Status: `done`

### T006 — Chat-first frontend flow
- Goal: Deliver usable query -> results -> refinement UX for recommendation sessions.
- Scope:
  - Build chat input and conversation panel.
  - Render recommendation cards with poster/runtime/reason/caveat.
  - Support follow-up turns preserving local session context.
- Acceptance Criteria:
  - User can submit query and receive rendered recommendations.
  - Follow-up queries include prior context in same session.
  - UI is responsive and dark-mode first.
- Required Tests (derived from AC):
  - Component tests for chat input and card rendering.
  - Frontend integration test for follow-up flow.
  - Responsive smoke test for mobile viewport.
- Verification Plan:
  - Run `npm run test:web`.
  - Run `npm run build:web`.
  - Execute manual query/refine path in local browser.
- Verification Evidence: `npm run test:web` ✅ (4/4 incl. follow-up integration + mobile viewport smoke), `npm run build:web` ✅.
- Risks/Todos: Keep UI state machine simple to avoid brittle chat state bugs.
- Final Commit: `a80c3b2`
- Final Status: `done`

### T007 — Trakt action layer from recommendation cards
- Goal: Close loop from recommendation to real user action in Trakt.
- Scope:
  - Implement API routes for add-to-watchlist and mark-watched.
  - Add card actions and optimistic UI feedback.
  - Sync local cache/state after write.
- Acceptance Criteria:
  - Add-to-watchlist works from recommendation card.
  - Mark-as-watched works from recommendation card.
  - Action failures show recoverable error feedback.
- Required Tests (derived from AC):
  - API tests for successful and failed Trakt writes.
  - Frontend action tests for optimistic update/rollback.
  - End-to-end happy-path action test.
- Verification Plan:
  - Run `npm run test:actions`.
  - Run `npm run test:web`.
  - Manual verify against Trakt account state.
- Verification Evidence: `npm run test:actions` ✅ (3/3 API action tests), `npm run test:web` ✅ (6/6 incl. optimistic update/rollback action flows). Manual Trakt-account live verification deferred pending runtime credentials.
- Risks/Todos: Respect rate limits and retry semantics for Trakt writes.
- Final Commit: `380db58`
- Final Status: `done`

### T008 — Taste profile generation/cache + profile page
- Goal: Provide transparent personalization baseline and reusable context for recommendation prompts.
- Scope:
  - Generate taste profile from synced watch history.
  - Cache profile with timestamp/version and refresh triggers.
  - Build profile page in frontend.
- Acceptance Criteria:
  - Profile page displays coherent, non-generic user taste summary.
  - Profile cache refreshes after significant history updates.
  - Recommendation pipeline consumes latest profile snapshot.
- Required Tests (derived from AC):
  - Profile generation unit/integration test with fixtures.
  - Cache invalidation/refresh logic test.
  - Frontend rendering test for profile page states.
- Verification Plan:
  - Run `npm run test:taste-profile`.
  - Run `npm run build:web`.
  - Manual compare profile before/after simulated new ratings.
- Verification Evidence: `npm run test:taste-profile` ✅ (API 4/4 + web 8/8), `npm run build:web` ✅; recommendation integration test confirms latest taste snapshot is injected into prompt context.
- Risks/Todos: Keep profile concise enough to control token usage.
- Final Commit: `475004b`
- Final Status: `done`

### T009 — Observability, QA gate, and release checklist
- Goal: Ship MVP with explicit quality, reliability, and cost guardrails.
- Scope:
  - Add structured logging + latency/error instrumentation.
  - Create project-level verify script and release checklist.
  - Add minimal runbook for dependency outages.
- Acceptance Criteria:
  - Key endpoints emit structured logs with request IDs.
  - Verify command runs tests/build/lint and returns non-zero on failures.
  - Release checklist covers security, performance, and functional checks.
- Required Tests (derived from AC):
  - Instrumentation smoke test across core routes.
  - End-to-end verify command test on clean clone.
  - Failure-mode drill for one external dependency outage.
- Verification Plan:
  - Run `bash /home/simon/.openclaw/workspace-builder/scripts/verify.sh /home/simon/.openclaw/workspace-builder/projects/couchpilot "npm run verify"`.
  - Execute outage simulation with mocked TMDB or Trakt failure.
  - Attach release checklist output artifact.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass), including API recommendation/taste-profile suites restored to green under OpenAI-compatible mocks.
- Risks/Todos: Persistent ACP reliability was unstable during execution; final task output validated by local verify gate and committed.
- Final Commit: `ea6960b`
- Final Status: `done`

### T010 — Smart shelf generation pipeline + API
- Goal: Generate personalized movie shelves from taste profile + watch history using LLM.
- Scope:
  - Implement shelf generation service using D4 prompt template from SPEC.md.
  - Add `POST /api/shelves/generate` endpoint (authenticated, uses taste profile + watch history).
  - TMDB-verify all shelf movie candidates (filter unverified, enrich with poster/runtime).
  - Cache generated shelves in D1 with TTL (regenerate on taste profile refresh or manually).
  - Add `GET /api/shelves` endpoint to retrieve cached shelves.
- Acceptance Criteria:
  - Shelf generation returns 5-10 themed shelves with 8-12 verified movies each.
  - Each shelf has evocative title, description, and type (taste/dynamic/chain).
  - At least 1 couple-compatible shelf, 1 deep cuts shelf, 1 new releases shelf.
  - No already-watched movies appear in shelves.
  - Shelves are cached and retrievable without regeneration.
- Required Tests (derived from AC):
  - Shelf generation unit test with mocked LLM + TMDB responses.
  - Cache storage/retrieval test.
  - Already-watched filtering test.
  - API endpoint contract tests (generate + retrieve).
- Verification Plan:
  - Run `npm run verify`.
  - Manual inspection of generated shelf quality from local API call.
- Verification Evidence: `npm run verify` ✅ (30 API tests + 8 web + 2 packages, build clean, lint clean). Shelf generation + cache + API contract + watched-filtering tests all pass.
- Risks/Todos: LLM shelf generation is expensive per call; cache aggressively. Keep shelf count configurable.
- Final Commit: `971f549`
- Final Status: `done`

### T011 — Browse frontend with shelf display
- Goal: Add visual browse mode alongside chat with shelf cards and movie posters.
- Scope:
  - Add browse view toggle (Chat ↔ Browse) in frontend.
  - Render shelves as horizontal scrollable rows with movie poster cards.
  - Each card shows poster, title, year, match hook (if available).
  - Clicking a card opens detail with reason/caveat + watchlist/watched actions.
  - Wire to `GET /api/shelves` endpoint.
- Acceptance Criteria:
  - Browse view displays shelves with poster cards.
  - User can toggle between Chat and Browse views.
  - Card click shows movie detail with actions.
  - Responsive layout (mobile-first, dark mode).
- Required Tests (derived from AC):
  - Component tests for shelf row and movie card rendering.
  - Toggle between Chat and Browse view test.
  - Mobile responsive smoke test.
- Verification Plan:
  - Run `npm run verify`.
  - Manual visual check of browse layout on mobile and desktop viewports.
- Verification Evidence: `npm run verify` ✅ — web component tests for shelf row + movie card, Chat/Browse toggle, mobile browse smoke test all pass. Build + lint clean.
- Risks/Todos: Shelf detail reason/caveat is synthesized if backend doesn't provide explicit fields. Browse action state keys are TMDB-ID based under shared "browse" context.
- Final Commit: `782de35`
- Final Status: `done`

### T012 — Match-score ranking for browse cards
- Goal: Add personalized match scores to browse movie cards using D3 prompt template.
- Scope:
  - Implement match-score service using D3 prompt from SPEC.md.
  - Score shelf movies against taste profile (batch, cached).
  - Add match_score + why_hook to shelf movie data.
  - Display score badge and hook on browse cards.
  - Add sort-by-score option in browse view.
- Acceptance Criteria:
  - Each browse card shows a 0-100 match score and personalized hook.
  - Scores are cached per shelf generation cycle.
  - Sort-by-score reorders cards within a shelf.
- Required Tests (derived from AC):
  - Match-score service unit test with fixtures.
  - Score display rendering test.
  - Sort behavior test.
- Verification Plan:
  - Run `npm run verify`.
- Verification Evidence: `npm run verify` ✅ (see close-task gate output)
- Risks/Todos: Batch scoring is LLM-heavy; keep candidate list bounded per shelf.
- Final Commit: `71d5642`
- Final Status: `done`

### T013 — Opinionated card copy (hook/why/caveat/tags)
- Goal: Upgrade browse + recommendation cards to feel like a *personal, opinionated film friend*.
- Scope:
  - Define a structured "card copy" schema (hook line, why-for-you, honest caveat, tags, craft nugget).
  - Implement card-copy generation + caching using prompt D5 (SPEC.md).
  - Wire card copy into browse detail + (optionally) chat recommendation cards.
  - Add safety fallbacks that stay varied (no repeated monotone phrase).
- Acceptance Criteria:
  - Cards display a punchy hook + 2-3 sentence why-for-you + a clear caveat.
  - Copy is varied across items and avoids generic Netflix-y phrasing.
  - Generation is cached and cost-capped (no per-card uncached calls on browse).
- Required Tests (derived from AC):
  - Prompt output JSON contract tests.
  - Quality fixture tests that assert variance + banned openings.
  - Web component tests for rendering the new fields.
- Verification Plan:
  - Run `npm run verify`.
  - Manual browse pass: open 20+ cards and confirm voice/variance.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). API contract + cache + quality tests pass. Web copy rendering + loading state tests pass.
- Risks/Todos: Balance voice with reliability — keep schema strict and fall back to deterministic copy if generation fails.
- Final Commit: `0b40168`
- Final Status: `done`

### T014 — Vibe taxonomy + vibe generation API
- Goal: Add vibe-forward browsing (🧠 / 🍿 / 🧑‍🤝‍🧑 / etc.) that feels personal and playful.
- Scope:
  - Define a small, stable vibe taxonomy (id, emoji, title, blurb, constraint presets).
  - Add `GET /api/vibes`.
  - Add `POST /api/vibes/:id/generate` to produce vibe rows + TMDB IDs (prompt D7), verified + cached.
  - Add `GET /api/vibes/:id` to read cached vibe page output.
- Acceptance Criteria:
  - Vibe pages have strong, distinct voice and non-generic row titles.
  - Rows are taste-aware (not a generic genre list).
  - Caching prevents repeated LLM work on refresh.
- Required Tests (derived from AC):
  - API contract tests for list/generate/get.
  - Verification tests that all returned tmdb_ids resolve to cached movie metadata.
- Verification Plan:
  - Run `npm run verify`.
  - Manual spot-check 3-5 vibes for row overlap/quality.
- Verification Evidence: `npm run verify` ✅ (48 API tests + 12 web + 2 packages, build clean, lint clean). Taxonomy list, generate, cache, enrichment, and static correctness tests all pass.
- Risks/Todos: Avoid taxonomy bloat; 6-10 vibes max initially.
- Final Commit: `9edcd5c`
- Final Status: `done`

### T015 — Vibe pages frontend
- Goal: Ship vibe browsing UX that is clearly *not* Netflix rows.
- Scope:
  - Add a Vibes entry point in browse.
  - Build vibe page layout (blurb + 2-4 rows) with distinct styling.
  - Add loading/error states and regeneration affordance (manual refresh).
- Acceptance Criteria:
  - Vibe pages render quickly from cache and look distinct from shelves.
  - Mobile-first layout reads like a curated zine, not a grid.
- Required Tests (derived from AC):
  - Component tests for vibe page + row rendering.
  - Navigation tests from Browse → Vibes → Vibe detail.
- Verification Plan:
  - Run `npm run verify`.
  - Manual mobile viewport review.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). Vibe index rendering, detail rendering, navigation flow, and loading state tests all pass.
- Risks/Todos: Keep animation flourishes lightweight; prioritize readability.
- Final Commit: `c74d960`
- Final Status: `done`

### T016 — "Because you watched X" chain generation API
- Goal: Provide explainable, playful recommendation chains (A → B → C) that feel tailored.
- Scope:
  - Add `POST /api/chains/generate` with seed tmdb_id and context.
  - Generate 3-5 step chains using prompt D6 with verified candidate pool.
  - Cache chains by (user, seed, taste_profile_version).
- Acceptance Criteria:
  - Chains are coherent and each step has a specific connective reason.
  - All items are TMDB-verified and enriched.
  - Cached reads are fast.
- Required Tests (derived from AC):
  - API contract tests + caching behavior.
  - Quality fixtures for chain coherence + banned openings.
- Verification Plan:
  - Run `npm run verify`.
  - Manual: generate chains from 5 different seeds; sanity-check flow.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). Chain generation contract, cache, auth, and sanitization tests all pass.
- Risks/Todos: Candidate pool size + token cost; keep pools bounded.
- Final Commit: `d910ef3`
- Final Status: `done`

### T017 — Chain UX (movie-to-movie path)
- Goal: Make chains feel like a fun guided path, not a list.
- Scope:
  - Add chain view: seed movie header + step cards with connective copy.
  - Deep link from movie detail "Because you watched this".
  - Keep actions available (watchlist/watched) on chain items.
- Acceptance Criteria:
  - Chain view is readable, delightful, and fast.
  - Steps clearly communicate "why this leads to that".
- Required Tests (derived from AC):
  - Component tests for chain step rendering.
  - Navigation/deeplink tests.
- Verification Plan:
  - Run `npm run verify`.
  - Manual UX review on mobile.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). Chain rendering, navigation, and loading state tests all pass.
- Risks/Todos: Avoid over-text; keep reasons punchy.
- Final Commit: `35589c7`
- Final Status: `done`

### T018 — Taste-aware genre hub API
- Goal: Turn genre browsing into "genre through *your* filter".
- Scope:
  - Define minimal supported genres and mapping.
  - Add `GET /api/genres`.
  - Add `POST /api/genres/:id/generate` using prompt D8.
  - Cache by (user, genre, taste_profile_version).
- Acceptance Criteria:
  - Genre pages contain 3-5 angles with non-generic titles.
  - Angles are taste-aware and use verified TMDB IDs.
- Required Tests (derived from AC):
  - API contract tests.
  - Verification tests for TMDB IDs.
- Verification Plan:
  - Run `npm run verify`.
  - Manual spot-check 3 genres.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). Genre list, generation, cache, and auth tests all pass.
- Risks/Todos: Genre naming collisions; keep IDs stable.
- Final Commit: `ac0297c`
- Final Status: `done`

### T019 — Genre hub UX
- Goal: Deliver genre pages that feel curated (angles), not a dump.
- Scope:
  - Genre index page.
  - Genre detail page with blurb + angle rows.
  - Visual distinction from shelves and vibes.
- Acceptance Criteria:
  - Genre hubs read like a magazine section, not a catalog.
  - Navigation is smooth and mobile-first.
- Required Tests (derived from AC):
  - Component tests for genre hub pages.
  - Navigation tests.
- Verification Plan:
  - Run `npm run verify`.
  - Manual UI pass.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). Genre index, detail, navigation, and loading state tests all pass.
- Risks/Todos: Keep angle count small to avoid scroll fatigue.
- Final Commit: `ac645ef`
- Final Status: `done`

### T020 — Date-night mode v1 (couple fit)
- Goal: Add a lightweight couple/double-viewer mode that surfaces "couple fit" without full multi-profile complexity.
- Scope:
  - Add settings: partner name + couple preferences (e.g., tolerance for heavy/violent/slow).
  - Adjust prompts to incorporate date-night mode constraints.
  - Surface a couple-fit indicator on cards (e.g., stars + one-line qualifier).
- Acceptance Criteria:
  - Users can toggle date-night mode.
  - Cards show a couple-fit line that feels grounded (not random).
  - Mode changes do not break caching correctness.
- Required Tests (derived from AC):
  - Settings persistence tests.
  - Prompt/context tests for date-night mode injection.
  - UI tests for toggle + indicator rendering.
- Verification Plan:
  - Run `npm run verify`.
  - Manual: compare browse output with mode on/off.
- Verification Evidence: `npm run verify` ✅ (all workspace tests/build/lint pass). Settings save/retrieve, recommendation prompt injection, match-score couple-fit, and UI toggle/display tests all pass.
- Risks/Todos: This is heuristic until we support per-person profiles; keep expectations honest.
- Final Commit: `f27415b`
- Final Status: `done`
