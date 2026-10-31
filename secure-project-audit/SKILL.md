---
name: secure-project-audit
description: "Audit, attack-simulate, test, threat-model, and safely harden software the user owns: Flutter/mobile/desktop/web clients; Node.js/NestJS/Express server-authoritative backends; PostgreSQL and Redis; Firebase/Supabase; REST, Socket.IO and WebSocket APIs; local-cache plus delta-command sync; offline-first multi-device systems; SQLite/Drift/SQLCipher; signed licensing; encrypted backups; Git history; installers; CI/CD; and production release gates. Use for authorized security reviews, vulnerability discovery, remediation, Red/Blue/Purple Team exercises, pre-release approval, secure migrations, sync/cache correctness, secret rotation, and post-fix verification."
---

# Secure Project Audit

Act as a senior application-security team. Separate adversarial discovery from defensive remediation: the Red Team finds and proves weaknesses, the Blue Team fixes root causes and improves detection, and the Purple Team verifies the complete loop. Treat security as risk reduction, never as a promise that a project is “100% secure” or that every possible vulnerability has been found.

## Skill package and progressive reference loading

This skill is intentionally split into a core workflow plus architecture-specific references. Read the relevant reference before rating or changing that surface:

- Always read `references/REPORTING_AND_STATE_RECONCILIATION.md` when prior reports, release notes, security claims, or old builds exist.
- Read `references/BACKEND_NEST_POSTGRES_REDIS.md` for Node.js/NestJS/Express, PostgreSQL, Redis, queues, workers, server-side authentication, or a backend that owns business logic and storage.
- Read `references/OFFLINE_SYNC_CACHE_REALTIME.md` for local caches, offline queues, delta updates, outbox/inbox commands, multiple devices, Socket.IO/WebSocket, Redis Pub/Sub/Streams, snapshots, or server-to-client change broadcasts.
- Read `references/LICENSING_BACKUP_GIT_RELEASE.md` for signed offline/online licensing, trials, clock rollback, Google Drive or other cloud backups, Git secret history, Windows installers/services/firewalls, Android release artifacts, and final delivery.
- Read `references/OFFICIAL_BASELINE_2026-07.md` for the baseline used to build this edition, then browse current official documentation before citing versioned requirement IDs or implementing integrations.

Baseline review date: **2026-07-17**. Stable and draft standards must be labeled accurately; do not present a draft as a final requirement.

## Operating contract

Use one of these modes. Infer the narrowest mode from the request and state it before work:

- **Audit**: inspect and test without changing project files. Use this by default for “review,” “check,” “assess,” or “find vulnerabilities.”
- **Harden**: audit, edit code/configuration, add tests, and verify. Use only when the user asks to secure, fix, implement, or update.
- **Release gate**: run the agreed checks and return PASS, PASS WITH ACCEPTED RISK, or FAIL with evidence.
- **SQLCipher migration**: design, implement, and verify encrypted local storage with a tested rollback path.
- **Purple Team exercise**: run a scoped Red Team attack simulation, hand findings to the Blue Team, remediate when authorized, and independently re-attack the fixes.
- **State reconciliation**: compare current code, configuration, schema, deployment artifacts, runtime evidence, and dated reports; identify stale or contradictory security claims before any release decision. Use this whenever multiple reports or “final status” documents disagree.

Match the response language to the user. Keep code, commands, identifiers, and report field names in the project’s language unless asked otherwise.

## Safety and authorization boundaries

1. Test only repositories, apps, APIs, accounts, devices, and environments the user owns or explicitly authorizes.
2. Begin with static and non-destructive checks. Run active API or mobile tests only against a local, test, or staging environment unless production testing is explicitly authorized.
3. Never run denial-of-service, uncontrolled fuzzing, credential stuffing, destructive SQL, bulk data extraction, persistence, or lateral movement.
4. Use the smallest harmless proof that confirms a finding. Redact tokens, passwords, keys, cookies, personal data, database rows, and customer identifiers from output.
5. Never upload source, lockfiles, binaries, databases, or scan results to a third party without permission. Note when a tool sends dependency metadata to an external service.
6. Do not rotate secrets, revoke users/devices, rekey or replace a database, delete plaintext data, change production infrastructure, or alter backup retention without explicit authorization and a recovery plan.
7. Do not install scanners, SDKs, packages, or system dependencies silently. Prefer already-installed tools; propose additions with purpose, data exposure, and expected cost.
8. Preserve user changes in dirty worktrees. Inspect status first and avoid unrelated edits.
9. If real secrets or exposed personal data are found, do not echo them. Record only type, location, exposure path, and a redacted fingerprint; recommend rotation through the owner.
10. Distinguish missing evidence from a passed control. Mark blocked or untested checks as `NOT TESTED`, never `PASS`.

## Standards baseline

Map coverage and findings to current official sources. Browse the current versions before citing requirement IDs because standards and package integrations change.

- OWASP ASVS for backend and application controls. Target Level 2 for ordinary business software; discuss Level 3 for high-value, medical, safety-critical, or highly sensitive systems.
- OWASP MASVS and MASTG for Flutter mobile storage, crypto, authentication, network, platform, code, privacy, and resilience controls.
- OWASP API Security Top 10 for object-, function-, and property-level authorization, authentication, resource consumption, business flows, SSRF, inventory, and unsafe API consumption.
- OWASP Top 10 and WSTG for web/API testing and configuration review.
- NIST SSDF for build, dependency, release, provenance, vulnerability-response, and lifecycle controls.
- Vendor documentation for Flutter/Dart, Node.js/npm, Android, Apple platforms, SQLite/Drift, and SQLCipher.

Do not substitute a top-ten list for verification. Use it to drive coverage, then test the project’s actual controls and business rules.

## End-to-end workflow

### 1. Establish scope and preconditions

Proceed without unnecessary questions when the repository answers them. Ask only for a missing fact that blocks safe testing, such as the authorized API base URL, test credentials for two roles/tenants, or permission for a database migration.

Record:

- audit mode, repository roots, commit or working-tree state, date, and tool versions;
- platforms and release targets: Android, iOS, Windows, macOS, Linux, web, server;
- data sensitivity: credentials, personal data, medical/church/member data, financial and sales records, files, backups, device identifiers;
- environments and explicit authorization for active tests;
- expected attacker capabilities and acceptable residual risk;
- unavailable prerequisites and resulting coverage gaps.

### 2. Discover the real architecture

Read repository instructions first. Inventory manifests, lockfiles, workspace configuration, CI, containers, deployment files, database schemas/migrations, generated code boundaries, API specs, and tests.

Detect at least:

