# SPEC.md - Couchpilot

**Version:** 0.4  
**Date:** 2026-03-28  
**Owner:** Blue Builder  
**Status:** Draft (Phase 2 planning; MVP + Phase 1.5 shipped)  
**Depends on:** PRD.md

---

## 1) Objective

Translate Couchpilot MVP scope into an executable technical plan that minimizes rework and keeps strict quality gates.

## 2) Current-State Findings (Validated)

- **Project state:** Monorepo is live at `projects/couchpilot` with API + web + shared packages.
- **Shipped (MVP):** Trakt OAuth + sync, taste profile, chat-first recommendations, and Trakt actions.
- **Shipped (Phase 1.5):** Smart shelves + browse UI + match-score ranking + cached hooks.
- **Current gap (product feel):** Browse still risks feeling like "generic streaming rows" unless we lean hard into *voice*, *taste signals*, and *contextual framing* (the "film-obsessed friend" experience).
- **Known constraints:**
  - Cloudflare-first stack (Pages + Workers + D1 + KV).
  - Trakt + TMDB + LLM as external dependencies.
  - Cost must stay personal-use friendly (token/call caps + caching).

## 2.1) Locked Technical Decisions

- **Recommendation candidate strategy:** Hybrid mode (LLM proposes, TMDB verifies/replaces) with TMDB trending/new-release context injected into prompt.
- **Session/auth model:** Cookie-based app session (httpOnly + Secure + SameSite=Lax), with Worker-managed Trakt OAuth token lifecycle.
- **Taste profile refresh policy:** Event-driven with floor (on new ratings or 10+ new watches) plus weekly fallback refresh.
- **LLM model defaults:** Use smaller/faster model for browse scoring & shelf generation by default; keep provider+model configurable by env.
- **Browse surfaces policy:** Phase 2 focus is making browse *feel personal, fun, and opinionated* (vibes, chains, taste-aware genre pages, and date-night mode).

## 3) Target Architecture

### Runtime and deployment
- **Platform/runtime:**
  - Frontend: Next.js (App Router) deployed to Cloudflare Pages.
  - API: Cloudflare Worker (Hono) under `/api/*`.
- **Data/storage:**
  - D1: relational app state (users, tokens metadata, watch history, taste profile cache, rec logs).
  - KV: short-lived session/cache keys and request-level transient data.
- **Queue/background processing:**
  - Initial MVP: Worker Cron trigger or on-demand sync endpoint for Trakt incremental sync.
  - Optional queue deferred unless sync workload proves bursty.
- **Environment strategy (dev/staging/prod):**
  - Local: wrangler dev + local D1.
  - Prod: single environment initially; staging optional after MVP stabilization.

### System boundaries
- **External integrations:**
  - Trakt OAuth + user data + watchlist write endpoints.
  - TMDB metadata/search/verification.
  - Claude Sonnet API for profile + recommendation reasoning.
- **Auth/security boundaries:**
  - Frontend never receives third-party secrets.
  - Worker owns all token exchange/refresh/write-back flows.
  - Access tokens encrypted at rest using server-side key material.
- **Data ownership boundaries:**
  - Trakt remains system of record for watchlist/history source.
  - Couchpilot stores normalized cache + recommendation telemetry.

## 4) Workstreams

## WS-A - Foundation, Auth, and Data Sync
**Scope:**
- Repo app scaffolding for frontend + API + shared schema package.
- Trakt OAuth flow and secure token lifecycle.
- Initial + incremental watch history sync into D1.

**Acceptance:**
- User can authenticate and sync history without duplicate records.
- Token refresh path works and recovers expired sessions.

**Test strategy:**
- OAuth callback flow tests.
- Sync idempotency tests.
- Migration and schema verification tests.

## WS-B - Recommendation Engine + Validation Pipeline
**Scope:**
- `/api/recommend` endpoint with query + constraints payload.
- Prompt assembly (taste profile + recent watches + constraints).
- TMDB verification + enrichment of model output.

**Acceptance:**
- Endpoint returns 3-5 verified recommendations with personalized reasoning.
- Constraints are enforced and surfaced in response metadata.

**Test strategy:**
- Contract tests for payload validation and response shape.
- TMDB verification tests (invalid/hallucinated title handling).
- Latency/error-path tests with dependency mocks.

## WS-C - Frontend Chat Experience + Action Layer
**Scope:**
- Chat-first UI for query, follow-up, and recommendation cards.
- Card actions: add to watchlist, mark watched.
- Error and loading states for dependency failures.

**Acceptance:**
- User can execute full recommendation flow from query to action.
- Action confirmations and failures are explicit and recoverable.

**Test strategy:**
- Component tests for chat/card interactions.
- E2E flow tests for query/refine/action happy path.
- Responsive layout checks for mobile and desktop.

