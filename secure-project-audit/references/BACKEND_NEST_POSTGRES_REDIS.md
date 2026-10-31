# Backend Security Reference — Node.js, NestJS, PostgreSQL, Redis

Use this reference when the backend contains the canonical business logic, authentication, authorization, and storage. The client is never a trusted enforcement boundary.

## 1. Architecture inventory

Record the complete runtime path for each sensitive action:

`client → proxy/load balancer → HTTP/Socket.IO/WebSocket → middleware → authentication → guard/policy → validation/serialization → service/domain rule → ORM/query → PostgreSQL transaction → audit/outbox → Redis/cache/queue → worker/broadcast → client reconciliation`

Inventory:

- Node and package-manager versions, exact lockfile, Nest/Express/Fastify version, ORM/query layer, migration tool, database driver and pool;
- modules/controllers/resolvers/gateways, global and route guards, pipes, interceptors, filters, middleware, scheduled jobs and workers;
- PostgreSQL roles, schemas, extensions, functions, triggers, RLS policies, grants, default privileges, backups and connection paths;
- Redis roles: cache, session/revocation, throttling, locks, queue, Streams, Pub/Sub, presence and real-time adapter;
- external services, webhooks, object storage, payment/printer/email/SMS side effects and administrator tools.

## 2. Node.js and process boundary

- Production must use a currently supported Active LTS or Maintenance LTS Node line. Record runtime and base-image patch versions.
- Validate all required environment values at startup. Reject weak defaults, unknown production mode, empty secrets, insecure URLs, wildcard credentialed CORS and missing TLS configuration.
- Run as a non-administrator/non-root identity with the smallest filesystem, network and process privileges.
- Consider the stable Node Permission Model for narrowly scoped services. Explicitly allow only required filesystem/network/worker/child-process/addon access. Treat it as defense in depth, not a sandbox or authorization system.
- Disable or restrict inspector/debug endpoints, diagnostic reports, source maps, Swagger/OpenAPI, metrics, health details and stack traces in production.
- Set request, response, header, body, upload, decompression, timeout, keep-alive, connection and concurrency limits at the actual proxy and application boundaries.
- Handle shutdown, uncaught rejection/exception and worker termination without acknowledging uncommitted work or losing in-flight audit/outbox records.

## 3. NestJS trusted-boundary checklist

### Authentication

- One authentication service validates algorithm, issuer, audience, signature, expiry, not-before, token type, subject, session/device identifier and revocation state.
- Access tokens are short-lived. Refresh tokens are rotated, reuse-detected and stored hashed/server-side when practical.
- Password recovery, enrollment and bootstrap flows cannot enumerate accounts, reuse codes, bypass MFA/step-up or create a second initial administrator.
- Device tokens, join keys, API keys and service credentials are distinct from user authorization and cannot silently grant administrator rights.

### Authorization

- Guards/policies enforce action + object + tenant + mutable fields. Authentication alone is never authorization.
- The same policy applies to HTTP, GraphQL, WebSocket/Socket.IO, queue consumers, cron, workers, imports, exports, admin scripts and internal callbacks.
- Test disabled users, expired subscriptions/licenses, revoked devices and role downgrades immediately or within a documented bounded cache TTL.
- Never authorize with a client-provided `role`, `isAdmin`, `tenantId`, owner, price, approval or UI route.

### Validation and serialization

- Use global validation with explicit DTOs. Prefer `whitelist: true` and `forbidNonWhitelisted: true` where compatibility permits.
- Treat implicit type transformation carefully; test `"0"`, `"false"`, huge integers, `NaN`, nested arrays/objects, duplicate keys and prototype-related inputs.
- Persistence entities are not directly bound to request bodies. Map allowed fields explicitly.
- Response serializers exclude password hashes, tokens, internal flags, deleted data, cross-tenant references and excessive nested relations.
- File validators check content signature where practical, not only extension/MIME supplied by the client.

### WebSockets and Socket.IO

