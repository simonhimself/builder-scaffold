# SPEC — RapidIntel

## Architecture Overview

```
Firehose SSE
     ↓
[Durable Object: StreamCoordinator] (per org)
     ↓  writes raw event
[Cloudflare Queue: signal-ingestion]
     ↓  consumer triggers + pre-filter
[Cloudflare Workflow: EnrichmentWorkflow]
     ↓  AI Gateway (global model config) → enriched signal
[D1: signals table]

Frontend:
[Cloudflare Pages (React)] → [Workers API] → [D1 + R2]
```

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Auth v1 | Email/password + JWT | OAuth deferred to v2 — faster to ship, sufficient for early access |
| Org model | Multi-seat, flat roles | Owner invites members by email. One role (member). No permission tiers in v1. |
| Delivery v1 | In-app feed only | Slack/email deferred to v2 — reduces v1 scope by 2 tasks |
| AI model | Global config via env var | Single model across all orgs; operator swaps in dashboard. Per-org API keys deferred to v2. |
| AI provider | AI Gateway (model-agnostic) | Default: Claude Haiku. Swappable to Kimi/Llama/etc. by changing `AI_MODEL` env var. |
| Noise handling | Provisional pre-filter defaults set from smoke behavior | Broad stream can spike quickly and markdown is often absent; filter before enrichment and re-tune after 24h validation report. |

## Cloudflare Products Used

| Layer | Product | Purpose |
|-------|---------|---------|
| Compute | Workers | API server, stream coordinator bootstrap |
| Compute | Durable Objects | Per-org Firehose SSE stream coordinator |
| Compute | Workflows | Durable enrichment pipeline per signal |
| Frontend | Pages | React app hosting + git deploys |
| Database | D1 | All relational data (users, orgs, signals, etc.) |
| Storage | R2 | Raw page markdown + large diff blobs |
| Cache | KV | Session tokens, org config cache |
| Async | Queues | Signal ingestion only (delivery queue removed for v1) |
| AI | AI Gateway | Model-agnostic proxy — logs, cost tracking, model swap via env var |
| Auth | Workers | JWT validation middleware |

## Data Model (D1 — SQLite)

### users
```sql
CREATE TABLE users (
  id            TEXT PRIMARY KEY,          -- UUID
  email         TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  org_id        TEXT NOT NULL REFERENCES organizations(id),
  role          TEXT NOT NULL DEFAULT 'member', -- owner|member
  invited_by    TEXT REFERENCES users(id),      -- NULL for first owner
  created_at    INTEGER NOT NULL               -- Unix ms
);
CREATE INDEX idx_users_org ON users(org_id);
```

### org_invites
```sql
CREATE TABLE org_invites (
  id         TEXT PRIMARY KEY,   -- UUID, also used as invite token
  org_id     TEXT NOT NULL REFERENCES organizations(id),
  email      TEXT NOT NULL,
  invited_by TEXT NOT NULL REFERENCES users(id),
  accepted_at INTEGER,           -- NULL = pending
  expires_at  INTEGER NOT NULL,  -- Unix ms (48h from creation)
  created_at  INTEGER NOT NULL
);
CREATE INDEX idx_invites_org   ON org_invites(org_id);
CREATE INDEX idx_invites_email ON org_invites(email);
```

### organizations
```sql
CREATE TABLE organizations (
  id                   TEXT PRIMARY KEY,
  name                 TEXT NOT NULL,
  plan                 TEXT NOT NULL DEFAULT 'free', -- free|starter|pro|enterprise
  firehose_tap_id      TEXT,           -- Firehose tap ID
  firehose_tap_token   TEXT,           -- AES-256 encrypted
  created_at           INTEGER NOT NULL
);
```