## WS-D - Taste Profile + Observability + Cost Guardrails
**Scope:**
- Taste profile generation endpoint/pipeline and cache policy.
- Usage logs for recommendation quality review.
- Baseline observability for latency/error/cost tracking.

**Acceptance:**
- Profile is generated, cached, and refreshable.
- Key metrics available for product and technical review.

**Test strategy:**
- Profile generation determinism/sanity tests.
- Logging/schema tests for rec telemetry.
- Budget smoke checks based on token usage assumptions.

## WS-E — Opinionated Browse Surfaces (Phase 2)
**Goal:** Make browse feel like a *personal film friend*, not a generic streaming catalog.

**Scope:**
- **Vibe pages** (🧠 / 🍿 / 🧑‍🤝‍🧑 / etc): curated, mood-forward collections with strong voice.
- **"Because you watched X" chains:** short, explainable recommendation paths (A → B → C) with taste-signal continuity.
- **Taste-aware genre pages:** genre hubs that are *filtered through the user’s taste* (e.g. "Crime, but your kind: moral rot + quiet dread").
- **Date-night / multi-person mode:** combine constraints + taste signals for two viewers; surface a "couple fit" indicator.
- **Card copy upgrade:** structured, opinionated micro-critique (hook line + why-for-you + honest caveat + tags).

**Acceptance:**
- Browse surfaces feel distinctive and personal (no "Netflix rows" vibe).
- Copy is varied, concrete, and anchored in taste signals.
- Features are cacheable and cost-capped.

**Test strategy:**
- Golden-fixture prompt tests for voice/variety.
- Contract tests for new browse endpoints.
- UI component tests for vibe/chain/genre pages.

## 5) Cross-Cutting Requirements

- **Observability/monitoring:**
  - Structured logs with request IDs across API calls.
  - Latency/error counters by dependency: Trakt, TMDB, LLM.
- **Error handling and retries:**
  - Safe retries for transient external failures.
  - Distinguish retryable vs non-retryable failures.
- **Data migration/backfill strategy:**
  - Versioned D1 migrations.
  - Backfill path for historical Trakt data with checkpointing.
- **Security controls:**
  - Encryption at rest for provider tokens.
  - Principle of least privilege on env/config.
  - Scrub PII/secrets from logs.
- **Performance/cost guardrails:**
  - Keep LLM context compact (profile summary + recent window).
  - Cache expensive computations (profile + candidate pools).

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
- Map tasks explicitly to workstreams:
  - WS-A -> T001-T003
  - WS-B -> T004-T005
  - WS-C -> T006-T007
  - WS-D -> T008-T009
  - WS-E -> T013+
- Keep each task small enough for one BUILD slice.
- Every task must include acceptance criteria, tests, verification plan, and evidence placeholders.

---

## Appendix A — Architecture Diagram

```
┌──────────────────────────────────────────┐
│              Frontend                     │
│         Next.js on CF Pages              │
│                                          │
│  ┌────────────┐  ┌───────────────────┐  │
│  │ 💬 Chat    │  │ 🎬 Browse        │  │
│  │ (language) │  │ (shelves/vibes)  │  │
│  └────────────┘  └───────────────────┘  │
│  ┌────────────┐  ┌───────────────────┐  │
│  │ Watchlist  │  │ Taste Profile    │  │
│  └────────────┘  └───────────────────┘  │
└──────────────┬───────────────────────────┘
               │
┌──────────────▼───────────────────────────┐
│           API Layer                       │
│      Cloudflare Worker (Hono)            │
│                                          │
│  /api/health          — healthcheck      │
│  /api/auth/trakt/*    — OAuth flow       │
│  /api/sync/trakt      — history sync     │
│  /api/recommend       — LLM recs         │
│  /api/actions/*       — Trakt writes     │
│  /api/taste-profile   — taste profile    │
│  /api/movie/:id       — movie details    │
│  /api/search          — movie search     │
└──┬───────┬───────┬───────┬───────────────┘
   │       │       │       │
   ▼       ▼       ▼       ▼
┌──────┐┌──────┐┌──────┐┌──────┐
│Trakt ││ TMDB ││Claude││  D1  │
│ API  ││ API  ││ API  ││(SQLite)│
│      ││      ││      ││      │
│state ││media ││brain ││cache │
└──────┘└──────┘└──────┘└──────┘
```

### Data flow: "Recommend me something"
```
1. User: "sci-fi, not too heavy, under 2 hours"
2. Worker fetches user's taste context from D1 cache
   (watch history, ratings, watchlist — synced from Trakt)
3. Worker builds LLM prompt:
   - taste profile summary
   - recent watches
   - user query + constraints
   - trending/new-release context from TMDB (hybrid pool hints)
4. Claude reasons about matches → returns ranked picks with explanations
5. Worker verifies each title against TMDB (filter hallucinations)
6. Worker enriches verified results with TMDB artwork + metadata
7. Frontend renders cards with posters, ratings, "why you'd like this"
8. User can: add to watchlist, mark watched, ask follow-up
```