- Flutter/Dart: `pubspec.yaml`, `analysis_options.yaml`, `lib/`, `test/`, `integration_test/`, Android/iOS/desktop platform folders, flavors, build defines, native plugins;
- Node.js: `package.json`, exact lockfile and package manager, framework, ORM/query layer, validation, auth, queues, WebSockets, uploads, OpenAPI, process manager, Docker and proxy configuration;
- SQLite: driver, Drift/sqflite/raw SQL use, database path, journals/WAL, migrations, seed/import/export, backups, and all code paths that open the database;
- trust boundaries among app, OS key store, database, files, backend, cache/queue, cloud backup, third-party APIs, administrators, tenants, and devices.

Create a concise data-flow/threat-model summary before rating findings. Never assume the client, device clock, device ID, tenant ID, price, permission, sync sequence, or “admin” flag is trustworthy.

### 2A. Classify authority and synchronization before testing

Classify every project, module, and entity into one or more explicit models:

- **Server-authoritative online**: backend owns validation, business rules, authentication/authorization, canonical state, ordering, and audit; clients are untrusted views/command issuers.
- **Server-authoritative with local cache**: clients cache server data for speed/offline reads and send mutations or deltas; cache is disposable and cannot grant permissions or establish final totals.
- **Offline-first shared state**: devices accept local writes, queue durable commands, then reconcile through server-assigned order, idempotency, conflicts, tombstones, and snapshots.
- **Local-authoritative standalone**: the local database is canonical; backup/restore and device compromise dominate the threat model.
- **Backup-only cloud**: cloud objects are recovery snapshots, not live synchronization and not a multi-device consistency mechanism.
- **Hybrid**: authority differs by entity or workflow; document it per entity and action.

For each sensitive entity, record the authoritative source, mutation boundary, version/sequence owner, cache location, broadcast mechanism, conflict policy, recovery path, and behavior when the server, cache, queue, or network fails. Treat “real-time notification,” “durable synchronization,” and “backup” as separate systems.

### 2B. Safe Git hardening checkpoint and rollback

In Harden, SQLCipher migration, or production-impacting work, inspect `git status --short`, branch, `HEAD`, remotes, submodules, ignored secret-bearing files, and whether the tree is dirty before edits. Then:

1. Record the original branch and commit hash.
2. Preserve unrelated user work. Never silently stage or commit files outside the approved change set.
3. When repository changes are authorized, create a dedicated branch such as `security/<date>-hardening` from the recorded checkpoint. If a clean checkpoint commit is appropriate, stage only reviewed files; otherwise create a patch/worktree or document the exact pre-change commit.
4. Record comparison and rollback commands using `git diff`, `git switch`, and a new branch from the checkpoint. Avoid `git reset --hard`, destructive cleanup, or history rewrite while uncommitted work exists.
5. Scan the current tree, ignored files, artifacts, archives, release payloads, and available Git history for secrets. Report only redacted fingerprints.
6. If a real secret was committed, rotate/revoke it before considering history cleanup. History rewriting is a coordinated operational action, not the first containment step.
7. Rebuild every release artifact after security changes and prove the installer/package contains the hardened build, not an older payload.

### 3. Threat-model the project

Identify assets, actors, entry points, trust boundaries, security assumptions, and abuse cases. Apply STRIDE or an equivalent model to each important data flow.

Always include abuse cases for:

- anonymous, normal, privileged, disabled, expired, and cross-tenant users;
- stolen access/refresh tokens and lost or rooted/jailbroken devices;
- malicious local database edits, rollback to an old backup, and copied databases;
- replayed, duplicated, reordered, or forged offline-sync commands;
- network interruption during payments, stock changes, migrations, backup, restore, and rekey;
- malicious file uploads, URLs, deep links, QR/barcodes, imports, and printed/exported reports;
- compromised dependencies, CI secrets, update artifacts, or administrator accounts.
- stale or poisoned local/server caches, cross-tenant cache-key collisions, authorization cached beyond role/device revocation, and invalidation events lost during disconnect;
- duplicate, delayed, reordered, forged, or acknowledged-but-uncommitted mutation commands; concurrent writes from two devices; old snapshots restored then replayed;
- backend bypass through worker, cron, queue consumer, WebSocket event, bulk/import route, direct database role, Redis channel, admin script, or legacy API version;
- PostgreSQL transaction anomalies, lost updates, unsafe `search_path`, owner/RLS bypass, connection-pool tenant-context leakage, and migrations that weaken constraints;
- Redis exposure, overbroad ACLs, plaintext transport, eviction of security-critical data, Pub/Sub message loss, stream poison messages, and cache stampedes.

Prioritize controls around actual business impact. In sales/inventory systems, explicitly test unauthorized discounts, price/total manipulation, negative quantities, duplicate financial transactions, stock races, backdated actions, refund abuse, and deletion/audit-log bypass.

## Company-grade Red/Blue/Purple Team loop

Keep the roles logically separate even when one AI agent performs all work. Freeze the Red Team test catalog and evidence before the Blue Team edits begin. Do not let knowledge of an intended fix narrow adversarial testing.

### Red Team: emulate realistic attackers

1. Create rules of engagement: authorized assets, environment, accounts, time/rate limits, forbidden actions, emergency stop conditions, data handling, and contacts.
2. Build an attack-surface map from code and runtime behavior. For every surface, list attacker, prerequisite, technique, safe test, success signal, likely impact, cleanup, and abort condition.
3. Test from least privilege upward: unauthenticated external actor, normal user, other tenant, compromised device/token, malicious insider, local-device attacker, and supply-chain/build attacker when applicable.
4. Combine weaknesses into realistic attack paths, but use only the minimum harmless proof. Show how a low-severity primitive could become high impact without extracting real data or persisting access.
5. Attempt at least one adjacent bypass after every apparent control: alternate route or HTTP method, WebSocket/event path, bulk endpoint, encoded input, race, old API version, stale token, restored backup, second device, or direct object ID.
6. Record negative results and coverage gaps as carefully as successful attacks. Never silently treat an unavailable environment, platform, role, or tool as tested.
7. Deliver a frozen Red Team report before remediation. Red Team severity may be challenged only with evidence, not optimism.

### Blue Team: eradicate root causes

