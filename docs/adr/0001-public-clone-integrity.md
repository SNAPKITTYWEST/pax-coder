# ADR-0001: Public Clone Integrity Verification

**Status:** Accepted  
**Date:** 2026-08-18  
**Author:** SNAPKITTYWEST PAX-Coder Security Team

---

## Context

A user who clones PAX-Coder from GitHub must be able to verify that the clone matches an officially published release without requiring authorization credentials or external systems.

Integrity verification answers:

> "Is this clone the exact artifact that was published?"

This is distinct from authorization, which answers:

> "Is this execution environment permitted to perform protected operations?"

## Decision

Implement integrity verification as an independent capability that:

1. **Does not require authorization** — A public clone can fully verify integrity without credentials
2. **Is publicly verifiable** — Any user with the public key and manifest can verify
3. **Uses only public key cryptography** — Ed25519 signatures, SHA-256 hashes
4. **Never produces corrupted data** — Integrity failure means verification fails, not silent corruption

## Architecture

```
RELEASED ARTIFACT
    ↓
Canonical Manifest (file list + hashes)
    ↓
Manifest SHA-256 Commitment
    ↓
Signed with Sovereign Node Private Key
    ↓
Public Release Record
    ├── Manifest
    ├── Signature (hex)
    ├── Node Public Key
    ├── Git Commit
    ├── Release Timestamp
    └── Prior-Art Record
```

External user verification:

```
CLONED REPOSITORY
    ↓
Read: sovereign/release.json (public key + signature)
    ↓
Verify signature on manifest
    ↓
Hash each tracked file
    ↓
Compare against manifest
    ↓
INTEGRITY_VERIFIED or INTEGRITY_FAILED
```

## Rules

```yaml
rules:
  - integrity verification MUST NOT require authorization
  - integrity verification MUST use only public cryptographic material
  - failed integrity MUST NOT proceed to protected operations
  - failed integrity MUST produce clear, non-corrupted error state
  - timestamp commitment MUST be included in verification
  - public key fingerprint MUST be verifiable independently
  - git commit MUST match exactly
  - all tracked files MUST be hash-verified
```

## Verification Command

```bash
./scripts/verify-release
```

Output distinguishes integrity from authorization:

```
PAX-CODER RELEASE VERIFICATION

[✓] Repository identity
[✓] Release version
[✓] Git commit
[✓] Canonical manifest
[✓] File integrity (N files)
[✓] Manifest SHA-256
[✓] Sovereign Node public key
[✓] Release signature (Ed25519)
[✓] Prior-art timestamp

RESULT: INTEGRITY VERIFIED
STATUS: No authorization attempted
NOTE: Protected operations require separate authorization
```

## What This Does NOT Guarantee

- Authorization to perform protected operations
- Code correctness or quality
- Legal ownership
- Bitcoin confirmation (unless separately timestamped)
- Immutability (user can modify clone locally)

## Tests Required

- `test_valid_release`: Verify successful release
- `test_modified_file`: Detect file modification
- `test_wrong_commit`: Detect commit mismatch
- `test_invalid_signature`: Detect signature failure
- `test_missing_manifest`: Detect missing manifest
- `test_corrupted_manifest_json`: Detect JSON corruption

## Consequences

- External users can verify provenance without requiring credentials
- CI must validate that integrity artifacts are correctly formed
- Documentation must clearly separate integrity from authorization
- Integrity failure is a hard stop; no silent corruption permitted

---

**Related ADRs:**
- ADR-0002: Authorization Boundary
- ADR-0004: Private Key Separation