### watchlists
```sql
CREATE TABLE watchlists (
  id                TEXT PRIMARY KEY,
  org_id            TEXT NOT NULL REFERENCES organizations(id),
  name              TEXT NOT NULL,
  template_type     TEXT NOT NULL,     -- competitor|investor|sales
  domains           TEXT NOT NULL,     -- JSON array: ["example.com", ...]
  firehose_rule_id  TEXT,
  slack_webhook_url TEXT,
  slack_threshold   REAL NOT NULL DEFAULT 0.5,  -- 0.0–1.0
  digest_frequency  TEXT NOT NULL DEFAULT 'daily', -- daily|weekly|never
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);
CREATE INDEX idx_watchlists_org ON watchlists(org_id);
```

### signals
```sql
CREATE TABLE signals (
  id                     TEXT PRIMARY KEY,
  watchlist_id           TEXT NOT NULL REFERENCES watchlists(id),
  org_id                 TEXT NOT NULL,   -- denormalized for query perf
  firehose_rule_id       TEXT,
  url                    TEXT NOT NULL,
  domain                 TEXT NOT NULL,
  title                  TEXT,
  matched_at             INTEGER NOT NULL,  -- Unix ms
  diff_r2_key            TEXT,              -- R2 key for raw diff blob (if >16KB)
  diff_inline            TEXT,              -- JSON diff chunks (if ≤16KB)
  markdown_r2_key        TEXT,              -- R2 key for full page markdown
  status                 TEXT NOT NULL DEFAULT 'pending_enrichment',
                                            -- pending_enrichment|enriching|enriched|failed
  ai_summary             TEXT,
  ai_why_it_matters      TEXT,
  ai_recommended_action  TEXT,
  signal_strength        REAL,             -- 0.0–1.0
  page_type              TEXT,
  actioned_at            INTEGER,
  dismissed_at           INTEGER,
  saved_at               INTEGER,
  created_at             INTEGER NOT NULL
);
CREATE INDEX idx_signals_org_date   ON signals(org_id, matched_at DESC);
CREATE INDEX idx_signals_watchlist  ON signals(watchlist_id, matched_at DESC);
CREATE INDEX idx_signals_status     ON signals(status) WHERE status = 'pending_enrichment';
CREATE INDEX idx_signals_domain     ON signals(domain);
```

### signal_deliveries
```sql
CREATE TABLE signal_deliveries (
  id           TEXT PRIMARY KEY,
  signal_id    TEXT NOT NULL REFERENCES signals(id),
  channel      TEXT NOT NULL,  -- slack|email|in_app
  delivered_at INTEGER,
  status       TEXT NOT NULL,  -- pending|delivered|failed
  error        TEXT,
  created_at   INTEGER NOT NULL
);
CREATE INDEX idx_deliveries_signal ON signal_deliveries(signal_id);
```

## Migration Tool
Use `drizzle-orm` with `drizzle-kit` for schema management.
- Schema defined in `packages/db/schema.ts`
- Migrations generated to `packages/db/migrations/`
- Apply: `wrangler d1 migrations apply rapidintel-db --remote`
- Local: `wrangler d1 migrations apply rapidintel-db --local`

## Monorepo Structure

```
rapidintel/
├── apps/
│   ├── api/          # Cloudflare Worker (Hono) — REST API + Firehose bootstrap
│   ├── web/          # Cloudflare Pages (React + Vite + Tailwind)
│   └── workers/
│       ├── stream/   # Durable Object: StreamCoordinator
│       ├── enrich/   # Cloudflare Workflow: EnrichmentWorkflow
│       └── delivery/ # Queue consumer: DeliveryWorker
├── packages/
│   ├── db/           # Drizzle schema + migrations
│   ├── types/        # Shared TS types
│   └── firehose/     # Firehose API client
├── wrangler.jsonc    # Root wrangler config
└── package.json      # Workspaces root
```

## Durable Object: StreamCoordinator

One DO instance per organization. Manages the long-lived SSE connection to Firehose.

