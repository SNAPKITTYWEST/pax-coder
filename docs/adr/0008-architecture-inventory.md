# ADR-0008: Security Architecture Inventory & Conflict Analysis

**Status:** Proposed  
**Date:** 2026-08-18  
**Type:** Architecture Analysis  

---

## Purpose

This ADR maps every existing security-related artifact in PAX-Coder to its primary security property, identifies conflicts where mechanisms serve multiple properties, and documents the current architectural state before any implementation changes.

**Directive:** Do not modify security implementation until this inventory is approved.

---

## Security Properties (Canonical)

1. **PUBLIC_CLONABILITY** — Anyone may clone the repository
2. **RELEASE_INTEGRITY** — Official releases are cryptographically signed and verifiable
3. **NODE_IDENTITY** — Cryptographic identity controls signing operations
4. **RELEASE_SIGNING** — Releases are signed by a private key held by the authority
5. **PRIOR_ART_TIMESTAMP** — Cryptographic commitment has a recorded timestamp
6. **EXECUTION_AUTHORIZATION** — Protected operations require external capability or held secret

---

## Artifact Inventory

### Core Verification Scripts

#### `scripts/verify-clone`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Verify release integrity (property #2) |
| **Primary Input** | Git repository state + release.json |
| **Verification Steps** | Git commit match, manifest SHA256 match |
| **Output** | Exit 0 (INTEGRITY_VERIFIED) or exit 1 (FAILED) |
| **Cryptographic Primitive** | SHA-256 hash, git commit hash |
| **Property Provided** | RELEASE_INTEGRITY |
| **Dependencies** | sha256sum, git, release.json, manifest.json |
| **Callers** | verify-release (Phase 1) |
| **Tests** | test_verification.sh (Tests 1-3) |
| **Governing ADR** | ADR-0001 (Public Clone Integrity) |
| **Current Conflict** | None detected |

**Status:** ✅ Maps to exactly one property (RELEASE_INTEGRITY)

---

#### `scripts/verify-release`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Two-phase verification: integrity + authorization |
| **Primary Input** | Git state + release metadata + authorization token |
| **Verification Steps** | Phase 1: calls verify-clone; Phase 2: checks .node_sk OR PAX_AUTH_TOKEN |
| **Output** | Exit 0 (VERIFIED_AND_AUTHORIZED) or exit 2 (VERIFIED_NOT_AUTHORIZED) or exit 1 (INTEGRITY_FAILED) |
| **Cryptographic Primitive** | Delegates to verify-clone for integrity |
| **Properties Provided** | RELEASE_INTEGRITY (delegated) + EXECUTION_AUTHORIZATION (checked but not cryptographically verified) |
| **Dependencies** | verify-clone, environment variable PAX_AUTH_TOKEN |
| **Callers** | User-facing, optional in workflow |
| **Tests** | test_verification.sh (Tests 4-6) |
| **Governing ADR** | ADR-0002 (Authorization Boundary) |
| **Current Conflict** | ⚠️ AUTHORIZATION check is not cryptographically verified; only checks for presence of .node_sk or env var |

**Status:** ⚠️ Secondary input (.node_sk presence OR environment variable) is not cryptographically verified. This is a design issue.

---

### Node Key Generation