- Authenticate the handshake and authorize every event/room/subscription. A valid socket is not permission for every event.
- Apply gateway guards, pipes, rate limits, payload limits, event allowlists and sanitized exception handling.
- Do not trust room names supplied by clients. Construct tenant/user/device rooms server-side.
- Revalidate sensitive permissions and revocation for long-lived sockets.
- Keep `skipMiddlewares` disabled for recovered Socket.IO sessions unless revocation is enforced by another tested mechanism.
- Reject replayed acknowledgements and event IDs across users, devices or tenants.

### Browser-specific controls

- Exact CORS origin allowlist. Never combine credentialed CORS with `*`.
- If cookies authenticate state-changing requests, configure `Secure`, `HttpOnly`, appropriate `SameSite`, origin checks and CSRF protection.
- Helmet/security headers are defense in depth; still fix output encoding, CSP design, uploads and authorization.
- Configure `trust proxy` only for known proxy hops; otherwise client IP, secure-cookie and throttling logic can be spoofed.

## 4. Server-side business invariants

The server recomputes or validates from canonical data:

- price, tax, discount, total, cost, balance, commission and currency;
- inventory quantities, warehouse ownership, recipe/material effects and non-negative/allowed bounds;
- booking overlap, rental duration, attendance time and minimum/rounding rules;
- refund/return eligibility, original transaction ownership and maximum refundable quantity/value;
- approval state, role, tenant, owner, creator, sequence, timestamps and audit actor;
- licensing status, device enrollment, feature entitlement and trial redemption;
- sync dependencies, entity version and conflict outcome.

Use database constraints and transactions for invariants; client checks and service checks alone are insufficient.

## 5. PostgreSQL security boundary

### Connection and identity

- Restrict `listen_addresses`, firewall and `pg_hba.conf` to required networks/identities.
- Prefer `scram-sha-256`; migrate away from deprecated MD5 password storage/authentication.
- Use TLS for remote connections and verify the server identity (`verify-full` or equivalent) where feasible.
- Separate runtime, migration, backup/restore, read-only analytics and administrator roles. Runtime must not be superuser, database owner or schema owner without a proven need.
- Store credentials outside source/build artifacts and rotate them with a tested overlap plan.

### Schemas and privileges

- Revoke unnecessary `CREATE` on `public` and any schema appearing in a privileged `search_path`.
- Schema-qualify security-sensitive functions/tables and set a safe `search_path` inside `SECURITY DEFINER` functions.
- Review grants and default privileges for tables, sequences, functions, schemas and future migrations.
- Restrict extensions and untrusted procedural languages.

### Row-Level Security

When used as tenant defense in depth:

- enable RLS and test no-policy default deny;
- runtime role must not own the table and must not have `BYPASSRLS`;
- evaluate `FORCE ROW LEVEL SECURITY` for owner paths;
- separate `USING` visibility from `WITH CHECK` write constraints;
- test SELECT/INSERT/UPDATE/DELETE, upsert, bulk operations, joins, views, reports, functions, COPY/import and background jobs;
- set tenant/user context transaction-locally and reset it before pooled connection reuse;
- test PgBouncer/pooling mode compatibility and failure paths where context could leak to the next request.

### Transactions and concurrency

- Put state + audit + idempotency record + transactional outbox in one PostgreSQL transaction.
- Use unique/check/foreign-key/exclusion constraints to enforce canonical invariants.
- Use `SELECT ... FOR UPDATE` or appropriate row locks for contested rows, with deterministic lock ordering.
- If `SERIALIZABLE` is used, implement bounded retries for serialization failures and prove the operation remains idempotent.
- Handle deadlocks explicitly; do not return success before commit.
- Advisory locks require documented key derivation, ownership, timeout and transaction/session lifecycle. They do not replace constraints.
- Test two or more parallel transactions for sales, stock, refunds, bookings, license redemption and sync deduplication.

### Query and availability controls

