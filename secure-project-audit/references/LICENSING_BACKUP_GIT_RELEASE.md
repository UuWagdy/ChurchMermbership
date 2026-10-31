# Licensing, Backup, Git, and Release Hardening Reference

## 1. Signed licensing and trials

### License format

Use a versioned, canonical payload signed with a modern asymmetric algorithm. Include and verify:

- format version and explicit algorithm;
- key identifier (`kid`) and product/domain separation;
- unique license/lease ID;
- customer/tenant, product, edition/features;
- device enrollment identifier and installation identifier where intended;
- issued-at, not-before, absolute expiry/lease expiry and optional offline grace;
- schema/minimum client version and issuer/audience;
- signature over the exact canonical bytes.

Reject unknown algorithms, keys, versions, duplicate fields, non-canonical encodings, unsupported future formats and downgrade to legacy formats unless an explicit time-limited migration flag exists.

### Private key lifecycle

- Never embed the private key in client apps, Flutter assets, `.env` shipped to customers, admin activator binaries, installers, CI logs or repository history.
- Prefer KMS/HSM or a dedicated offline encrypted signing device. If a local PEM is unavoidable, load it externally per session, restrict ACL, use full-disk encryption and maintain encrypted offline backups.
- Activators verify the expected public-key fingerprint/key size and do not remember the private key or a default administrator password.
- Log issuance metadata and operator approval, not the private key or full sensitive payload.
- Support key rotation with a public-key keyring and explicit `kid`; define overlap, revocation and retirement.

### Offline trial receipt

An offline receipt may contain:

- installation/device/product binding;
- redeemed trial/license ID;
- first trusted time, last accepted time and monotonic elapsed evidence;
- accumulated usage where required;
- integrity/version metadata.

Protect it with authenticated encryption and OS-protected key material. Verify writes and fail closed on corruption/rollback for protected actions. Flush at important lifecycle points and test crashes between state update and persistence.

State the limitation: full local administrator/root control can erase app/OS state, alter the runtime or restore a VM/image. Offline controls raise cost and stop ordinary reset/reuse; they cannot guarantee one trial forever. Strong uniqueness and revocation need an online authority or trusted hardware.

### Online lease evolution

Prefer:

- authenticated device enrollment;
- server-side unique trial redemption;
- signed short/medium-lived leases verified locally;
- refresh with nonce/replay protection;
- bounded grace for outages;
- device/user revocation and audit;
- key rotation and emergency kill/deny policy with safe owner recovery;
- rate limits and abuse monitoring.

Test service outage, stale lease, revoked device, copied lease, clock rollback, refresh replay, account transfer and key rotation.

## 2. Git security hardening workflow

### Before changes

1. `git status --short`
2. record current branch and `git rev-parse HEAD`
3. inspect remotes, submodules and ignored files
4. identify unrelated dirty work and generated artifacts
5. create a dedicated security branch from a known checkpoint when authorized

Never silently stage unrelated changes. Prefer a patch/worktree when the tree cannot be cleanly checkpointed.

### Secret search scope

Search:

- current tracked files and configuration examples;
- ignored/untracked `.env`, PEM, keystores, database dumps and backup folders;
- Git history and deleted files when available;
- release APK/EXE/DLL/JS bundles, source maps, installers and payload archives;
- CI artifacts, logs, crash dumps and copied legacy workspaces.

Do not print secrets. Record type, location, owner/provider and redacted fingerprint.

### Leaked-secret order of operations

1. contain exposure and identify dependent systems;
2. rotate/revoke the credential first;
3. update applications/deployments and verify new credential;
4. consider history rewrite only after rotation and coordination;
5. rebuild artifacts and invalidate/delete unsafe old distributions;
6. add secret scanning/push protection/pre-commit controls.

A new commit deleting a secret does not make the old secret safe. History rewriting can be recontaminated by old clones and needs coordinated re-cloning/cleanup.

### Safe compare and rollback

Record commands similar to:

```powershell
git diff <checkpoint>..<security-branch>
git switch <original-branch>
git switch -c restore-before-security <checkpoint>
git switch <security-branch>
```

Avoid `git reset --hard` or destructive clean commands around uncommitted work.

## 3. Encrypted backup and restore

### Backup envelope

Use a versioned manifest containing:

- product/tenant/account scope;
- backup ID and creation time;
- schema/app format version;
- compression and encryption algorithms;
- nonce/IV, authenticated metadata and ciphertext checksum/tag;
- snapshot cursor/boundary and object/table counts;
- key-wrapping/recovery-key identifier;
- retention/version metadata.

Encrypt before upload with authenticated encryption. Never store the unwrapped key beside the backup.

### Recovery keys