#### `sovereign/generate_node_key.sh`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Generate Ed25519 keypair locally (properties #3, #5) |
| **Primary Input** | None (generates random seed) |
| **Generates** | node.json (public identity), node_pk.pem (public key), .node_sk (private key) |
| **Output** | Local keypair + metadata + prior-art timestamp |
| **Cryptographic Primitive** | Ed25519 key generation, SHA-256 |
| **Properties Provided** | NODE_IDENTITY (#3) + PRIOR_ART_TIMESTAMP (#5) |
| **Dependencies** | openssl, date |
| **Callers** | User at `cd sovereign && ./generate_node_key.sh` |
| **Tests** | Integration test via verify_node_key.sh |
| **Governing ADR** | ADR-0004 (Private Key Separation) |
| **Current Conflict** | None — generates two properties together (identity + timestamp) but both are related to the same key generation event |

**Status:** ✅ Maps to two related properties (NODE_IDENTITY + PRIOR_ART_TIMESTAMP); this is acceptable because they share the same key generation event

---

#### `sovereign/verify_node_key.sh`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Verify generated keypair is mathematically valid |
| **Primary Input** | node.json, node_pk.pem, .node_sk |
| **Verification Steps** | Check PEM syntax, check key material consistency, verify Ed25519 properties |
| **Output** | Exit 0 (valid) or exit 1 (invalid) |
| **Cryptographic Primitive** | Ed25519 verification, openssl validation |
| **Properties Provided** | NODE_IDENTITY (verification only) |
| **Dependencies** | openssl |
| **Callers** | User after generate_node_key.sh |
| **Tests** | Manual integration test |
| **Governing ADR** | ADR-0004 (Private Key Separation) |
| **Current Conflict** | None detected |

**Status:** ✅ Maps to exactly one property (NODE_IDENTITY verification)

---

### Release Signing & Integrity

#### `sovereign/generate_release.sh`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Sign a release (properties #4, #2) |
| **Primary Input** | Private key (.node_sk), canonical manifest, git commit, metadata |
| **Generates** | release.json (signed metadata) |
| **Output** | release.json with Ed25519 signature |
| **Cryptographic Primitive** | Ed25519 signature over manifest hash |
| **Properties Provided** | RELEASE_SIGNING (#4) + RELEASE_INTEGRITY (#2, as commitment) |
| **Dependencies** | .node_sk (private key), openssl, manifest data |
| **Callers** | Release authority during release process |
| **Tests** | verify-clone validates the output |
| **Governing ADR** | ADR-0001 (Public Clone Integrity) |
| **Current Conflict** | ⚠️ This script is generating release.json with static commit hashes (updated manually). No integration with CI for automatic release signing. |

**Status:** ⚠️ Script exists but its inputs are not automatically verified. Currently requires manual update of git commit in release.json.

---

#### `sovereign/release.json`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Cryptographic manifest of official release |
| **Content** | Git commit, manifest hash, Ed25519 signature, public key, timestamp |
| **Format** | JSON |
| **Verification** | Via verify-clone (signature validation) |
| **Cryptographic Primitive** | Ed25519 signature, SHA-256 hashes |
| **Properties Provided** | RELEASE_INTEGRITY (#2) + NODE_IDENTITY (#3 reference) + PRIOR_ART_TIMESTAMP (#5 reference) |
| **Dependencies** | Public key (from node_pk.pem), manifest.json |
| **Callers** | verify-clone, verify-release |
| **Governing ADR** | ADR-0001 (Public Clone Integrity) |
| **Current Conflict** | 🔴 This file serves THREE properties simultaneously: integrity + identity reference + timestamp reference. This is the primary conflation point. |

**Status:** 🔴 CONFLICT DETECTED — release.json mixes three security properties. See section below.

---

#### `sovereign/manifest.json`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Canonical list of all tracked files + their hashes |
| **Content** | File paths → SHA-256 hashes |
| **Format** | JSON |
| **Verification** | SHA-256 hash verified in release.json |
| **Cryptographic Primitive** | SHA-256 |
| **Properties Provided** | RELEASE_INTEGRITY (#2) — the ground truth for file integrity |
| **Dependencies** | Tracked repository files |
| **Callers** | verify-clone (for file hash validation) |
| **Governing ADR** | ADR-0001 (Public Clone Integrity) |
| **Current Conflict** | None — pure integrity record |

**Status:** ✅ Maps to exactly one property (RELEASE_INTEGRITY)

---

### Node Key Metadata

#### `sovereign/node.json`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Public identity record |
| **Content** | node_id, public key (hex), creation timestamp, verification status |
| **Format** | JSON |
| **Verification** | Checked by verify_node_key.sh |
| **Cryptographic Primitive** | None (public metadata) |
| **Properties Provided** | NODE_IDENTITY (#3) + PRIOR_ART_TIMESTAMP (#5) |
| **Dependencies** | generate_node_key.sh output |
| **Callers** | verify_node_key.sh, reference in release.json |
| **Governing ADR** | ADR-0004 (Private Key Separation) |
| **Current Conflict** | ⚠️ Contains both identity AND timestamp. Acceptable because they share the same generation event. |

**Status:** ✅ Two properties, both tied to the same key generation event

---

#### `sovereign/node_pk.pem`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Public key in PEM format for signature verification |
| **Content** | Ed25519 public key |
| **Format** | PEM |
| **Verification** | Used by openssl in verify-clone to verify release signature |
| **Cryptographic Primitive** | Ed25519 public key |
| **Properties Provided** | NODE_IDENTITY (#3) — proof that this entity controls the signing |
| **Dependencies** | generate_node_key.sh |
| **Callers** | verify-clone (signature validation) |
| **Governing ADR** | ADR-0004 (Private Key Separation) |
| **Current Conflict** | None detected |

**Status:** ✅ Maps to exactly one property (NODE_IDENTITY)

---

#### `sovereign/.node_sk` (Private Key)

| Attribute | Value |
|-----------|-------|
| **Purpose** | Private signing key (NEVER DISTRIBUTED) |
| **Content** | Ed25519 private key seed |
| **Format** | Plain text (local only) |
| **Git Status** | In .gitignore, not tracked |
| **Verification** | N/A (private) |
| **Cryptographic Primitive** | Ed25519 private key |
| **Properties Provided** | RELEASE_SIGNING (#4) — proof that releases are authorized |
| **Dependencies** | generate_node_key.sh |
| **Callers** | generate_release.sh (for signing) |
| **Location** | Local filesystem, sovereign/ directory |
| **Governing ADR** | ADR-0004 (Private Key Separation) |
| **Current Conflict** | None — private keys belong in this one place only |

**Status:** ✅ Correctly isolated

---

#### `sovereign/prior_art.json`

| Attribute | Value |
|-----------|-------|
| **Purpose** | Timestamp record of key generation |
| **Content** | Timestamp, commitment hash, status |
| **Format** | JSON |
| **Verification** | Timestamp is human-readable but not cryptographically verified |
| **Cryptographic Primitive** | None (metadata only) |
| **Properties Provided** | PRIOR_ART_TIMESTAMP (#5) — proof of when commitment was recorded |
| **Dependencies** | generate_node_key.sh (generation time) |
| **Callers** | Reference in release.json, user verification |
| **Governing ADR** | ADR-0004 (Private Key Separation) |
| **Current Conflict** | ⚠️ Timestamp is local system time, not externally verified (accepted for prior art but noted as limitation) |

**Status:** ⚠️ Timestamp evidence is locally generated (not verified by external authority). This is documented as a limitation.

---

### ADRs (Architectural Constraints)

#### `docs/adr/0001-public-clone-integrity.md`
Governs: RELEASE_INTEGRITY (#2)

#### `docs/adr/0002-authorization-boundary.md`
Governs: EXECUTION_AUTHORIZATION (#6)

#### `docs/adr/0003-fail-closed-enforcement.md`
Governs: All properties (cross-cutting)

#### `docs/adr/0004-private-key-separation.md`
Governs: NODE_IDENTITY (#3), RELEASE_SIGNING (#4), PRIOR_ART_TIMESTAMP (#5)

#### `docs/adr/0005-native-verifier-cost.md`
Status: Proposal without implementation

#### `docs/adr/0006-server-challenge-protocol.md`
Governs: EXECUTION_AUTHORIZATION (#6) (future implementation)

#### `docs/adr/0007-codex-security-preservation.md`
Governs: ADR process itself

---

## Conflict Analysis

### Conflict 1: release.json Serves Multiple Properties

**Location:** `sovereign/release.json`

**Current State:**
```json
{
  "git_commit": "...",              // RELEASE_INTEGRITY
  "manifest_sha256": "...",         // RELEASE_INTEGRITY
  "signature_hex": "...",           // RELEASE_SIGNING
  "node_id": "...",                 // NODE_IDENTITY reference
  "node_public_key_hex": "...",     // NODE_IDENTITY
  "release_timestamp_utc": "...",   // PRIOR_ART_TIMESTAMP
  "prior_art_record": { ... }       // PRIOR_ART_TIMESTAMP
}
```

**Problem:** This file conflates:
- **RELEASE_INTEGRITY** (what is signed)
- **NODE_IDENTITY** (who signed it)
- **PRIOR_ART_TIMESTAMP** (when it was signed)
- **RELEASE_SIGNING** (proof of authorization)

**Assessment:** This is acceptable if the file is understood as "the signed release manifest" — integrity + metadata about the signer. However, the current implementation makes it ambiguous whether the node identity provides authorization (it does not) or just identification (it does).

**Recommendation:** Clarify in documentation that release.json provides:
- ✅ Proof of integrity (signature + manifest hash)
- ✅ Identification of signer (node_id, public key)
- ✅ Timestamp of commitment
- ❌ NOT authorization for execution (separate concern)

---

### Conflict 2: verify-release Conflates Integrity and Authorization

**Location:** `scripts/verify-release`

**Current State:**
```bash
Phase 1: Calls verify-clone (RELEASE_INTEGRITY)
Phase 2: Checks for .node_sk OR PAX_AUTH_TOKEN (EXECUTION_AUTHORIZATION)
```

**Problem:** The authorization check (Phase 2) is **not cryptographically verified**. It only checks:
- File exists (.node_sk)
- Environment variable set (PAX_AUTH_TOKEN)

Neither of these proves authorization. They prove possession of something, but:
- .node_sk presence = local access, not authorization
- Environment variable = client-side state, not authorization

**Assessment:** This is the core issue. The script says "VERIFIED_AND_AUTHORIZED" but the authorization part is theater.

**Recommendation:** Split verify-release into two explicit modes:
1. **Integrity-only mode** (public): `./scripts/verify-release --integrity-only`
   - Output: INTEGRITY_VERIFIED or INTEGRITY_FAILED
   - This is what verify-clone currently does

2. **Authorization check mode** (protected): `./scripts/verify-release --check-authorization`
   - Input: Authorization token (must come from external source)
   - Output: AUTHORIZATION_GRANTED or AUTHORIZATION_DENIED
   - Token must be cryptographically verified against a server/keypair, NOT just checked for presence

---

### Conflict 3: Node Key Generation Lacks Authorization Flow

**Location:** `sovereign/generate_node_key.sh`

**Current State:**
- Anyone with `PAX_AUTH_TOKEN` environment variable can generate a key
- The token is checked by verify-release, but:
  - Token is not cryptographically verified
  - Token presence = authorization (false assumption)

**Problem:** There is no external authorization mechanism. The payment flow exists (NODE_KEY_REQUEST_POLICY.md) but is not wired to the scripts.

**Assessment:** generate_node_key.sh is currently accessible to anyone. The authorization is documented but not implemented.

**Recommendation:** This is acceptable if the intent is:
- Scripts are open source (anyone can run them locally)
- Running them remotely (through a service) would enforce authorization
- OR: Implement token verification that validates against a server

---

## Summary: What Maps Where

| Property | Mechanism | Status |
|----------|-----------|--------|
| PUBLIC_CLONABILITY | GitHub public repo | ✅ OK |
| RELEASE_INTEGRITY | verify-clone + manifest.json + signature | ✅ OK |
| NODE_IDENTITY | node_pk.pem + node.json | ✅ OK |
| RELEASE_SIGNING | .node_sk (private) + generate_release.sh | ⚠️ Requires manual commit update |
| PRIOR_ART_TIMESTAMP | prior_art.json + node.json | ✅ OK (local timestamp, documented limitation) |
| EXECUTION_AUTHORIZATION | verify-release Phase 2 | 🔴 NOT IMPLEMENTED (only theater checks) |

---

## Proposed Fix (Minimum Diff)

**Do NOT implement until this ADR is approved.**

1. **Keep all existing files** — nothing deleted
2. **Clarify verify-release** — split into integrity-only and authorization modes
3. **Document the limitation** — authorization Phase 2 requires external capability (future work)
4. **Create ADR-0009** — detailing the authorization server protocol
5. **Update docs** — make clear: integrity is free and public, authorization requires external server

---

## Next Steps

This ADR is **PROPOSED**. Required before proceeding:

1. **Approve this inventory**
2. **Confirm conflict analysis**
3. **Authorize minimum-diff fixes**
4. **Then implement**

---

**Status:** Proposed (awaiting approval before implementation)  
**Next Action:** Review this inventory; approve conflicts; proceed with ADR-0009 for authorization server