## Appendix B — MVP API Surface

| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Healthcheck |
| GET | `/api/auth/trakt/start` | Initiate Trakt OAuth |
| GET | `/api/auth/trakt/callback` | OAuth callback handler |
| POST | `/api/auth/logout` | End session |
| POST | `/api/sync/trakt` | Trigger history/rating sync |
| POST | `/api/recommend` | Natural-language recommendation |
| POST | `/api/actions/watchlist/add` | Add movie to Trakt watchlist |
| POST | `/api/actions/watched` | Mark movie as watched |
| GET | `/api/taste-profile` | Retrieve/generate taste profile |
| GET | `/api/movie/:id` | Movie detail (TMDB enriched) |
| GET | `/api/search` | Movie search (TMDB) |

## Appendix C — D1 Schema

### users
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,           -- trakt user slug
  trakt_access_token TEXT,       -- encrypted at rest
  trakt_refresh_token TEXT,      -- encrypted at rest
  token_expires_at INTEGER,
  taste_profile_json TEXT,       -- cached LLM-generated taste profile
  taste_updated_at INTEGER,
  settings_json TEXT,
  created_at INTEGER,
  updated_at INTEGER
);
```

### watch_history (synced from Trakt)
```sql
CREATE TABLE watch_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  trakt_id INTEGER,
  tmdb_id INTEGER,
  imdb_id TEXT,
  media_type TEXT,               -- 'movie' or 'show'
  title TEXT,
  year INTEGER,
  watched_at TEXT,
  rating INTEGER,                -- user rating 1-10 (null if unrated)
  genres_json TEXT,
  runtime INTEGER,
  trakt_rating REAL,             -- community rating
  UNIQUE(user_id, trakt_id, watched_at)
);
```

### movie_cache (TMDB enrichment cache)
```sql
CREATE TABLE movie_cache (
  tmdb_id INTEGER PRIMARY KEY,
  trakt_id INTEGER,
  imdb_id TEXT,
  title TEXT,
  year INTEGER,
  genres_json TEXT,
  runtime INTEGER,
  overview TEXT,
  poster_path TEXT,
  backdrop_path TEXT,
  tmdb_rating REAL,
  trakt_rating REAL,
  popularity REAL,
  updated_at INTEGER
);
```

### recommendations_log
```sql
CREATE TABLE recommendations_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  query TEXT,
  constraints_json TEXT,
  results_json TEXT,
  model TEXT,
  tokens_used INTEGER,
  latency_ms INTEGER,
  created_at INTEGER
);
```

### sync_state
```sql
CREATE TABLE sync_state (
  user_id TEXT PRIMARY KEY,
  last_history_sync_at TEXT,
  last_ratings_sync_at TEXT,
  total_synced INTEGER DEFAULT 0,
  updated_at INTEGER
);
```

## Appendix D — LLM Prompt Designs

### D1: Taste profile prompt (run periodically / on significant new data)
```
You are a film critic and taste analyst. Given this user's watch history
and ratings, write a concise taste profile.

Include:
- Core genres and themes they gravitate toward
- Filmmaking styles they prefer (directors, cinematography, pacing)
- What they avoid or rate low
- Mood patterns (when do they watch what?)
- If this is a shared account, identify likely different viewers

Watch history (last 6 months):
{history_with_ratings}

Write the profile in 2nd person ("You love..."). Be specific and opinionated.
Keep it under 500 words — this will be used as context for recommendations.
```

### D2: Recommendation prompt
```
You are a movie advisor. The user wants a recommendation.

Their taste profile:
{taste_profile}

Recent watches:
{recent_5}

Their request: "{user_query}"

Constraints:
- Genre preference: {genre}
- Max runtime: {runtime}
- Mood: {mood}
- Watching with: {who}