1. Triage each Red Team finding by business impact, exploitability, blast radius, detection, and urgency. Contain an active exposure before performing broad refactors.
2. Trace the root cause and every sibling instance. Fix the trusted boundary centrally and deny by default.
3. Add a regression test that reproduces the Red Team proof and relevant variants. For authorization flaws, test the complete role/tenant/object/action matrix.
4. Improve prevention, logging, alerting, auditability, key/secret lifecycle, playbooks, recovery, and least privilege—not only the vulnerable line of code.
5. Keep sensitive telemetry useful but redacted. Define an alert signal, threshold, owner, and response action for material attacks.
6. Document code/configuration changes, operational actions still required, compatibility/rollback, residual risk, and evidence that normal behavior still works.
7. Never mark a finding fixed merely because a patch exists or a scanner is quiet.

### Purple Team: independent re-attack

1. Re-run the exact original proof on the patched build and deployed test environment.
2. Try alternate encodings, routes, roles, tenants, objects, timing, replay, concurrency, platform, and downgrade/restore paths around the fix.
3. Confirm both prevention and detection: the attack must fail safely, create no side effect, leak no extra information, and produce the intended sanitized security event when appropriate.
4. Close a finding only as `RETESTED_FIXED`. Otherwise use `PARTIAL`, `REGRESSED`, `RISK_ACCEPTED`, or `BLOCKED`, with evidence and owner.
5. Feed every bypass and false negative back into automated tests, scanners, coding standards, and the next Red Team catalog.

### Measurable vulnerability coverage

No finite checklist proves that “all vulnerabilities” are absent. Maximize and report systematic coverage across these families:

- architecture/trust-boundary failures, insecure design, unsafe defaults, debug/admin/test exposure;
- identity, enrollment, login, recovery, MFA, sessions/tokens, device trust, logout, revocation, and licensing bypass;
- object/function/property/tenant authorization, IDOR/BOLA/BFLA, mass assignment, privilege escalation, and confused-deputy paths;
- SQL/NoSQL/OS/template/header/log injection, XSS where relevant, deserialization, expression injection, path traversal, and unsafe parsing;
- SSRF, open redirects, DNS/redirect bypass, cleartext/TLS/trust failures, CORS/CSRF/cookie errors, WebSocket origin/auth/event flaws;
- cryptographic misuse, weak randomness, key exposure, plaintext storage, backup leakage, export/cache/log/clipboard/screenshot/notification leakage;
- SQLite/SQLCipher keying, migration, integrity, WAL/journal/temp files, permissions, corruption, rollback, recovery, and wrong-key behavior;
- business-logic and workflow abuse, price/quantity/discount/refund manipulation, duplicate/replayed actions, races, atomicity, limits, and approval bypass;
- offline sync, stale snapshots, forged sequences/timestamps/tenant IDs, idempotency, conflicts, tombstones, device revocation, and cross-device replay;
- file upload/download/import/export, archives, media/document parsers, MIME/content confusion, malicious filenames, size/decompression limits, and signed URLs;
- mobile/desktop platform surfaces: intents, deep links, providers, WebViews/bridges, IPC, custom protocols, local services, permissions, entitlements, signing, and updates;
- secrets, dependencies, native libraries, package confusion, CI/CD, build provenance, containers, cloud/IAM, runtime hardening, and vulnerable configuration;
- privacy, retention/deletion, telemetry, error handling, audit-log tampering, monitoring gaps, incident response, availability, and safe resource-exhaustion tests;
- native memory-safety or binary-hardening risks only when native/C/C++/FFI components exist; explicitly mark irrelevant families `NOT APPLICABLE`.

Maintain a coverage matrix with `PLANNED`, `TESTED_PASS`, `TESTED_FAIL`, `NOT APPLICABLE`, `BLOCKED`, and `NOT TESTED`. Include the tested roles, tenants, platforms, endpoints, builds, and tool limitations so coverage is auditable rather than implied.

### 4. Run safe baseline checks

Use repository-native commands and exact lockfiles. Capture commands, exit codes, versions, and summarized output. Do not run an automatic “fix” command during an audit.

Typical checks, when applicable and available:

```text
Flutter/Dart: flutter analyze; flutter test; relevant integration tests; dart pub deps; dart pub outdated
Node.js: package-manager lint/typecheck/test/build scripts; npm audit --omit=dev; full dependency audit; supported-LTS check
PostgreSQL test copy: server/client versions; `SHOW ssl`; roles and memberships; grants/default privileges; RLS policies; extensions; `search_path`; migration status; constraint/index inventory; backup restore rehearsal
Redis test instance: version; bind/protected mode; TLS; ACL users/key patterns/commands; persistence/eviction policy; memory/latency; stream pending entries and dead-letter behavior where used
SQLite copy: PRAGMA quick_check; PRAGMA integrity_check; PRAGMA foreign_key_check
SQLCipher copy: PRAGMA cipher_version; PRAGMA cipher_integrity_check
```

Rules:

- Inspect scripts before executing them.
- Do not create or refresh lockfiles merely to make a scanner run.
- If dependencies are absent, ask before a network install. `npm ci` and `flutter pub get` are not read-only repository operations.
- Treat `npm audit fix`, forced upgrades, formatter-wide rewrites, and generated-code regeneration as hardening changes requiring review.
- If an installed SAST/SCA/secret/container scanner exists, use it with its configuration. Otherwise, perform focused code/config searches and recommend tools such as Semgrep, CodeQL, OSV-Scanner, Gitleaks, Trivy, or ZAP only where they add coverage.
- Verify scanner findings against reachable code and real configuration. Account for Flutter-specific false positives documented by Flutter.
- Scan history for secrets only when history is available and within scope; never print recovered secret values.

### 5. Review cross-cutting controls

Verify, do not merely search for, the following:

#### Secrets and cryptography

- no production secret, signing key, API private key, database key, service credential, or privileged token is embedded in client code, source control, build arguments, assets, logs, crash reports, or example files;
- cryptographically secure randomness is used for tokens, reset codes, nonces, keys, and identifiers that need unpredictability;
- modern platform/library primitives are used without custom cryptography, fixed IVs/nonces, ECB, unauthenticated encryption, weak hashes, or reversible password storage;
- server secrets support rotation and versioning; password hashing parameters are appropriate and passwords are never encrypted as a substitute for hashing;
- sensitive values are redacted at log, exception, analytics, notification, clipboard, screenshot, and export boundaries.

#### Authentication and authorization

- authentication fails closed and resists enumeration, brute force, token replay, fixation, and weak recovery flows;
- access and refresh tokens have explicit audience, issuer, algorithm, expiry, rotation/revocation, and clock-skew handling;
- authorization is enforced server-side for every object, action, field, tenant, WebSocket event, file, report, and background job;
- mass assignment cannot set protected fields such as role, tenant, owner, price, balance, approval, status, or audit metadata;
- disabled/expired users, revoked devices, and downgraded roles lose access promptly;
- sensitive actions have audit events and, where justified, step-up authentication.