```typescript
// apps/workers/stream/StreamCoordinator.ts
export class StreamCoordinator extends DurableObject<Env> {
  private reader: ReadableStreamDefaultReader | null = null;
  private lastEventId: string | null = null;

  // Called by API Worker when org is created or DO needs waking
  async start(tapToken: string): Promise<void> { ... }

  // Connects to Firehose SSE, loops on events
  private async connect(tapToken: string): Promise<void> {
    const headers: Record<string, string> = {
      Authorization: `Bearer ${tapToken}`,
      Accept: 'text/event-stream',
    };
    if (this.lastEventId) headers['Last-Event-ID'] = this.lastEventId;

    const res = await fetch('https://firehose.diffbot.com/v1/stream', { headers });
    // Parse SSE, enqueue to signal-ingestion queue on each 'update' event
    // On disconnect: schedule alarm to reconnect with exponential backoff
  }

  // Alarm fires for reconnect backoff
  async alarm(): Promise<void> { ... }
}
```

**Design notes:**
- Per-org isolation — one DO ID per org ID (`idFromName(orgId)`)
- Reconnect on disconnect using `Last-Event-ID` header
- Backoff: 1s → 2s → 4s → 8s → 30s cap — stored in DO SQLite
- On `update` event: write raw signal to Queues (`signal-ingestion`)
- On `error`/`end` event: schedule alarm for reconnect
- Large diff payloads (>16KB) stored to R2, key written to signal record

## Cloudflare Workflow: EnrichmentWorkflow

Durable enrichment pipeline (4 steps in v1). Triggered by Queue consumer.

**Implementation notes from Firehose smoke test:**
- `document.markdown` is often absent/empty — treat as optional.
- `document.diff` / `diff.chunks` can be absent — skip enrichment if no usable diff text.
- High-volume broad rules are possible (observed 50 events in ~60s) — keep strict watchlist domain constraints and pre-filter before enrichment.