- Device-only keying prevents clean-install recovery; design recovery deliberately.
- User recovery secrets need sufficient entropy, rate-limited derivation and clear loss consequences.
- Envelope encryption may wrap a random content key to a recovery public key or server KMS.
- Upload-only clients should have only the public/wrapping authority, not private recovery material.
- “Upload-only” inside the application is not a Google/cloud IAM role if the same account/token can delete or inspect objects.

### Restore protocol

1. authenticate/authorize restore and step up for sensitive actions;
2. download to a bounded staging location;
3. verify account/tenant, version, size, signature/tag, decompression limits and schema;
4. open with the correct key and run integrity/relationship/invariant checks;
5. preserve license/device credentials according to explicit policy;
6. journal the operation and atomically swap only after verification;
7. recover safely from power loss before/after commit;
8. reconcile with server-authoritative state before replaying pending commands;
9. retain rollback for the agreed window and clean staging safely.

Test wrong account/key/passphrase, truncated/tampered/oversized/decompression-bomb backup, old schema, partial download, low disk, power loss, duplicate restore and clean-install recovery.

## 4. Google Drive native backup

Only apply if the current code actually uses Google Drive.

- Native/desktop authorization uses system browser, Authorization Code flow with PKCE-S256, unique `state`, exact registered redirect and random loopback port where applicable.
- A native client cannot keep a client secret confidential; do not treat an embedded secret as protection.
- Request the narrowest scope, such as `drive.appdata` when suitable.
- Protect refresh tokens in Android Keystore/Apple Keychain/Windows DPAPI or equivalent and revoke/delete on disconnect.
- `appDataFolder` is hidden and app-isolated, but the user/app can delete it; it is not immutable backup or true role separation.
- Do not transfer license, trial receipt, device token or private recovery seed in the business-data backup.
- WorkManager/OS scheduling is best-effort. Show last success, last failure, next eligible attempt and a manual foreground action. Test force-stop/reboot/vendor restrictions.
- Backup is not concurrent multi-device synchronization.

## 5. Windows server, installer, service and LAN delivery

### Build and payload integrity

- Produce Release artifacts from the recorded hardened commit.
- Generate a manifest of filenames, hashes, versions, build flags, schema/migration and signing identity.
- Inspect the installer payload/archive itself; do not assume it was refreshed.
- Quarantine/delete from delivery paths any old/debug/secret-bearing build after owner approval.
- Sign the installer and executables where feasible; verify signature after packaging and download/copy.

### Filesystem and service identity

- Executables belong under Program Files or another protected install location.
- Mutable data belongs in per-user app data or a dedicated service data directory, not beside the executable.
- Use a dedicated least-privilege service identity. Restrict ACLs on database, config, secrets, logs and backups.
- Do not grant all users modify access to executable/service directories.
- Define uninstall behavior: preserve or remove customer data only with clear confirmation and backup policy.

### Network and TLS

- Bind only required interfaces.
- Firewall scope should match the design, commonly Private/Domain and LocalSubnet for an in-company server, not public-anywhere.
- Use TLS in production and validate/pin the intended certificate or trust chain. Plan certificate renewal/rotation.
- Restrict PostgreSQL/Redis to the backend host/private network rather than exposing them to clients.
- Test proxy headers, DNS/IP changes, local discovery and certificate mismatch.

### Clean-machine test matrix

On a clean supported Windows VM/machine test:

1. install with and without expected prerequisites;
2. service starts under the intended identity after reboot;
3. ACLs and data paths are correct;
4. firewall rules are exactly scoped;
5. health endpoint reveals no secrets and is appropriately restricted;
6. two client devices on LAN authenticate and sync;
7. server interruption/restart and network loss preserve local pending work;
8. TLS/certificate mismatch fails safely;
9. upgrade from supported old version migrates safely;
10. rollback/downgrade policy is enforced;
11. backup/restore and power interruption work;
12. uninstall/reinstall follows the documented data/license policy.

## 6. Android and other client release delivery

- Build Release with a real protected signing key; reject debug signing/configuration.
- Inspect merged release manifest, network security config, backup/data extraction rules and exported components.
- Verify no production secret/private key is in APK/assets/native libraries/Dart defines.
- Test clean install, upgrade, reinstall, offline use, background restrictions, secure-storage failure and restored OS backup.
- Retain signing-key recovery and rotation plan; losing the signing key can block updates.

## 7. Release artifact gate

Fail if:

- private signing/licensing/database/recovery keys exist in distributed artifacts or repository history without rotation;
- installer/payload hashes do not match the tested build;
- Debug APK or old installer remains an approved delivery candidate;
- clean-machine install/service/firewall/TLS/LAN tests are absent;
- backup restore is untested or can transfer device/license trust incorrectly;
- required operational actions (rules deployment, OAuth config, key rotation, firewall/cert setup) are described as completed when they are not;
- no safe branch/checkpoint/rollback exists for key, schema, auth or sync changes.
