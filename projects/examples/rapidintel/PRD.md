# PRD — RapidIntel

## Vision
RapidIntel is a real-time web intelligence platform. It monitors any set of web properties, detects content changes, enriches those changes with AI context, and delivers actionable signals to the people who need to act on them.

Built entirely on Cloudflare's edge infrastructure — zero persistent servers, global by default.

## Problem
The web changes constantly — pricing pages, job listings, product pages, executive bios, investor relations. The people who most need to act on those changes (investors, competitive intel teams, sales reps) find out days or weeks late, if at all. Existing tools send dumb alerts ("page changed"). Nobody tells you *what changed, why it matters, and what to do about it.*

## Target Personas

### Primary — SaaS Competitive Intel
- **Who:** Product Marketing Managers, Competitive Intel leads, GTM teams at SaaS companies
- **Pain:** Competitors update pricing, ship features, change positioning — they find out from a customer or a sales loss, not proactively
- **Trigger:** "We lost a deal because the competitor dropped price last week and we didn't know"
- **Budget:** $500–$2,000/month
- **Action on signal:** Update battlecards, brief sales, adjust pricing

### Secondary — Investor & Corp Dev
- **Who:** VC associates, corp dev analysts, PE deal teams
- **Pain:** Deal flow is about timing. Companies signal distress, growth, or transition through web changes before any press release
- **Trigger:** "We missed that acquisition because we didn't see the exec departures and pricing changes three months ago"
- **Budget:** $5,000–$25,000/month (team seat pricing)
- **Action on signal:** Add to deal pipeline, flag to partner, initiate outreach

## Core Value Proposition
> "Know what changed on any website the moment it changes — and understand why it matters."

The differentiation is the **intelligence layer**: not raw diffs, but AI-enriched summaries with context, relevance scoring, and recommended action.

## Key Features (v1)

### 1. Signal Configuration
- Users define **watchlists** — sets of domains/URLs to monitor
- Each watchlist maps to a **persona template** (Competitive Intel, Investor, Sales Triggers)
- Under the hood: Firehose Lucene rules per watchlist, managed by RapidIntel

### 2. Real-Time Enriched Alerts
When Firehose delivers a match, AI enriches it via a durable Workflow:
- **What changed** — human-readable summary of the diff
- **Why it matters** — context relative to the watchlist intent
- **Recommended action** — e.g. "Update your pricing battlecard", "Flag to deal team"
- **Signal strength** — 0.0–1.0 confidence score

Delivered via: Slack webhook (real-time), email digest (daily/weekly), in-app feed

### 3. Signal Feed (Web App)
- Chronological feed of enriched signals per watchlist
- Filter by: watchlist, domain, date range, signal strength threshold
- Expandable detail: full diff view, original page content, AI summary
- Mark as actioned / dismiss / save

### 4. Watchlist Templates
- **Competitor Monitor** — pricing, features, job listings, messaging changes
- **Deal Flow Radar (Investor)** — funding signals, exec changes, product pivots
- **Sales Trigger** — prospect job postings, tech stack signals, expansion indicators

### 5. Delivery
- **In-app feed** — always-on, filterable (**v1**) 
- **Slack webhook** — real-time per signal, above configurable threshold (**v2**) 
- **Email digest** — daily or weekly summary per watchlist (Resend) (**v2**) 

### 6. Signal Quality Guardrails (v1)
- Enrichment only runs on meaningful changes (noise filtering before AI call)
- Parser tolerates missing `markdown` / missing `diff` fields
- Cost controls: skip low-signal updates and track filter rate

### 7. Frontend Interaction Reliability (v1)
- Tiered testing system: PR gate (fast smoke), manual release gate (live dev/prod), bug-regression retention
- PR-blocking E2E smoke coverage for critical signal interactions
- First-priority regression target: signal card clickability from feed to detail
- Manual live E2E gates: run against dev/preview before prod push and once after prod deploy
- CI/live failures retain traces/screenshots for fast root-cause analysis

### 8. Automatic Signal Pipeline Activation (v1 — CRITICAL)
- On first watchlist creation, if org has no Firehose tap, automatically provision one via Firehose management API
- Store encrypted tap credentials on the org record
- Create Firehose rule for watchlist domains under that tap
- Start StreamCoordinator DO to begin consuming SSE events
- Fail loudly in UI if pipeline cannot be activated (do not silently swallow)
- Without this, no user receives any signals — the product does not function

## Out of Scope (v1)
- Custom crawler (Firehose only)
- CRM integrations
- API access for customers
- Mobile app
- Billing/Stripe (design for it, implement in v2)
- Slack/email delivery channels (v2)

## Success Metrics (v1)
- 10 paying customers within 60 days of launch
- Average watchlist size: 5+ domains
- Alert open rate within 24h: >60%
- NPS >40 at 30 days

## Tech Stack
- **Runtime:** Cloudflare Workers (API, stream coordination, delivery)
- **Frontend:** React + Tailwind, deployed on Cloudflare Pages
- **Database:** Cloudflare D1 (SQLite) — users, orgs, watchlists, signals, deliveries
- **Object Storage:** Cloudflare R2 — raw page markdown + large diff blobs
- **Sessions/Cache:** Cloudflare KV — session tokens, org stream state mirror
- **Queue:** Cloudflare Queues — raw signal ingestion, delivery dispatch
- **Enrichment:** Cloudflare Workflows — durable, retryable Claude enrichment pipeline
- **SSE coordination:** Cloudflare Durable Objects — per-org Firehose stream coordinator
- **AI:** Anthropic Claude via Cloudflare AI Gateway
- **Email:** Resend (external, triggered from Workers)
- **Domain:** rapidintel.io (or similar)