```typescript
// apps/workers/enrich/EnrichmentWorkflow.ts
import { WorkflowEntrypoint, WorkflowStep, WorkflowEvent, NonRetryableError } from 'cloudflare:workers';

type EnrichParams = { signalId: string; watchlistId: string; orgId: string };

export class EnrichmentWorkflow extends WorkflowEntrypoint<Env, EnrichParams> {
  async run(event: WorkflowEvent<EnrichParams>, step: WorkflowStep) {
    const { signalId, watchlistId } = event.payload;

    // Step 1: Load signal + watchlist from D1
    const { signal, watchlist } = await step.do('load-signal', async () => {
      const signal = await this.env.DB.prepare('SELECT * FROM signals WHERE id = ?')
        .bind(signalId).first();
      const watchlist = await this.env.DB.prepare('SELECT * FROM watchlists WHERE id = ?')
        .bind(watchlistId).first();
      if (!signal || !watchlist) throw new NonRetryableError('Signal or watchlist not found');
      return { signal, watchlist };
    });

    // Step 2: Fetch diff content (inline or R2)
    const diffContent = await step.do('fetch-diff', async () => {
      if (signal.diff_inline) return signal.diff_inline;
      if (signal.diff_r2_key) {
        const obj = await this.env.R2.get(signal.diff_r2_key);
        return obj ? await obj.text() : null;
      }
      throw new NonRetryableError('No diff content available');
    });

    // Step 3: Enrich via AI Gateway (model selected by env vars)
    const enrichment = await step.do('model-enrich', {
      retries: { limit: 3, delay: '10 seconds', backoff: 'exponential' },
      timeout: '60 seconds',
    }, async () => {
      const prompt = buildEnrichmentPrompt(watchlist.template_type, signal, diffContent);
      const res = await fetch(
        `https://gateway.ai.cloudflare.com/v1/${this.env.CF_ACCOUNT_ID}/${this.env.AI_GATEWAY_ID}/compat/chat/completions`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.env.AI_API_KEY}`,
          },
          body: JSON.stringify({
            model: `${this.env.AI_PROVIDER}/${this.env.AI_MODEL}`,
            messages: [{ role: 'user', content: prompt }],
          }),
        }
      );
      if (!res.ok) throw new Error(`AI Gateway API error: ${res.status}`);
      return parseEnrichmentResponse(await res.json());
      // Returns: { summary, why_it_matters, recommended_action, signal_strength }
    });

    // Step 4: Write enrichment to D1
    await step.do('save-enrichment', async () => {
      await this.env.DB.prepare(`
        UPDATE signals SET
          ai_summary = ?, ai_why_it_matters = ?, ai_recommended_action = ?,
          signal_strength = ?, status = 'enriched'
        WHERE id = ?
      `).bind(
        enrichment.summary, enrichment.why_it_matters,
        enrichment.recommended_action, enrichment.signal_strength,
        signalId
      ).run();
    });

  }
}
```

**Enrichment prompt strategy (template-aware):**

```typescript
function buildEnrichmentPrompt(templateType: string, signal: Signal, diff: string): string {
  const personas = {
    competitor: `You are a competitive intelligence analyst. A competitor's website changed.
      Analyze the diff and respond in JSON with keys: summary, why_it_matters, recommended_action, signal_strength (0.0-1.0).
      Focus on: pricing changes, feature launches, positioning shifts, hiring signals.`,
    investor: `You are a VC analyst tracking portfolio and deal targets.
      A company's website changed. Respond in JSON with: summary, why_it_matters, recommended_action, signal_strength.
      Focus on: executive changes, product pivots, funding signals, distress or growth indicators.`,
    sales: `You are a sales intelligence analyst.
      A prospect's website changed. Respond in JSON with: summary, why_it_matters, recommended_action, signal_strength.
      Focus on: hiring sprees, tech stack changes, leadership changes, expansion signals.`,
  };
  return `${personas[templateType] ?? personas.competitor}

URL: ${signal.url}
Title: ${signal.title ?? 'Unknown'}
Domain: ${signal.domain}

Page diff:
${diff}

Respond ONLY with valid JSON, no markdown fences.`;
}
```

## Queue: signal-ingestion

- **Producer:** StreamCoordinator DO (one message per Firehose `update` event)
- **Consumer:** Worker that writes raw signal to D1, stores large diffs to R2, then triggers EnrichmentWorkflow
- **Batch size:** 10 (configurable)
- **Retry:** 3 attempts, DLQ enabled
- **Pre-filter (provisional RI-000 defaults):**
  - Skip if `document.diff` is missing, not an object, or has `chunk_count < 2`.
  - Skip if combined diff chunk text length `< 300` chars after trimming.
  - Skip if `domain` is missing/invalid or not in the watchlist rule's explicit domain set.
  - Do not require `document.markdown` for enrichment; treat markdown as optional.
  - Revisit thresholds after 24h validation report (`firehose-validation-*.json`).

**Enrichment cost risk (smoke-test provisional go/no-go):**
- **No-Go** for broad/unconstrained rules (observed high event burst rates).
- **Go** for v1 when using explicit watchlist domains + above pre-filter defaults; confirm with 24h report before scaling.
- **Idempotency:** dedupe by `sourceEventKey = tapId:ruleId:url:matched_at`
- **Consumer logic:**

```typescript
export default {
  async queue(batch: MessageBatch<RawFirehoseEvent>, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      try {
        const event = msg.body;
        const signalId = crypto.randomUUID();

        // Build idempotency key from Firehose fields (dedupe retries/reconnects)
        const sourceEventKey = `${event.tapId}:${event.ruleId}:${event.url}:${event.timestamp}`;

        // Diff can be missing — keep optional
        let diffInline: string | null = null;
        let diffR2Key: string | null = null;
        const hasDiff = event.diff && Array.isArray(event.diff.chunks) && event.diff.chunks.length > 0;
        if (hasDiff) {
          const diffJson = JSON.stringify(event.diff);
          if (diffJson.length <= 16384) {
            diffInline = diffJson;
          } else {
            diffR2Key = `diffs/${signalId}.json`;
            await env.R2.put(diffR2Key, diffJson, { httpMetadata: { contentType: 'application/json' } });
          }
        }

        // markdown can be missing/empty
        let markdownR2Key: string | null = null;
        if (event.markdown && event.markdown.trim().length > 0) {
          markdownR2Key = `pages/${signalId}.md`;
          await env.R2.put(markdownR2Key, event.markdown, { httpMetadata: { contentType: 'text/markdown' } });
        }

        // Write signal to D1
        await env.DB.prepare(`
          INSERT INTO signals (id, watchlist_id, org_id, firehose_rule_id, url, domain, title,
            matched_at, diff_inline, diff_r2_key, markdown_r2_key, status, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending_enrichment', ?)
        `).bind(
          signalId, event.watchlistId, event.orgId, event.ruleId,
          event.url, event.domain, event.title ?? null,
          event.timestamp, diffInline, diffR2Key, markdownR2Key, Date.now()
        ).run();

        // Trigger enrichment workflow
        await env.ENRICHMENT_WORKFLOW.create({
          id: `enrich-${signalId}`,
          params: { signalId, watchlistId: event.watchlistId, orgId: event.orgId },
        });

        msg.ack();
      } catch (e) {
        msg.retry();
      }
    }
  }
};
```

## Delivery (v1 scope)

- v1 ships **in-app feed only**.
- Slack/email delivery is deferred to v2.
- Keep `signal_deliveries` schema as forward-compatible placeholder, but do not implement delivery worker in RI-001…RI-015.

## API Server (Hono on Workers)

Using `hono` for routing on Cloudflare Workers.

```
POST   /api/auth/signup
POST   /api/auth/login
POST   /api/auth/refresh

