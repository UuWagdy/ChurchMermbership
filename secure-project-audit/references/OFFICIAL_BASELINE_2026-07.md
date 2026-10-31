# Official Security Baseline — reviewed 2026-07-17

This file records the official-source baseline used when updating the skill. Before implementation or versioned citations, browse the latest official source again.

## Standards status

- OWASP ASVS latest stable observed: 5.0.0. Use version-qualified IDs such as `v5.0.0-x.y.z` because identifiers can change.
  - https://owasp.org/www-project-application-security-verification-standard/
- OWASP Top Ten current released version observed: 2025.
  - https://owasp.org/www-project-top-ten/
- OWASP WSTG stable released version observed: 4.2; 5.0 is under development.
  - https://owasp.org/www-project-web-security-testing-guide/
- OWASP MASVS/MASTG current online standard and tests:
  - https://mas.owasp.org/MASVS/
- NIST SP 800-218 SSDF 1.1 remains final. SSDF 1.2 was an Initial Public Draft published 2025-12-17; label it as draft until finalized.
  - https://csrc.nist.gov/pubs/sp/800/218/final
  - https://csrc.nist.gov/pubs/sp/800/218/r1/ipd

## OpenAI skill packaging

- A Codex skill is a directory with required `SKILL.md` and optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml`.
- Codex initially sees name, description and path, then loads full `SKILL.md` when selected. Descriptions should front-load triggers.
- Skills can be explicitly selected using `/skills` or `$` in CLI/IDE; changes are detected automatically, with restart as fallback.
- ChatGPT Skills supports Create → Upload from computer.
- API skill upload accepts a directory multipart upload or a `.zip` containing a single top-level folder.
  - https://developers.openai.com/codex/build-skills
  - https://help.openai.com/en/articles/20001066-skills-in-chatgpt
  - https://developers.openai.com/api/docs/guides/tools-skills

## Node.js and NestJS

- Production Node applications should use Active LTS or Maintenance LTS releases.
  - https://nodejs.org/en/about/previous-releases
- Node Permission Model is stable and can restrict filesystem, network, child process, worker, addon, WASI and other capabilities when launched with `--permission`; it is defense in depth.
  - https://nodejs.org/api/permissions.html
- NestJS official references:
  - authentication: https://docs.nestjs.com/security/authentication
  - authorization: https://docs.nestjs.com/security/authorization
  - validation: https://docs.nestjs.com/techniques/validation
  - WebSocket guards: https://docs.nestjs.com/websockets/guards
  - rate limiting: https://docs.nestjs.com/security/rate-limiting
  - CORS/Helmet/CSRF: https://docs.nestjs.com/security/cors

## PostgreSQL

- Current docs observed at PostgreSQL 18.
- RLS becomes default-deny when enabled and no policy applies, but table owners typically bypass RLS; test owner/BYPASSRLS paths and consider FORCE RLS.
  - https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- `search_path` trusts users who can create objects in included schemas; revoke unnecessary CREATE on `public` and schema-qualify sensitive paths.
  - https://www.postgresql.org/docs/current/ddl-schemas.html
- SCRAM-SHA-256 is the preferred password method; MD5 password support is deprecated.
  - https://www.postgresql.org/docs/current/auth-password.html
- Transaction isolation, row/advisory locks and retries must be designed for concurrency.
  - https://www.postgresql.org/docs/current/transaction-iso.html
  - https://www.postgresql.org/docs/current/explicit-locking.html

## Redis and real-time delivery

- Redis Pub/Sub has at-most-once delivery; lost/disconnected subscribers cannot replay messages.
  - https://redis.io/docs/latest/develop/pubsub/
- Redis Streams provides append-only log and consumer-group/acknowledgement primitives, but application consumers still require idempotency and poison handling.
  - https://redis.io/docs/latest/develop/data-types/streams/
- Redis ACL/TLS and deployment security:
  - https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/
  - https://redis.io/docs/latest/operate/oss_and_stack/management/security/encryption/
- Redis client-side caching invalidation requires clients to remove stale keys; version/authoritative fallbacks remain necessary.
  - https://redis.io/docs/latest/develop/reference/client-side-caching/

## Socket.IO

- Socket.IO guarantees message ordering, but default delivery is at-most-once; stronger client-to-server retries require ACK/idempotency and pending events can still be lost on client termination.
  - https://socket.io/docs/v4/delivery-guarantees
- Connection-state recovery is opportunistic and may fail. Applications still need a state synchronization path. `skipMiddlewares` can allow a blocked user to recover without revalidation.
  - https://socket.io/docs/v4/connection-state-recovery

## OAuth and Google Drive

- OAuth 2.0 Security Best Current Practice: RFC 9700 / BCP 240.
  - https://www.rfc-editor.org/info/rfc9700/
- Google installed-app OAuth supports PKCE and requires a unique verifier/challenge per authorization request.
  - https://developers.google.com/identity/protocols/oauth2/native-app
- Google Drive `appDataFolder` is hidden/app-specific and uses `drive.appdata`, but users/app can delete the data; it is not immutable storage.
  - https://developers.google.com/workspace/drive/api/guides/appdata
- Android WorkManager scheduling is constraint- and OS-dependent; work may stop/retry as constraints change.
  - https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work

## Git and supply chain

- Rotate/revoke a leaked secret before history cleanup. Deleting it in a new commit is not remediation.
  - https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
- Use `git switch`/branches for safe rollback paths.
  - https://git-scm.com/docs/git-switch
- SLSA current site and provenance/source tracks:
  - https://slsa.dev/spec/
- CycloneDX current BOM specification:
  - https://cyclonedx.org/docs/latest
