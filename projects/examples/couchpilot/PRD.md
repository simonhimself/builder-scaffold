# PRD.md - Couchpilot

**Version:** 0.3  
**Date:** 2026-03-26  
**Owner:** Blue Builder + Simon  
**Status:** Draft (PLAN-ready, decisions locked)

---

## 0) Kickoff Contract (Builder Intake)

- **Goal:** Build a personal movie recommendation copilot that turns natural-language intent + Trakt watch history into high-confidence, constraint-aware movie picks.
- **Why now:** Current discovery tools optimize engagement, not decision quality. Simon + Brittany have immediate dogfooding demand and existing Trakt data.
- **Acceptance Criteria (MVP release gate):**
  1. User can sign in with Trakt OAuth and complete initial sync of watched/rated movies.
  2. User can submit a natural-language query and receive 3-5 recommendations with personalized reasoning.
  3. Every recommendation shown to user is verified against TMDB (exists, metadata available, artwork available).
  4. Query constraints (runtime, mood, genre intent, who’s watching) are honored; constraints are never silently ignored.
  5. User can add a recommendation to Trakt watchlist and mark a recommendation as watched from the app UI.
  6. App provides a readable taste profile generated from user history and keeps it cached/fresh.
  7. End-to-end happy path is usable on mobile and desktop in dark mode.
- **Constraints:**
  - **Stack:** Cloudflare Pages + Workers + D1 + KV, Trakt API, TMDB API, Claude Sonnet.
  - **Deadline:** MVP targeted in ~2-3 weeks of focused work.
  - **Budget:** personal-use target <= $10/month (expected ~$1-5/month).
  - **Non-goals (MVP):** multi-user taste splitting, show recommendations, streaming-provider integration, social features, push notifications.
- **Artifacts path:** `projects/couchpilot/`

---

## 1) Vision

- **One-liner value proposition:** Your couch. Your taste. Your pilot.
- **Why this matters now:** Movie-night decision friction is high, and existing recommendation systems do not reason about nuanced constraints or couple dynamics.

## 2) Target Users

### Primary user
- **Who:** Simon + Brittany (shared Trakt account, frequent movie watchers).
- **Current workflow:** Scroll across platforms, cross-check memory/watch history manually, pick late.
- **Pain points:** Decision paralysis, generic recommendations, poor support for two-person constraints.

### Secondary user (optional)
- **Who:** Trakt users who actively log watch/rating data.
- **Why they matter:** Data-rich users get strong personalization quickly and can validate product fit.

## 3) Problem Statement

- **Core problem to solve:** Turn “what should we watch right now?” into a fast, trustworthy decision.
- **Current alternatives and why they fail:**
  - Netflix/streaming homepages: engagement-optimized, low transparency.
  - Trakt lists: strong data, weak reasoning layer.
  - Letterboxd/social recs: discovery-heavy, not intent-and-constraint driven.
- **Consequences if not solved:** Ongoing decision fatigue, watch-time wasted on browsing, lower confidence in recommendations.

## 4) Product Principles

1. **Two equal entry points, one brain:** Chat and Browse both map to the same taste engine.
2. **Reason, don’t just rank:** Every recommendation must explain *why this user* should care.
3. **Constraint respect is mandatory:** Runtime/mood/who constraints are hard requirements, not suggestions.
4. **No hallucinated picks:** User-facing recommendations must be verified against trusted movie metadata.
5. **Fast feedback loops:** Personalization should improve quickly from user actions (watchlist, watched, dismiss).

## 5) Scope

### In scope (MVP)
- Trakt OAuth login + token lifecycle handling.
- Trakt watch/rating sync into D1.
- Natural-language recommendation endpoint with personalization.
- Minimal chat-style recommendation UI with follow-up refinement.
- Recommendation cards with poster, runtime, match rationale, caveat.
- One-click Trakt actions: add to watchlist, mark watched.
- Taste profile generation + caching.
- Dark-mode responsive frontend.

### Out of scope (for MVP)
- Separate per-person profiles on shared account.
- Streaming availability (“where to watch”).
- TV show recommendations.
- Social/polling/notification features.
- Complex browse surfaces (smart shelves/vibes/chains) as hard MVP requirement.

## 6) Feature Requirements (MVP)

### F1: Identity + Data Foundation (Trakt OAuth + Sync)
- **Requirements:**
  - OAuth sign-in/out and token refresh.
  - Initial sync of watched/rated movie history.
  - Sync state persisted with last cursor/timestamp.