GET    /api/watchlists
POST   /api/watchlists
PUT    /api/watchlists/:id
DELETE /api/watchlists/:id

GET    /api/org                          # current org + members list
POST   /api/org/invites                  # send invite (owner only)
GET    /api/org/invites                  # list pending invites (owner only)
DELETE /api/org/invites/:id              # revoke invite (owner only)
POST   /api/org/invites/:token/accept    # accept invite (unauthenticated)

GET    /api/signals?watchlist_id=&domain=&strength_min=&page=&limit=
GET    /api/signals/:id
POST   /api/signals/:id/action   { action: 'actioned'|'dismissed'|'saved' }
```

**Auth:** Email/password (bcryptjs). JWT via `@tsndr/cloudflare-worker-jwt` (HS256). JWT payload: `{ userId, orgId, role, email }`. Tokens stored (hashed) in KV for revocation. Org-scoped DB queries enforced via middleware that injects `{ userId, orgId, role }` into all Hono handler contexts. Google OAuth deferred to v2.

**Invite flow:** Owner calls `POST /api/org/invites` with email → row created in `org_invites` with UUID token → Resend email sent with link `/accept-invite?token=<uuid>` → recipient hits `POST /api/org/invites/:token/accept` with their name + password → user created, invite marked accepted. Token expires 48h. No auth required to call the accept endpoint.

**Firehose rule management** is called synchronously from watchlist create/update/delete handlers — no separate worker needed for this.

## Frontend (Cloudflare Pages + React)

Framework: **React + Vite + Tailwind CSS**
Deploy: Cloudflare Pages with git integration (main → production, PRs → preview)
API calls: relative `/api/...` path, Pages `_redirects` proxies to Workers API worker

### Pages

1. **`/auth`** — Sign up / log in
2. **`/onboarding`** — Create org → add watchlist → domains → template → Slack (optional)
3. **`/`** — Signal feed: filterable, paginated, real-time poll every 30s
4. **`/signals/:id`** — Signal detail: diff viewer (green ins / red del), AI fields, action buttons
5. **`/watchlists`** — Manage watchlists + delivery settings
6. **`/settings`** — Org/account settings

### Testing System (Tiered)

- Runner: Playwright (`@playwright/test`) + Vitest API/unit suites.
- Scope priority: critical interaction path from signal feed card → signal detail view, plus ingestion/API integrity.

**Tier 1 — PR gate (fast, mandatory)**
- Mocked smoke specs in `e2e/smoke`:
  - `signals.click.opens-detail.spec.ts`
  - `signals.click.after-filter.spec.ts`
  - `signals.regression.unclickable-after-action.spec.ts`
- CI gate executes fail-fast order: `npm run test:e2e:smoke` → `npm run test:signal-feed` → `npm run test:signal-ingestion`.
- On failure, CI uploads tier logs + Playwright artifacts (`playwright-report`, `test-results`).

**Tier 2 — Release gate (manual, mandatory)**
- Live integration spec in `e2e/live`:
  - `signals.clickability.live.spec.ts`
- Commands:
  - Pre-prod: `npm run release:gate:preprod`
  - Post-prod: `npm run release:gate:postprod`
- No periodic automation/canaries by policy.

**Tier 3 — Regression discipline (mandatory)**
- Every production bug must add a retained automated reproducer test.

Selector policy: prefer stable `data-testid` on high-risk interactive elements (`auth-tab-login`, `login-email`, `login-password`, `login-submit`, `signal-card`, `domain-filter`, `watchlist-filter`, `strength-filter`, `signal-detail-title`).

Failure artifacts: `trace: retain-on-failure`, `screenshot: only-on-failure`.

Reference: `docs/testing-policy.md`.

## Firehose Tap + Rule Lifecycle (CRITICAL PATH)

### Tap Provisioning (auto, on first watchlist creation)
When an org creates its first watchlist and has no `firehose_tap_id`:
1. Call `FirehoseClient.createTap(orgName)` using `FIREHOSE_API_KEY`
2. Encrypt returned `tap.token` via AES-256-GCM (`encryptToken`)
3. Store `firehose_tap_id` + encrypted token on `organizations` row
4. Proceed to rule creation + DO activation below

If tap provisioning fails → return 500 to user with clear error (do NOT silently skip).

### Rule Management (per watchlist)
Per watchlist, RapidIntel manages one Firehose rule scoped to the org's tap:
- **Rule value:** `domain:"example.com" OR domain:"competitor.com"`
- **Quality filter:** `true` (default)
- On watchlist create → `POST /v1/rules` (Firehose API)
- On domain list change → `PUT /v1/rules/:id`
- On watchlist delete → `DELETE /v1/rules/:id`

### StreamCoordinator Activation (auto, after tap + rule are live)
After successful watchlist creation with a live rule:
1. Decrypt org tap token
2. Get DO stub: `env.STREAM_COORDINATOR.get(env.STREAM_COORDINATOR.idFromName(orgId))`
3. Call `stub.start(decryptedTapToken)` to begin SSE consumption

The `firehose_tap_token` is stored AES-256 encrypted in D1. A utility in `packages/firehose/` wraps all Firehose API calls.

## Wrangler Configuration (overview)

```jsonc
// wrangler.jsonc
{
  "name": "rapidintel-api",
  "main": "apps/api/src/index.ts",
  "compatibility_date": "2025-01-01",
  "d1_databases": [
    { "binding": "DB", "database_name": "rapidintel-db", "database_id": "..." }
  ],
  "r2_buckets": [
    { "binding": "R2", "bucket_name": "rapidintel-blobs" }
  ],
  "kv_namespaces": [
    { "binding": "KV", "id": "..." }
  ],
  "queues": {
    "producers": [
      { "binding": "SIGNAL_QUEUE", "queue": "signal-ingestion" }
    ],
    "consumers": [
      { "queue": "signal-ingestion", "max_batch_size": 10, "max_retries": 3, "dead_letter_queue": "signal-ingestion-dlq" }
    ]
  },
  "durable_objects": {
    "bindings": [
      { "name": "STREAM_COORDINATOR", "class_name": "StreamCoordinator" }
    ]
  },
  "workflows": [
    { "name": "ENRICHMENT_WORKFLOW", "binding": "ENRICHMENT_WORKFLOW", "class_name": "EnrichmentWorkflow" }
  ],
  "vars": {
    "CF_ACCOUNT_ID": "...",
    "AI_GATEWAY_ID": "rapidintel-gateway"
  }
}
```

## Environment Variables / Secrets

```bash
# Secrets — set via: wrangler secret put <NAME>
AI_API_KEY=                  # API key for active AI provider (Claude, Kimi, etc.)
FIREHOSE_API_KEY=            # Diffbot/Firehose master key
ENCRYPTION_KEY=              # AES-256-GCM key for tap token encryption
JWT_SECRET=                  # JWT signing secret (HS256)
RESEND_API_KEY=              # Email (v2 — kept for future use)