- Values are parameterized; dynamic identifiers/order/filter expressions are allowlisted.
- Apply statement, lock, idle transaction and connection timeouts appropriate to each workload.
- Bound pagination, exports, report ranges, JSON depth and expensive search/sort patterns.
- Detect N+1/large joins and unsafe ORM relation expansion that can become resource-exhaustion or data-leak paths.
- Monitor slow queries, failed auth, lock waits, deadlocks, RLS denials where observable, replication lag and backup health without logging secrets or raw sensitive payloads.

### Migrations, backup and recovery

- Review migration SQL, locks, data transforms, defaults, trigger/function changes and downgrade policy.
- Test migration on a production-shaped copy, including concurrent old/new application versions if rolling deploy is supported.
- Backups are encrypted, access-controlled and restore-tested. Record RPO/RTO and point-in-time recovery requirements.
- A successful backup command is not evidence of recoverability; restore into an isolated environment and verify constraints, sequences, roles and application behavior.

## 6. Redis security and correctness

### Deployment

- Never expose Redis directly to the public internet.
- Use protected/private networking, ACL users, command and key-pattern restrictions, and TLS when traffic crosses trust boundaries.
- Separate applications/environments/tenants by credentials and key namespace. Do not let a compromised worker flush or inspect unrelated keys.
- Restrict dangerous administrative commands and configuration access.

### Classify each use

- **Cache:** disposable; canonical correctness must survive cache loss/eviction/staleness.
- **Session/revocation/rate limit:** choose persistence/replication/TTL based on acceptable fail-open/fail-closed behavior.
- **Lock/coordination:** document failure model and fencing/version check at the canonical store.
- **Queue/Stream:** define delivery, acknowledgement, retry, pending recovery, ordering, poison handling and dead-letter policy.
- **Pub/Sub:** real-time hint only; at-most-once and non-durable.
- **Canonical data:** generally avoid unless durability, backup, consistency and recovery are explicitly designed and tested.

### Cache keys and invalidation

- Include environment, tenant, user/role scope where needed, entity ID, schema/serializer version and authorization-affecting version.
- Never cache an authorization decision longer than permitted revocation delay.
- Prevent cross-tenant collisions and user-specific response leakage.
- Use TTL plus explicit invalidation/versioning; invalidation loss must trigger authoritative re-read on version/cursor mismatch.
- Protect against cache stampede with bounded coalescing/jitter and no unbounded distributed lock waits.
- Cache negative/missing results only with careful short TTL and authorization scope.

### Streams and workers

- Use stable event IDs, consumer groups, explicit ACK after successful durable side effects, pending-entry recovery, bounded retries and dead-letter/quarantine.
- Consumers must be idempotent because at-least-once processing can duplicate work.
- Validate event schema and authorization context; never trust an internal channel merely because it is internal.
- Do not acknowledge before the database commit or external side effect is safely recorded.

## 7. Required backend adversarial tests

At minimum test:

1. no/malformed/expired/revoked token on every sensitive HTTP and socket path;
2. lower role, disabled user, cross-tenant user and revoked device;
3. own/other/missing/sequential object IDs and bulk/report/export routes;
4. protected/unknown/nested fields and direct price/role/tenant/owner/status mutation;
5. duplicate idempotency key with same and different payload;
6. two parallel stock/sale/refund/booking commands;
7. server crash before commit, after commit before response, and after response before broadcast;
8. Redis unavailable, flushed, evicted, stale or delayed; application must not corrupt canonical data;
9. Pub/Sub/event loss and Socket.IO disconnect; clients recover from cursor/snapshot;
10. RLS owner/bypass role and pooled tenant-context leakage;
11. migration while traffic exists, rollback and restore on clean environment;
12. worker/cron/admin script attempting the same forbidden operation as an HTTP client.

## 8. Evidence required to pass

- exact release commit/build and runtime versions;
- role/tenant/object/action matrix with database side-effect assertions;
- transaction/concurrency tests with deterministic final invariants;
- RLS/grants/role evidence and pool-context tests where applicable;
- Redis ACL/TLS/eviction/persistence configuration and failure tests;
- outbox/stream/worker retry evidence and dead-letter handling;
- sanitized logs/audit events for blocked and successful sensitive actions;
- restore rehearsal and rollback steps.