- **Acceptance criteria:**
  - New user can authenticate and complete first sync without manual intervention.
  - Re-sync is incremental and does not duplicate history records.

### F2: Recommendation Engine API
- **Requirements:**
  - Accept free-text query and structured constraints.
  - Build prompt with taste profile + recent watch context.
  - Verify LLM-selected titles against TMDB before response.
- **Acceptance criteria:**
  - API returns 3-5 verified recommendations with personalized why + caveat + confidence.
  - Invalid/unverified items are filtered and replaced before response.

### F3: Recommendation UX (Chat-first MVP)
- **Requirements:**
  - Query input, response cards, refinement loop.
  - Explicit display of why match score/fit rationale.
  - Mobile and desktop usability.
- **Acceptance criteria:**
  - User can complete query -> refine -> select flow in under 2 minutes.
  - Follow-up question reuses prior context in same session.

### F4: Action Layer (Trakt write-back)
- **Requirements:**
  - Add recommendation to Trakt watchlist.
  - Mark recommendation as watched.
  - Reflect action success/failure in UI.
- **Acceptance criteria:**
  - Action success updates Trakt and local state.
  - Action failure is surfaced with recoverable UX state.

### F5: Taste Profile
- **Requirements:**
  - Generate concise profile from watch/rating history.
  - Cache profile with refresh policy.
- **Acceptance criteria:**
  - User sees a non-generic profile tied to their own history.
  - Profile refreshes after meaningful history changes.

## 7) Non-Functional Requirements

- **Performance targets:**
  - Recommendation API p95 <= 4.0s for warmed path.
  - Read endpoints p95 <= 500ms where no LLM call is required.
- **Reliability targets:**
  - Graceful fallback when LLM/TMDB/Trakt errors occur.
  - Idempotent sync writes and safe retry behavior.
- **Security/privacy requirements:**
  - Store third-party access tokens encrypted at rest.
  - Use cookie-based app session (httpOnly + Secure + SameSite=Lax) and keep provider tokens server-side only.
  - Secrets only in Worker/Pages environment vars (never client).
  - No leakage of tokens/prompts in client-visible logs.
- **Cost constraints:**
  - Keep projected monthly model/API usage <= $10 for personal usage.
- **Compliance constraints (if any):**
  - Respect Trakt/TMDB API terms and attribution requirements.

## 8) Success Metrics

- **Product metrics:**
  - Recommendation -> “watchlist add” rate.
  - Recommendation -> “marked watched” rate.
  - Median time-to-pick (query to chosen title).
- **Technical metrics:**
  - Verified recommendation rate (target: 100% user-visible titles verified).
  - API latency and error rates by dependency (Trakt/TMDB/LLM).
- **Business metrics:**
  - Weekly active usage by primary dogfooding users.
  - Monthly infra + model cost against budget target.

## 9) Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| LLM outputs nonexistent/wrong titles | High trust hit | Verify against TMDB before responding; replace invalid items |
| Shared-account taste ambiguity | Medium relevance drop | Keep MVP profile global; defer explicit split model to next phase |
| Trakt/TMDB limits or outages | Medium reliability hit | Cache aggressively, retry with backoff, degrade read-only where possible |
| Recommendation quality too generic | High adoption risk | Prompt iteration + explicit “why this user” constraints + logging |
| Scope creep from browse mode | Delivery risk | Freeze MVP to chat-first core; defer shelves/vibes to Phase 1.5 |

## 10) Locked Product/Implementation Decisions (2026-03-26)

1. **Candidate pool strategy:** Use **hybrid** mode — LLM proposes candidates, worker verifies/replaces via TMDB, and prompt includes TMDB trending/new-release context as recency hints.
2. **Profile refresh policy:** **Event-driven with floor** — regenerate on new ratings or 10+ new watches since last profile, with weekly fallback refresh.
3. **Browse expansion timing:** Smart shelves/vibes remain **post-MVP Phase 1.5** and are started only after usage proof from chat-first MVP (2-3 weeks dogfooding).
4. **Session model:** Use **cookie-based app sessions** (httpOnly/secure/SameSite) with Worker-managed Trakt token lifecycle server-side.

---

## 11) Launch Readiness Definition

A project is launch-ready only when all are true:
1. Critical acceptance criteria are met and verified.
2. Required tests are passing with evidence.
3. Security/privacy baseline is validated for deployment environment.
4. PRD, SPEC, and TASKS agree on implemented vs deferred scope.

---

*This PRD is the product truth. Update it when product scope or success criteria change.*