# Vars — set in wrangler.jsonc [vars]
CF_ACCOUNT_ID=               # Cloudflare account ID
AI_GATEWAY_ID=rapidintel-gateway
AI_PROVIDER=anthropic        # anthropic | moonshot | openai | workersai
AI_MODEL=claude-3-5-haiku-20241022
```

`.dev.vars` file used for local development (gitignored).

## AI Gateway Configuration

- Gateway name: `rapidintel-gateway`
- Auth: enabled (authenticated gateway)
- Logging: enabled with custom metadata (orgId, watchlistId, signalId)
- Rate limiting: 500 req/min (sliding window)
- Caching: disabled (all enrichment requests are unique)

### Model Abstraction

The enrichment worker selects provider + model via env vars. No code change needed to swap models.

```bash
AI_PROVIDER=anthropic          # anthropic | moonshot | openai | workersai
AI_MODEL=claude-3-5-haiku-20241022
```

The AI Gateway unified API endpoint (`/compat/chat/completions`) handles provider routing:

```
https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/compat/chat/completions
```

Pass `{provider}/{model}` as the `model` field — e.g. `anthropic/claude-3-5-haiku-20241022` or `moonshot/moonshot-v1-8k`. Provider API key passed via `Authorization: Bearer` (stored as Worker secret). When switching providers, only `AI_PROVIDER`, `AI_MODEL`, and the corresponding API key secret need to change.

**v2 extension point:** Per-org API key override — orgs can supply their own key stored encrypted in D1, bypassing the global key. Architecture already supports this; just add a key lookup step before the AI call.

## Security

- Firehose tap tokens: AES-256-GCM encrypted at rest in D1
- All API routes: JWT required, org isolation enforced at query level
- D1 queries: always include `org_id = ?` binding (never cross-org leakage)
- R2 objects: not publicly accessible; only accessible via signed Worker responses
- Secrets: managed via `wrangler secret put`, never in source

## Deployment

| Component | Deploy Command |
|-----------|---------------|
| API Worker + DOs + Workflows | `wrangler deploy` (apps/api) |
| Queue consumers (signal-ingestion) | `wrangler deploy` (apps/workers) |
| Frontend | `wrangler pages deploy dist` or git push → auto-deploy |
| DB migrations | `wrangler d1 migrations apply rapidintel-db --remote` |
| R2 bucket | `wrangler r2 bucket create rapidintel-blobs` |
| Queue creation | `wrangler queues create signal-ingestion` etc. |

All infra defined in `wrangler.jsonc` — no Terraform/IaC needed for v1.

## Phase Plan

### Phase 1 — Core (MVP)
- Scaffold: monorepo, Drizzle schema, wrangler config
- Auth: email/password + JWT, multi-seat invite flow
- Watchlist CRUD + Firehose rule management
- StreamCoordinator DO + signal-ingestion queue
- EnrichmentWorkflow (model-agnostic via AI Gateway)
- Signal feed + signal detail (React)
- Org settings + invite management (React)

### Phase 2 — Delivery + Polish
- Slack webhook delivery per watchlist
- Email digests (Resend)
- Signal strength filtering
- Billing / Stripe (plan gating)
- Google OAuth

### Phase 3 — Growth
- CRM integrations (HubSpot, Salesforce)
- Customer API (API key auth, scoped read access)
- Multi-user orgs + seat management
- Investor persona: deal-flow specific features