Trending/new releases to consider (but don't limit yourself to these):
{tmdb_trending_context}

Return 5-7 recommendations (we'll verify and may filter some).
For each, return JSON:
{
  "title": "exact movie title",
  "year": 2024,
  "why": "specific to THIS user's taste, not generic",
  "caveat": "one honest warning (subtitled / slow start / etc)",
  "confidence": "high|medium|low"
}

Rules:
- NEVER invent a movie. Only suggest real films.
- Runtime constraints are HARD — do not exceed them.
- Mood constraints are HARD — match the requested energy.
- Explain why THIS person would like it, not why it's generally good.
- Return valid JSON array.
```

### D3: Match score prompt (for browse/card ranking, Phase 1.5+)
```
Given this user's taste profile and a list of candidate movies,
score each movie 0-100 for taste match and write a one-line hook
explaining why this user specifically would (or wouldn't) enjoy it.

Taste profile:
{taste_profile}

Movies to score:
{candidate_list}

Return JSON array of {tmdb_id, match_score, why_hook}.
Score meaning: 90+ = "this is SO you", 70-89 = solid match,
50-69 = might like it, below 50 = probably not their thing.
The hook should be personal, not a generic synopsis.
```

### D4: Shelf generation prompt (Phase 1.5+)
```
You are a film curator building personalized movie collections.

User taste profile:
{taste_profile}

Recent watches (last 30 days):
{recent_watches}

Their full watch history includes {total_movies} movies. Top genres:
{genre_breakdown}

Generate 10 smart shelves. For each shelf:
1. A short, evocative title (not generic like "Action Movies")
2. A one-line description explaining why this shelf exists for THIS user
3. 12-15 movie suggestions (title + year)
4. Shelf type: "taste" | "dynamic" | "chain"

Rules:
- Never include movies they've already watched
- At least 2 shelves should be couple-compatible (both viewers)
- At least 1 shelf should be "deep cuts" (< 50k TMDB votes)
- At least 1 shelf should be new releases (last 12 months)
- Titles must be specific and evocative, not generic
- Each shelf should feel like a distinct mood/angle, not overlapping

Return as JSON array.
```

### D5: Opinionated card-copy prompt (Phase 2)
```
You are a film-obsessed friend with great taste.
Write structured copy for a single movie, tailored to THIS user's taste.

Inputs:
- User taste profile: {taste_profile}
- Watching context: {with} (optional)
- Movie: {title} ({year}) + key metadata (runtime, director, cast, score/composer, genres)
- If present: "because you watched" seed: {seed_title} ({seed_year})

Return JSON:
{
  "hook_line": "one punchy sentence (opinionated, concrete)",
  "why_for_you": "2-3 sentences tying craft/vibe to one taste signal",
  "caveat": "one honest warning",
  "couple_fit": "short line or null (e.g. 'Couple fit: ★★★★☆ — depends how much Brittany likes brutal crime thrillers')",
  "tags": ["#border", "#moralRot", "#razorTense"],
  "craft_nugget": "1 sentence on a specific craft element (score/camera/editing)"
}

Rules:
- Do NOT sound like Netflix.
- Avoid generic synopsis language.
- Vary openings; never start with 'Potential fit' or 'You might'.
- Keep it tight; no markdown; valid JSON only.
```

### D6: "Because you watched X" chain prompt (Phase 2)
```
Create a short chain of 3-5 movies that starts from a seed movie and walks to a fresh recommendation.
Each step must explain the connective tissue (tone, craft, theme, filmmaker DNA).

Inputs:
- Taste profile: {taste_profile}
- Seed movie: {seed_title} ({seed_year})
- Candidate pool (verified TMDB IDs + titles): {candidate_list}

Return JSON array of steps:
[{"tmdb_id": 123, "reason": "because ..."}]

Rules:
- Each step must feel like a *natural* next pick.
- Keep it personal and opinionated.
- Valid JSON only.
```

### D7: Vibe page prompt (Phase 2)
```
Given a vibe definition and a user's taste profile, generate 1) a short vibe description and 2) 2-4 shelves/rows under that vibe.

Inputs:
- Taste profile: {taste_profile}
- Vibe: {vibe_id} / {vibe_title} / {vibe_description}
- Candidate pool: {candidate_list}

Return JSON:
{
  "vibe_blurb": "2 sentences, strong voice",
  "rows": [
    {"title": "row title", "description": "why this row exists for this user", "movie_tmdb_ids": [1,2,3]}
  ]
}

Rules:
- Avoid generic row titles.
- Strong, playful taste voice.
- Valid JSON only.
```

### D8: Taste-aware genre page prompt (Phase 2)
```
Generate a genre hub that feels filtered through the user's taste.

Inputs:
- Taste profile: {taste_profile}
- Genre: {genre_name}
- Candidate pool: {candidate_list}

Return JSON:
{
  "genre_blurb": "2 sentences, opinionated",
  "angles": [
    {"title": "angle title", "description": "why this angle suits them", "movie_tmdb_ids": [1,2,3]}
  ]
}

Rules:
- No generic 'Top {genre}' rows.
- Valid JSON only.
```

## Appendix E — Security Baseline

- Token fields encrypted with server-side key (`TOKEN_ENC_KEY` env var) before D1 write.
- All write routes require authenticated app session.
- Dependency failures must not leak provider response bodies containing sensitive data.
- httpOnly + Secure + SameSite=Lax cookies for app session.
- CORS restricted to app origin only.