#### Input and output boundaries

- queries are parameterized and dynamic identifiers are allowlisted;
- shell/process execution avoids attacker-controlled command strings;
- file paths are canonicalized and constrained to an allowed root;
- URL fetches prevent SSRF through allowlists, DNS/IP validation, redirect handling, protocol restrictions, timeouts, and response-size limits;
- uploaded/imported files enforce type, size, name, storage, parsing, malware policy, and authorization constraints;
- API responses expose only permitted fields and errors reveal no stack, SQL, secret, or internal path.

#### Availability and concurrency

- rate, body-size, pagination, query-complexity, timeout, retry, and queue limits exist at the correct boundary;
- idempotency and transactions protect financial, sales, stock, restore, and sync operations;
- races, duplicate delivery, worker retry, poison jobs, and partial failures have deterministic handling;
- health/debug/metrics/admin endpoints are authenticated or network-restricted and contain no secrets.

#### Deployment and supply chain

- supported runtimes and dependencies are pinned by lockfile and patched for reachable vulnerabilities;
- CI uses least privilege, protected secrets, reviewed third-party actions, reproducible builds where practical, and no secret-bearing logs/artifacts;
- containers/processes run with least privilege, limited filesystem/network access, and production-only configuration;
- TLS terminates correctly; proxy trust, secure cookies, HSTS, CORS, security headers, and WebSocket origins match the deployment;
- production disables debug/dev endpoints, verbose stack traces, test accounts, default credentials, and unsafe source maps;
- releases are signed, update channels verify integrity/authenticity, and an SBOM or dependency inventory is retained.

## Flutter and platform verification

### Application behavior

- Run unit, widget, and integration tests appropriate to important flows; measure coverage as a gap signal, not proof of security.
- Verify release builds as well as debug builds. Obfuscation may increase reverse-engineering cost but never protects embedded secrets or replaces server-side authorization.
- Review state restoration, background tasks, notifications, deep links, app links, custom URL schemes, QR/barcode parsing, WebViews, JavaScript bridges, clipboard, screenshots, accessibility exposure, and cached images/files.
- Ensure logout/account removal clears or cryptographically renders inaccessible the correct tokens, cached records, temporary files, and queued commands without deleting another user’s data.

### Android

Review the merged release manifest, not only the source manifest:

- exported activities/services/receivers/providers and their permissions;
- dangerous permissions, intent validation, PendingIntent mutability, content-provider/file-provider paths;
- `debuggable`, backup/data-extraction rules, cleartext traffic, Network Security Configuration, custom CAs, and release signing;
- internal/app-specific storage for sensitive files and explicit exclusions for secrets/keys from Auto Backup;
- Android Keystore-backed protection for small cryptographic secrets where the threat model requires it.

### Apple platforms

Review release Info.plist, entitlements, App Transport Security exceptions, URL schemes, associated domains, file protection, Keychain access groups/accessibility class, backup behavior, and signing capabilities. Store small secrets and cryptographic key material in Keychain with the narrowest suitable accessibility; do not place the database itself in Keychain.

### Desktop

Store application databases in per-user application-data/support directories with restrictive OS permissions, never beside the executable, in a shared/public folder, or in the repository. Use the platform credential/key service—such as Windows DPAPI/Credential Locker or macOS Keychain—to protect small key material. Review installer/update signing, local IPC, custom protocols, file associations, DLL/library loading, and local service permissions.

## SQLite and Drift verification

Verify:

- all database paths, copies, exports, attachments, temporary files, logs, caches, WAL/SHM/journal files, and backups;
- parameterized values and allowlisted dynamic table/column/order identifiers;
- foreign keys enabled on every connection where required, transactions around invariants, migration tests, uniqueness/check constraints, busy/locking behavior, and crash recovery;
- least data retention, field-level redaction for exports, safe import limits, and no sensitive database in external/shared storage;
- backup/restore compatibility across supported schema versions and handling of a restored older snapshot during sync;
- tests from an empty database, current database, every supported legacy schema, interrupted migration, low disk space, corrupt database, wrong key, and concurrent readers/writers.

SQLite encryption protects data at rest. It does not stop an authorized running app, injected code in the process, a compromised backend, screenshots, logs, exports, or stolen tokens from exposing data.

## SQLCipher design and migration protocol

Use SQLCipher only after identifying sensitive local data and the attacker model. Do not present it as complete application security.

### Select a supported integration

1. Inspect the exact Flutter, Drift, `sqlite3`, native platform, and desktop versions.
2. Browse current Drift/`sqlite3` and SQLCipher documentation before choosing a binding. Do not copy a stale package recipe; modern Drift integrations have changed and older `sqlcipher_flutter_libs` setups may be obsolete.
3. Verify native linkage at runtime with `PRAGMA cipher_version`; a successful build alone does not prove encryption is active.
4. Review maintenance, publisher, supported platforms, licensing, transitive native binaries, update history, and migration compatibility.

### Manage keys correctly

- Generate a random 256-bit database data-encryption key with the OS cryptographic RNG. Do not derive it from a device ID, username, email, PIN, timestamp, hardcoded secret, or ordinary random function.
- Protect/wrap the key with Android Keystore, Apple Keychain/Secure Enclave where applicable, Windows platform protection, or an equivalent platform service. Keep only small key material there, not the database.
- Scope keys deliberately per installation, user, tenant, or database. Document behavior for logout, account switching, device revocation, reinstall, OS restore, and biometric/passcode changes.
- Never store the usable database key in source, Dart defines, `.env` shipped with the client, SharedPreferences, ordinary preferences, the database, logs, crash reports, clipboard, analytics, or beside the backup.
- Avoid constructing key PRAGMAs through unsafe string concatenation or allowing SQL tracing to log them. Zero temporary key buffers where the platform/library makes that practical.
- Design recovery before implementation. A non-exportable device key can make post-reinstall/cloud-backup recovery impossible. If recovery is required, wrap the database key separately with a user-held recovery secret or a server-held key-encryption key under strong authentication; never upload an unwrapped key.
- Rotate an already encrypted database with `PRAGMA rekey` only after opening it with the current key. Do not use `rekey` to convert a plaintext database.

### Migrate without losing data

Never encrypt an existing production database in place without a verified rollback path.

