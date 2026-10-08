# Connection Lifecycle

## Root Causes

- Notification accept/decline swallowed API errors and removed the card regardless.
- Delayed list reads could restore requests already handled locally.
- Feed, profile and notifications held independent connection state.
- `follows` and `notifications` were not published to Realtime.
- Historical `follow` notifications always displayed the original request wording.
- Reciprocal legacy edges could duplicate people and counts.

## Changes

`ConnectionStore` owns the current user's authoritative connection snapshot and
per-person mutation state. Pending rows are removed only after a successful server
transition. Generations reject pre-mutation and previous-account reads. Failed
reads preserve confirmed state. Accepted edges take precedence over legacy
pending duplicates. Every connection surface reads this same store.

`transition_connection` derives the caller from `auth.uid()` and serializes a
pair's transitions using a transaction advisory lock. Repeated requests are
idempotent, crossed requests reuse the existing incoming request, and stale
cancel/decline actions cannot disconnect accepted people. Explicit disconnect is
separate. Existing accepted connections and historical notifications are retained.

Realtime watches incoming/outgoing edges and recipient notifications while the
app is active. A fresh snapshot follows the PostgreSQL subscription-ready event,
not just the WebSocket join reply. An eight-second authoritative recheck covers
missed events or broken sockets; foregrounding and opening the inbox also refresh.
This is foreground synchronization, not background push notification delivery.

The inbox renders connection requests only from current pending edges, not old
notification history. The badge combines pending requests with unread non-follow
notifications. Read acknowledgements cover only IDs actually fetched.

## Verification

- `ConnectionStoreTests.swift`: delayed reads after acceptance, subscription events
  during reads, failures/retry, double taps, reciprocal rows, and account changes.
- `ConnectionRepositoryTests.swift`: typed RPC request/cancel and accepted-edge safety.
- `ConnectionLifecycle.sql`: actual PostgreSQL transitions, idempotency, RLS caller
  identity, cancelled-request acceptance, legacy deduplication. Run inside a
  transaction with migration 0026 installed; roll back afterwards.
- `node Tests/ConnectionLifecycleLive.mjs`: local Supabase only. Creates two
  temporary authenticated users, exercises REST + Realtime and simultaneous
  requests, then deletes only those test accounts. Requires local migration 0026.

No tests send requests to existing users. CLI credentials are read in memory and
not logged. Production rollout uses migration `0026_connection_lifecycle.sql`.
