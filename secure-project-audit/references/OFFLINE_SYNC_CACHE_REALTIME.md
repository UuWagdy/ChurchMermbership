# Offline Sync, Local Cache, Delta Commands, and Real-Time Reference

Use this reference when clients fetch server data into a local cache, work offline, send only modifications, and receive changes from other users/devices.

## 1. Non-negotiable model

Separate four concepts:

1. **Canonical state:** authoritative server/database result.
2. **Durable command delivery:** a mutation survives process/network failure until accepted or rejected.
3. **Real-time hint:** a low-latency notification that something changed.
4. **Backup:** a recovery snapshot, not a live merge protocol.

Socket.IO, WebSocket and Redis Pub/Sub are useful real-time hints but do not replace a durable change log and reconciliation endpoint.

## 2. Entity contract

Each synchronized entity should define:

- tenant/company scope and stable server ID;
- server version/revision and server-assigned update sequence;
- create/update/delete semantics and tombstone retention;
- authoritative fields versus client-editable fields;
- conflict policy per field/workflow;
- dependency ordering and referential rules;
- schema version and compatibility window;
- retention/compaction and minimum supported client cursor;
- whether the entity may be read/written offline.

Never trust client-supplied global sequence, server timestamp, tenant, role, owner, total or final status.

## 3. Local data model

Recommended logical tables/records:

### Cached entity

- `tenant_id`
- `entity_type`
- `entity_id`
- `server_version`
- `server_sequence`
- `deleted/tombstone`
- canonical payload or normalized fields
- local optimistic overlay, if used
- last confirmed time and schema version

### Durable outbox command

- cryptographically random immutable `command_id`
- tenant, authenticated actor and device scope
- entity type/ID and action
- expected version/base revision or explicit conflict basis
- allowed mutation payload only
- payload schema version
- local creation order/time for UX only
- state: `pending`, `in_flight`, `acked`, `rejected`, `needs_resolution`
- attempt count, next retry, sanitized error/rejection reason
- canonical response/server sequence once known

### Inbox/change cursor

- last contiguous applied server sequence per tenant/stream
- received event IDs for bounded deduplication
- gap/recovery state
- snapshot generation/schema version

Encrypt sensitive cache/outbox data at rest when required by the threat model. Clear or cryptographically isolate it on logout, account switch and device revocation without deleting another tenant/user’s data.

## 4. Client mutation lifecycle

1. Validate UX-level inputs, but do not claim server acceptance.
2. Write the command durably to the outbox before showing a recoverable optimistic result.
3. Send with current user/device authentication and immutable command ID.
4. On timeout/disconnect, keep it pending as **unknown outcome**.
5. Retry with the same command ID and same semantic payload.
6. Server deduplicates and returns the previously committed canonical result if already processed.
7. On acceptance, replace optimistic state with canonical state/version/sequence.
8. On rejection, retain reason and roll back/rebase only the affected optimistic overlay.
9. On conflict, use the declared policy; never silently overwrite financial/stock/approval data.

Connectivity failure must never delete an unacknowledged command.

## 5. Server command transaction

Inside one trusted server path:

1. authenticate current token/session and device;
2. authorize tenant, actor, entity, action and fields;
3. validate command schema and supported client version;
4. look up scoped idempotency key/command ID;
5. if already completed, return the stored canonical result;
6. load canonical state and lock/check expected version as required;
7. recompute business invariants from server data;
8. commit entity changes, audit record, command result and outbox/change record atomically in PostgreSQL;
9. only after commit, publish/dispatch the notification;
10. return canonical result and server cursor/sequence.

A response or ACK before commit is a correctness and security defect.

## 6. Idempotency requirements

- Scope keys to tenant + actor/device/client class + operation as appropriate.
- Store request fingerprint/hash and canonical response/status.
- Reusing the same key with a different semantic payload must be rejected and audited.
- Retention must exceed the maximum retry/offline/restore window for high-impact commands.
- Idempotency applies to external side effects too: payment, printer, email/SMS, file upload finalize, license issuance and webhooks.
- Do not derive keys from client time, incremental local counters alone or user-editable fields.

## 7. Ordering and conflict control

- Server owns a monotonic per-tenant/global stream cursor or equivalent durable ordering.
- Per-entity versions prevent stale blind overwrite.
- Use database constraints/locks/serializable retries for contested invariants.
- Do not assume arrival order equals creation order.
- Define last-write-wins only for explicitly safe fields; do not use device clock as the winner for financial, stock, entitlement, approval or identity data.
- Prefer merge/rebase/manual review for concurrent edits where both changes matter.
- Reject impossible backward versions and trigger reconciliation.

## 8. Broadcast and recovery

Broadcast payloads should contain a trusted event ID, tenant scope, entity ID/type, new version, server cursor and minimal change metadata. Full payloads may be sent, but clients must still validate tenant/schema/version and must not apply authority fields from an untrusted origin.