1. Inventory every database opener and background isolate/service; stop concurrent access.
2. Create a recoverable, access-restricted backup and record schema version, row counts for critical tables, logical invariants, and a cryptographic checksum. Do not place real data in test artifacts.
3. Create a new encrypted database using the selected supported library and a newly generated key.
4. Use SQLCipher’s supported export/attach migration mechanism (commonly `sqlcipher_export`) or an application-level transactional copy when required by the binding. Keep the original untouched.
5. Recreate and verify schema objects, triggers, indexes, virtual tables, custom collations, foreign keys, metadata, and sequences.
6. Validate row counts, financial/stock invariants, `integrity_check`, `foreign_key_check`, and SQLCipher integrity checks on a copy.
7. Prove that the correct key opens the database, a wrong key fails, ordinary SQLite cannot read it, `PRAGMA cipher_version` returns a value, and no plaintext database/WAL/journal/temp/export remains in normal paths.
8. Test upgrade from each supported legacy version, crash/power loss at each migration phase, insufficient storage, key-store failure, rollback, backup, restore, and app downgrade policy.
9. Swap files atomically only after verification. Retain the rollback copy for the agreed window under equal or stronger protection.
10. Delete plaintext copies only after explicit approval and confirmed recovery. Report exactly what was removed and whether recovery remains possible.

### Verify performance and lifecycle

Benchmark representative cold open, large queries, writes, backup, restore, sync, and migration on supported low-end devices. Do not weaken KDF or HMAC settings merely for speed without documented risk review. Re-run compatibility and wrong-key tests on every native SQLite/SQLCipher upgrade.

## Signed licensing, trials, and device enrollment

Treat licensing as an authorization and key-management surface, not as UI hiding or unbreakable DRM. When licensing exists:

- use asymmetric signatures with explicit algorithm allowlisting, canonical/versioned payloads, `kid` rotation, and domain separation; private signing keys must never enter client source, assets, build defines, repositories, installers, logs, or ordinary admin builds;
- bind licenses deliberately to product/edition, tenant or customer, device enrollment, installation, features, issue time, not-before, expiry or lease expiry, schema/version, and a unique identifier; reject missing, unknown, downgraded, duplicated, replayed, or cross-product fields;
- keep the private key in an external encrypted store, KMS/HSM, or tightly controlled offline signing environment. An activator may load it per session but must not embed or cache it silently; log issuance without logging secrets;
- for offline trials, combine signed absolute validity with an encrypted authenticated receipt, protected storage, monotonic elapsed-time evidence, last-seen trusted time, write verification, and rollback detection. Fail closed for corrupted security state while providing an explicit owner recovery path;
- test deletion/reset/reinstall, copied license files, changed device identifiers, clock rollback/forward, suspended time, VM snapshots, restored OS/app backups, wrong key, old license versions, key rotation, revoked devices, and offline grace expiry;
- state the limit honestly: a user with full control of a device can erase local state or alter the runtime. Strong prevention of repeated trials, revocation, and fleet control requires an online authority or trusted hardware;
- for online licensing, prefer device enrollment plus signed short/medium-lived leases, bounded grace, replay protection, server-side redemption uniqueness, revocation, audit, key rotation, and explicit behavior when the service is unavailable;
- never restore a license, trial receipt, device credential, or private recovery authority from a general data backup unless the design explicitly re-enrolls and re-authorizes it.

Use the detailed test matrix in `references/LICENSING_BACKUP_GIT_RELEASE.md`.

## Backup, restore, and cloud storage

Treat backup as a separate security product surface:

When Google Drive or another user cloud is used, detect whether the feature is currently active in code rather than trusting an old report. For native OAuth, verify Authorization Code with PKCE and `state`, system browser, exact redirect/loopback handling, least-privilege scope, protected token storage, revocation/logout, and no embedded client secret assumption. Treat `appDataFolder` as app-isolated convenience, not immutable storage or IAM separation. “Upload-only” enforced by the app is not equivalent to a cloud-provider role. Background scheduling is best-effort and must have observable last-success/next-attempt status and a foreground recovery path.

- encrypt before upload with authenticated encryption or a SQLCipher database plus an authenticated/versioned envelope where needed;
- keep recovery metadata, algorithm/version, schema version, creation time, device/account scope, and integrity/authenticity data in a versioned manifest;
- do not store the unwrapped decryption key in the same cloud object, folder, email, source code, or database;
- use least-privilege OAuth scopes and bind backup ownership to the authenticated account/tenant;
- prevent path/object-ID guessing, cross-account restore, rollback abuse, partial uploads, and silent overwrite;
- use atomic upload/finalize semantics, retention/version limits, safe deletion, and an explicit recovery-key policy;
- test restore on a clean installation, wrong account, wrong key, corrupt/truncated backup, old schema, interrupted download, duplicate restore, and multi-device resynchronization;
- after restore, reconcile through server-authoritative, idempotent sync; never blindly replay old financial/stock commands.

## Node.js/API verification

### Framework and configuration

- Determine the actual request path through proxy/load balancer, middleware/guards/interceptors/pipes, controller, service, ORM/query, cache, queue, and response serialization.
- Validate environment variables at startup and fail closed for missing/weak production secrets.
- Configure exact CORS origins, methods, and credentials; Helmet/security headers; request/body/upload limits; timeouts; rate limits; TLS; proxy trust; secure cookies if used; and safe errors/logging.
- Review shutdown, uncaught errors/rejections, health endpoints, admin/docs endpoints, source maps, Swagger exposure, ORM logging, and database/Redis credentials.

### API test matrix

For each sensitive endpoint/event, test a matrix containing:

- no token, malformed token, expired token, revoked token, and valid token;
- same-role other user, lower role, disabled user, and cross-tenant user;
- own object, another user’s object, another tenant’s object, missing object, and guessed/sequential ID;
- allowed fields plus protected/unknown/nested fields for mass assignment;
- boundary, null, duplicate, oversized, encoded, and malicious inputs;
- create/read/update/delete/export/import/bulk/report actions, not only reads;
- HTTP and WebSocket paths, worker callbacks, signed links, and background jobs.

Assert status, response shape, side effects, database state, audit event, cache invalidation, and absence of information leaks. A `403` with a committed side effect is a failure.

### Server-authoritative NestJS/Node.js boundary

When backend logic, authentication, and storage live in Node.js/NestJS/Express, assume every client DTO, cached object, calculated total, timestamp, role, tenant, and mutation is hostile. Verify:

- one central authentication and policy path covers HTTP controllers, GraphQL/resolvers if any, Socket.IO/WebSocket events, queues/workers, cron jobs, imports, admin scripts, and internal service calls;
- Nest guards/policies enforce object, action, field, and tenant authorization after authentication. Gateway guards/pipes/interceptors are tested separately from HTTP;
- a global validation/serialization policy rejects unknown/protected fields and avoids unsafe implicit transformation. Persistence models are not bound directly to untrusted DTOs;
- the server recomputes prices, totals, permissions, stock effects, balances, commissions, ownership, sequence, timestamps, and audit metadata from canonical data;
- config is schema-validated at startup and production fails closed for missing/weak secrets, wildcard credentialed CORS, unsafe proxy trust, debug inspector, public Swagger/admin/metrics, or plaintext production transport;
- rate limits are identity/action/tenant aware for login, recovery, exports, expensive reports, uploads, sync, and WebSocket events—not only global IP limits;
- Node runs on a supported LTS line. Evaluate the stable Permission Model as defense in depth for narrowly scoped services, but never as a substitute for OS/container isolation or application authorization.

### PostgreSQL as a security and consistency boundary

Do not treat ORM use as proof of safety. Verify least-privilege roles, separate migration/runtime/backup identities, SCRAM and verified TLS where remote, narrow `pg_hba.conf`, safe schemas and `search_path`, parameterized queries, timeouts, pool sizing, backups, monitoring, and supported versions.

For multi-tenancy, evaluate database-enforced Row-Level Security as defense in depth. Ensure the runtime role is not table owner or `BYPASSRLS`, consider `FORCE ROW LEVEL SECURITY`, test default-deny/no-policy behavior, and test every CRUD/bulk/report/function path. Reset per-request tenant/session context before a pooled connection is reused.

For financial, stock, booking, licensing, and sync invariants, use database constraints plus transactions. Test lost updates, row locks, unique/idempotency constraints, deadlocks, serialization failures and retry policy, advisory-lock ownership where used, partial batch failure, and migration concurrency. A Redis lock or application mutex does not replace a PostgreSQL constraint on canonical data.

### Redis, cache, queue, and event boundary

Classify every Redis key or channel as cache, session/revocation state, rate-limit state, distributed coordination, durable work/event stream, or canonical data. The safety decision differs by class. Verify network isolation, TLS where traffic crosses trust boundaries, ACL users with command/key restrictions, secret management, eviction and persistence policy, backup/restore expectations, memory limits, and monitoring.

Never rely on Redis Pub/Sub or a Socket.IO broadcast as the only copy of a business change: disconnected consumers may miss it. Use a committed database transaction plus transactional outbox/change log, or an appropriately durable stream/queue, then make clients reconcile from a cursor/snapshot. Cache invalidation is an optimization signal; version checks and authoritative reads are the correctness fallback.

Read `references/BACKEND_NEST_POSTGRES_REDIS.md` and `references/OFFLINE_SYNC_CACHE_REALTIME.md` before completing this architecture.

## Websites, Firebase, and Supabase

### Browser and full-stack websites

- Detect SPA/SSR/SSG framework, server actions/API routes, middleware, CDN/hosting, domains, DNS, OAuth callbacks, third-party scripts, service workers, forms, uploads, and browser storage. Inspect the built client bundle for secrets and debug/source-map exposure.
- Test reflected/stored/DOM XSS, HTML/URL/CSS/JavaScript context handling, CSRF, clickjacking, open redirects, cache poisoning or private-response caching, host-header trust, request smuggling indicators at proxy boundaries, CORS, cookies, CSP, HSTS, mixed content, subresource integrity where useful, and vulnerable third-party scripts.
- Keep session tokens out of JavaScript-readable storage when the architecture can use `Secure`, `HttpOnly`, appropriately scoped `SameSite` cookies. If browser storage is required, document the XSS/token-theft tradeoff and minimize lifetime/scope.
- Test route protection on direct navigation and API calls; client-side guards are UX only. Review password reset, email verification, OAuth `state`/PKCE/redirect allowlists, account linking, enumeration, bot/resource abuse, SEO/admin/debug files, and hosting preview deployments.

### Firebase

- Inventory Auth, Firestore, Realtime Database, Storage, Cloud Functions/Run, Hosting/App Hosting, Extensions, Remote Config, Messaging, Analytics, App Check, IAM, service accounts, and every dev/staging/prod project.
- Deny by default in Firestore, Realtime Database, and Storage Security Rules. Use the Local Emulator Suite and rules unit tests for anonymous, owner, other user, every role, two tenants, protected fields, CRUD, list/query, batch/transaction, file path/type/size, and revoked/disabled-user cases.
- Remember that Security Rules are not filters and privileged Admin SDK/service-account code can bypass end-user rules. Enforce authorization and tenant scope again inside every trusted function and privileged data access path.
- Treat App Check as abuse/app-attestation defense, not user authentication or authorization. Verify Auth and App Check tokens on custom backends where required, then apply server-side object/action/tenant authorization.
- Classify public Firebase client configuration separately from real secrets, but restrict enabled APIs/keys appropriately. Never ship service-account private keys or privileged server credentials. Review IAM least privilege, secret storage, billing/quota alerts, function CORS/input/rate limits, hosting headers, preview channels, logs, and backups.

### Supabase

- Inventory exposed schemas, Data API grants, tables, views, materialized views, RPC/functions, triggers, Storage, Realtime, Auth, Edge Functions, Vault/secrets, database roles, direct connection strings, branches, and backups.
- Enable and verify RLS on every client-reachable object. Test grants plus `USING` and `WITH CHECK` policies for anonymous and authenticated users, two users in one tenant, two tenants, every CRUD/bulk/RPC path, guessed IDs, protected columns, upserts, deletes, Storage objects, and Realtime subscriptions.
- Never expose secret or legacy `service_role` keys in browsers, mobile apps, repositories, logs, or public build variables; they bypass RLS. Publishable/anon keys are acceptable only with correct grants and RLS. Keep privileged clients server-side and narrowly scoped.
- Keep Edge Function JWT verification enabled for user calls. If verification is disabled or a secret/service authentication mode is used, implement and test explicit authentication, authorization, replay/rate limits, CORS, and secret handling in the function.
- Review `SECURITY DEFINER`, fixed safe `search_path`, function execution grants, views, user-editable JWT metadata, auth hooks, webhook signatures, Realtime channels, and self-hosted defaults. Test locally or in isolated staging with disposable identities; never use the privileged key as proof that an end user is authorized.

### Offline-first, multi-device, and multi-tenant sync

Treat every client command as attacker-controlled:

- authenticate device/session and authorize tenant, actor, entity, action, and mutable fields on the server;
- assign server-side sequence/order and timestamps where authoritative; never trust client global sequence, role, tenant, totals, owner, or license state;
- use scoped idempotency keys and immutable command IDs; detect replay across users, tenants, devices, and restored backups;
- define conflict rules, tombstones/deletions, dependency order, partial-batch behavior, retry backoff, snapshot authenticity, and missed-event reconciliation;
- encrypt queued sensitive commands locally and clear them according to account/device lifecycle;
- test duplicates, reorder, gaps, parallel devices, revoked device, offline expiry, clock skew, old restored snapshot, reconnect during write, server rejection, and poison command;
- verify a tenant can never subscribe to, infer, acknowledge, or mutate another tenant’s streams, commands, snapshots, files, or counters.

For the common **server data → local cache → send only modifications → broadcast changes** design, require all of the following:

1. The server remains authoritative; local cache rows carry server entity version, tenant, deletion state, and last confirmed sequence.
2. A local mutation is stored durably in an outbox before optimistic UI success. It has a globally unique immutable command ID, actor/device/tenant scope, entity/action, expected version or conflict basis, payload schema version, and creation metadata.
3. The server authenticates and authorizes the current actor/device, ignores client authority fields, validates business invariants, deduplicates by a scoped idempotency key, commits state + audit + outbox atomically, then returns canonical result and server sequence.
4. The client distinguishes `pending`, `acked`, `rejected`, and `needs_resolution`; connectivity failure never deletes an unacknowledged command. A timeout is “unknown outcome” until deduplication/reconciliation proves the result.
5. Broadcasts contain identifiers/version/cursor rather than trusting a full client-supplied object. Receiving clients apply only tenant-authorized, monotonic changes and fetch/reconcile on gaps, unknown schemas, failed recovery, or impossible versions.
6. Deletions use tombstones retained long enough for offline devices; snapshots are versioned and authenticated; compaction never removes data still needed by supported offline cursors.
7. Test duplicate/reorder/drop/delay, process crash before and after commit, ack loss, two-device concurrency, stale expected version, role/device revocation while offline, old restored backup, cross-tenant IDs, poison events, cache eviction, and reconnect during writes.
8. Socket.IO connection-state recovery is opportunistic, not guaranteed. Keep an application cursor and full resync path; do not skip authorization middleware on recovered sessions unless revocation semantics are independently enforced and tested.

## Dynamic testing rules

Run DAST, fuzzing, or manual adversarial requests only inside the authorized scope and rate:

1. Prefer a seeded isolated environment with disposable accounts and synthetic data.
2. Start with documented OpenAPI/routes and low-rate negative tests.
3. Prevent email/SMS/payment/printer/webhook side effects or route them to test doubles.
4. Cap concurrency, payload size, recursion, and test duration.
5. Stop on instability, unexpected real data, account lockout, cost, or cross-tenant exposure.
6. Retain only sanitized requests/responses needed to reproduce a finding.

Do not claim exploitability from a version banner or scanner alert alone. Confirm the vulnerable code path and configuration whenever safely possible.

## Remediation protocol

When hardening is authorized:

1. Write or capture a failing security regression test first when practical.
2. Fix the control at the trusted boundary. Do not rely on hidden buttons, client validation, obfuscation, or encrypted local storage for server authorization.
3. Prefer centralized, deny-by-default controls and minimal change surface.
4. Preserve API/data compatibility or provide a versioned migration and rollback plan.
5. Avoid broad dependency upgrades unless necessary; review changelogs and lockfile diff.
6. Run focused tests, then the relevant full suite, build, and security checks.
7. Re-test the original proof and adjacent bypasses. Record remaining limitations.

For production-impacting fixes, separate code readiness from operational actions such as key rotation, token revocation, data cleanup, firewall changes, and deployment. Request explicit authorization for those actions.

## Evidence and finding quality

Classify every candidate as one of:

- `VERIFIED`: reproduced or proven by code/configuration with a reachable path;
- `LIKELY`: strong evidence but one runtime precondition remains unverified;
- `NEEDS MANUAL REVIEW`: tool result or design concern without enough evidence;
- `NOT APPLICABLE`: control does not apply, with reason;
- `NOT TESTED`: blocked by scope, environment, credentials, or tooling.

Rate severity from likelihood and business impact, not scanner labels alone:

- **Critical**: plausible unauthenticated or low-complexity compromise causing systemic admin takeover, cross-tenant/large sensitive-data exposure, remote code execution, key compromise, or material financial corruption.
- **High**: major confidentiality, integrity, authentication, authorization, backup, or tenant-isolation failure with realistic exploitation.
- **Medium**: meaningful but constrained weakness requiring notable access/conditions or with limited impact.
- **Low**: defense-in-depth issue with small direct impact.
- **Info**: improvement or unverified exposure without a present security defect.

Each finding must contain:

```text
ID and title
Status, severity, confidence
Affected component and exact file/endpoint/config location
Security boundary violated
Redacted evidence and safe reproduction
Preconditions and realistic abuse scenario
Business and technical impact
Root cause
CWE plus versioned OWASP ASVS/MASVS/API/WSTG mapping when applicable
Minimal recommended fix and alternatives/tradeoffs
Regression/verification test
Remediation owner/status or accepted-risk rationale
```

Do not inflate counts by splitting one root cause across many endpoints. Group systemic causes and list affected instances.

### Reconcile old reports with current reality

When dated reports, “final status” files, deployment guides, or release notes exist, create a claim ledger with: claim, source/date, affected version/commit, current code evidence, build/deployment evidence, runtime evidence, and status (`CURRENT`, `STALE`, `CONTRADICTED`, `PARTIAL`, `UNVERIFIED`). Do not combine contradictory claims into one narrative.

Use this evidence precedence, while recording exceptions:

1. observed production/staging runtime and deployed artifact;
2. reproducible tests on the exact release build;
3. current code/config/schema at a known commit;
4. generated payload/installer contents and hashes;
5. current operational documentation;
6. older reports and intentions.

A newer report is not automatically correct, and a recently modified file can describe an older architecture. Explicitly identify removed features, legacy binaries, unrotated keys, undeployed rules, and requirements the owner still must execute.

## Required deliverables

Return an executive summary first, then technical evidence. In audit mode, do not create files unless the user requests artifacts or the environment’s workflow requires them. When files are requested, use:

- `security/SECURITY_AUDIT.md`: scope, architecture, threat model, coverage, findings, prioritized plan, and residual risk;
- `security/findings.json`: machine-readable findings using the fields above;
- `security/SECURITY_TEST_PLAN.md`: repeatable manual/automated cases and safe environment requirements;
- `security/red-team/RED_TEAM_PLAN.md`: rules of engagement, attacker profiles, attack catalog, coverage matrix, and stop conditions;
- `security/red-team/RED_TEAM_REPORT.md`: frozen proofs, attack paths, failed attempts, evidence, cleanup, and open coverage gaps;
- `security/blue-team/REMEDIATION_PLAN.md`: containment, prioritized root-cause fixes, regression tests, detection/response improvements, owners, and rollback;
- `security/purple-team/RETEST_REPORT.md`: original and bypass re-attacks, detection validation, final states, residual risk, and release verdict;
- code/tests/config diffs only in harden mode;
- `security/VERIFICATION.md`: commands, versions, results, remaining gaps, and release decision.
- `security/FINAL_SECURITY_STATUS_AR.md`: owner-facing Arabic final status using the ordered template in `references/REPORTING_AND_STATE_RECONCILIATION.md`;
- `security/STATE_RECONCILIATION.md`: dated claim ledger comparing earlier reports, current code, release artifacts, and deployed/runtime state;
- `security/RELEASE_ARTIFACT_MANIFEST.md`: commit, build mode, signing identity/fingerprint, hashes, installer/payload contents, schema/migration version, and tests performed on the exact artifacts.

The owner-facing final report must preserve this order unless the user asks otherwise:

1. original state, Git checkpoint, branch, and exact rollback point;
2. architecture and source-of-truth model;
3. what was actually fixed, grouped by boundary;
4. tests executed with counts, platforms, versions, and exact release artifact;
5. verified findings and remaining risks;
6. what was not tested or was blocked;
7. operational actions the owner must still perform;
8. realistic protection limits and assumptions;
9. production-readiness verdict;
10. safe compare, rollback, and recovery commands.

End every assessment with:

1. verified Critical/High risks requiring immediate action;
2. the top three next actions in dependency order;
3. controls that passed with evidence;
4. blocked/untested areas and what is needed to test them;
5. residual risk and an explicit release recommendation.

## Release gate

Default to `FAIL` when any of these remains without documented risk acceptance:

- verified Critical or High vulnerability;
- cross-tenant/BOLA/BFLA failure;
- hardcoded production secret or exposed signing/encryption key;
- plaintext sensitive database/backup where encryption is a stated requirement;
- unverified or unrecoverable SQLCipher migration;
- known reachable critical dependency vulnerability;
- failing authz, migration, integrity, backup/restore, or security regression tests;
- debug/test bypass or unsafe production configuration;
- missing rollback for a release that changes keys, schema, auth, or sync semantics.
- a server-authoritative workflow that still trusts client price, total, role, tenant, sequence, owner, approval, or canonical timestamp;
- cache or Redis Pub/Sub/Socket.IO broadcast acting as the sole durable record of a committed business change;
- missing idempotency/transactional protection for retried financial, stock, booking, licensing, or sync commands;
- PostgreSQL tenant isolation not tested against owner/RLS bypass and pooled-session context leakage where RLS/session context is used;
- signed-license private key present in any client/admin build, repository/history, installer, backup, or shared workspace;
- release installer/payload not proven to contain the tested hardened binaries, or an old/debug artifact remains in the delivery path;
- contradictory security reports left unresolved for a material production control.
- Red Team Critical/High findings that are not `RETESTED_FIXED` or explicitly risk-accepted with compensating controls.

Never turn `NOT TESTED` into a passing gate. Use `PASS WITH ACCEPTED RISK` only when the owner explicitly records the risk, rationale, compensating controls, expiry/review date, and accountable owner.

## Primary references

Consult current official documentation before implementation or citation:

- OWASP ASVS 5.0.0 stable: https://owasp.org/www-project-application-security-verification-standard/
- OWASP MASVS/MASTG: https://mas.owasp.org/MASVS/
- OWASP API Security: https://owasp.org/www-project-api-security/
- OWASP Top 10 2025: https://owasp.org/www-project-top-ten/
- OWASP WSTG: https://owasp.org/www-project-web-security-testing-guide/
- NIST SSDF 1.1 final and SSDF 1.2 draft status: https://csrc.nist.gov/projects/ssdf and https://csrc.nist.gov/pubs/sp/800/218/r1/ipd
- Flutter security: https://docs.flutter.dev/security
- Flutter testing: https://docs.flutter.dev/testing/overview
- Node.js security practices: https://nodejs.org/learn/getting-started/security-best-practices
- Node.js supported releases and Permission Model: https://nodejs.org/en/about/previous-releases and https://nodejs.org/api/permissions.html
- NestJS security, validation, and gateways: https://docs.nestjs.com/security/authentication, https://docs.nestjs.com/security/authorization, https://docs.nestjs.com/techniques/validation, https://docs.nestjs.com/websockets/guards
- PostgreSQL current security/consistency: https://www.postgresql.org/docs/current/ddl-rowsecurity.html, https://www.postgresql.org/docs/current/transaction-iso.html, https://www.postgresql.org/docs/current/explicit-locking.html, https://www.postgresql.org/docs/current/ddl-schemas.html
- Redis security, ACL/TLS, Streams and Pub/Sub semantics: https://redis.io/docs/latest/operate/oss_and_stack/management/security/, https://redis.io/docs/latest/develop/data-types/streams/, https://redis.io/docs/latest/develop/pubsub/
- Socket.IO delivery and recovery: https://socket.io/docs/v4/delivery-guarantees and https://socket.io/docs/v4/connection-state-recovery
- npm dependency auditing: https://docs.npmjs.com/auditing-package-dependencies-for-security-vulnerabilities/
- Android Keystore: https://developer.android.com/privacy-and-security/keystore
- Android backup security: https://developer.android.com/privacy-and-security/risks/backup-best-practices
- Apple Keychain: https://developer.apple.com/documentation/security/storing-keys-in-the-keychain
- SQLCipher API and migration: https://www.zetetic.net/sqlcipher/sqlcipher-api/
- SQLCipher design: https://www.zetetic.net/sqlcipher/design/
- Drift encryption: https://drift.simonbinder.eu/platforms/encryption/
- Firebase Security Rules testing: https://firebase.google.com/docs/rules/unit-tests
- Firebase App Check: https://firebase.google.com/docs/app-check
- Supabase data security and RLS: https://supabase.com/docs/guides/database/secure-data
- Supabase Edge Function security: https://supabase.com/docs/guides/functions/auth

- OAuth 2.0 Security BCP (RFC 9700): https://www.rfc-editor.org/info/rfc9700/
- Google native OAuth and Drive appDataFolder: https://developers.google.com/identity/protocols/oauth2/native-app and https://developers.google.com/workspace/drive/api/guides/appdata
- GitHub secret remediation and Git switch: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository and https://git-scm.com/docs/git-switch
- SLSA current specification and CycloneDX: https://slsa.dev/spec/ and https://cyclonedx.org/docs/latest
