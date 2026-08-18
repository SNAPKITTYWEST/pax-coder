# ADR-0002: Authorization Boundary

**Status:** Accepted  
**Date:** 2026-08-18  
**Author:** SNAPKITTYWEST PAX-Coder Security Team

---

## Context

A public clone can verify integrity independently. However, some operations may require authorization:

- Accessing private proof-kernel secrets
- Signing attestations
- Modifying WORM-sealed records
- Publishing authorized artifacts

Authorization must NOT be enforceable by commenting out a Python conditional.

## Decision

Implement authorization as a separate capability that:

1. **Requires externally held secrets or server validation** — Not derived from client-side checks
2. **Fails closed** — Unauthorized execution produces an explicit error, not silent degradation
3. **Never corrupts state** — Authorization failure means "operation unavailable," not "output is garbage"
4. **Uses challenge/response** — Server validates authorization, not client

## Architecture

```
INTEGRITY_VERIFIED
    ↓
Request Protected Operation
    ↓
┌───────────────────────────────────┐
│ Authorization Boundary            │
│ ├─ Node ID                        │
│ ├─ Release identity               │
│ ├─ Server challenge (nonce)       │
│ └─ Authorization protocol         │
└───────────────────────────────────┘
    ↓
Authorization Service
    │
    ├─ Validate authorization
    ├─ Check credentials
    ├─ Verify nonce
    └─ Issue capability
    ↓
Short-lived Capability
    ↓
Protected Operation Available
```

## Rules

```yaml
rules:
  - authorization MUST NOT depend solely on client-side conditionals
  - authorization MUST NOT depend on machine fingerprint as cryptographic proof
  - authorization MUST NOT embed private keys in the public repository
  - authorization MUST NOT embed server secrets in the public clone
  - unauthorized protected operations MUST fail closed with clear error
  - authorization MUST use fresh nonces for replay protection
  - authorization MUST use short-lived tokens
  - authorization response MUST be cryptographically signed (if server-provided)
  - authorization state MUST NOT be represented by silent corruption
```

## Implementation Strategy

### Phase 1: Integrity-Only (Now)

```
INTEGRITY_VERIFIED
    ↓
Protected operation: NOT AVAILABLE
    ↓
PAX-CODER AUTHORIZATION REQUIRED
Exit with clear error
```

### Phase 2: Authorization Service (Future)

When authorization service exists:

```
INTEGRITY_VERIFIED
    ↓
Request capability from authorization service
    ├─ Node ID
    ├─ Release identity
    ├─ Nonce
    └─ TLS
    ↓
Authorization service validates
    ↓
Issue short-lived token
    ↓
Protected operation executes
    ↓
Token expires (e.g., 1 hour)
```

## Failure States

```
INTEGRITY_VERIFIED + NO_AUTHORIZATION
    → PAX-CODER AUTHORIZATION REQUIRED
    → Protected capability unavailable

INTEGRITY_VERIFIED + EXPIRED_AUTHORIZATION
    → Authorization expired
    → Re-authenticate

INTEGRITY_VERIFIED + INVALID_AUTHORIZATION
    → Authorization validation failed
    → Protected capability unavailable

INTEGRITY_FAILED
    → Skip authorization entirely
    → Fail with integrity error
```

## What This Does NOT Guarantee

- Modification is impossible (it is possible; just detectable)
- User cannot bypass authorization (they can modify code; just not manufacture capability)
- Protection is absolute (it's protection from casual misuse, not sophisticated attackers)

## Tests Required

- `test_unauthorized_denied`: Protected operation fails without authorization
- `test_authorization_required_error`: Clear error message when authorization missing
- `test_no_silent_corruption`: Unauthorized state does not silently corrupt output
- `test_capability_required`: Modifying Python check does not grant authorization
- `test_nonce_replay`: Replayed nonce rejected
- `test_token_expiration`: Expired token rejected

## Consequences

- Public clone cannot execute protected operations without external validation
- Authorization failure is explicit and non-recoverable
- Authorization is never represented by corrupted state
- Documentation must explain what operations require authorization

---

**Related ADRs:**
- ADR-0001: Public Clone Integrity
- ADR-0003: Fail-Closed Enforcement
- ADR-0004: Private Key Separation