On every reconnect:

1. determine whether transport/session recovery succeeded;
2. compare local cursor with server minimum/current cursor;
3. fetch missing durable changes in pages;
4. if the gap is unavailable/compacted or schema incompatible, fetch an authenticated snapshot;
5. apply transactionally and advance the cursor only after success;
6. retry pending local commands through the same idempotent path;
7. verify critical invariants or checksums where practical.

Socket.IO connection-state recovery can fail; the application cursor is mandatory. Avoid skipping middleware on recovered sessions unless block/revocation changes are independently revalidated.

## 9. Redis and transport choices

- **Redis Pub/Sub:** at-most-once, no replay; use only as a low-latency signal.
- **Socket.IO default delivery:** application events are not a durable queue; client retries/ACKs still require idempotent server handling.
- **Redis Streams/queue:** can provide durable pending/consumer semantics, but consumers must be idempotent and poison messages need bounded retries/dead-letter handling.
- **PostgreSQL transactional outbox:** recommended when PostgreSQL is canonical; commit state and event record together, then dispatch asynchronously.
- **Cache invalidation:** version/cursor mismatch and authoritative reads are the correctness fallback.

## 10. Tombstones, snapshots and restore

- Deletion is a versioned tombstone, not an immediate disappearance, until all supported offline cursors can observe it.
- Snapshot manifests include tenant, schema/generation, cursor boundary, creation time, cryptographic integrity/authenticity and object counts/invariants.
- Snapshot apply is staged/transactional and never silently mixes tenants.
- Restoring an old local/cloud backup must not blindly replay old commands. First reconcile canonical state, deduplicate known commands and require manual handling for ambiguous high-impact operations.
- Backup must not transfer device trust, licensing receipt, refresh token or recovery authority by accident.

## 11. Cache security

- Cache keys include environment and tenant; include user/role/permission version for user-specific data.
- Do not treat cached role/license/user-enabled state as authoritative beyond a documented short bound.
- Encrypt sensitive local cache/outbox and protect its key in the OS secure store where required.
- Validate cache files/database schema and integrity; handle wrong key/corruption fail-closed for sensitive data.
- Clear temporary files, thumbnails, exports, logs and WAL/journals carrying sensitive data.
- Cache poisoning tests must attempt direct local edits, forged broadcast objects, cross-tenant key collision and stale privileged response reuse.

## 12. Mandatory failure/adversarial matrix

Run synthetic tests for:

| Case | Required safe result |
|---|---|
| Same command sent twice | one canonical effect; same result returned |
| Same command ID, changed payload | rejected and audited |
| Response lost after commit | retry returns committed result; no duplicate |
| Crash before commit | no effect; command remains retryable |
| Crash after commit before broadcast | clients recover from durable cursor |
| Broadcast lost/reordered/duplicated | gap/version logic reconciles correctly |
| Two devices update same entity | declared conflict policy, no silent corruption |
| Revoked role/device while offline | queued command rejected on reconnect |
| Cross-tenant entity ID | denied with no information leak or side effect |
| Old backup restored | no duplicate financial/stock/license actions |
| Tombstone missed offline | later reconciliation deletes/marks correctly |
| Redis unavailable/flushed/evicted | canonical DB remains correct; graceful degradation |
| Poison stream event | bounded retry then quarantine/dead-letter |
| Socket recovery fails | full cursor reconciliation succeeds |
| Local clock rollback/forward | no authority or ordering bypass |
| Server sequence gap/compaction | authenticated snapshot path succeeds |
| Schema mismatch | explicit upgrade/block; no partial corrupt apply |

Also test low disk space, database lock contention, corrupted local cache, wrong encryption key, token expiry mid-batch, pagination boundaries, server restart, rolling deploy and unsupported old client.

## 13. Observability and incident response

Record sanitized events for:

- command accepted/deduplicated/rejected/conflicted;
- actor/device/tenant and policy reason without raw secrets/PII;
- cursor gaps, repeated recovery, poison events and excessive retry;
- cross-tenant attempts and protected-field mutation;
- backlog age, oldest pending command, stream pending counts and dead-letter size;
- snapshot generation and restore events;
- device/user revocation and lease/license failures.

Define thresholds, owner and response. Monitoring that only shows transport connection status is not sync correctness monitoring.

## 14. Release criteria

Fail release if:

- any high-impact mutation lacks scoped idempotency and an atomic canonical transaction;
- transport broadcast is the only record of a change;
- clients trust role/tenant/price/total/sequence/timestamp/owner;
- no gap/snapshot recovery path exists;
- old restored backups can duplicate financial/stock/licensing actions;
- cross-tenant stream/room/cache/snapshot access is untested;
- pending commands are discarded on timeout/connectivity failure;
- the exact release build has not passed duplicate/reorder/drop/crash/concurrency tests.
