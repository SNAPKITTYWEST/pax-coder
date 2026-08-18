# ADR-0006: Server Challenge Protocol

**Status:** Accepted  
**Date:** 2026-08-18

---

## Decision

When authorization is required, use explicit challenge/response protocol.

```
Client → Server: node_id + release_identity + nonce
Server → Client: signature(authorization_token + timestamp + nonce)
Client: Verify signature, use token for protected operation
Token: Short-lived (1 hour), signed, includes nonce
```

## Rules

- Fresh nonces for replay protection
- Short-lived tokens (1 hour max)
- Signed responses (not encrypted secrets)
- TLS for transport security
- Explicit expiration timestamps
- No client-side fallback if server unavailable

## What This Prevents

- Replayed tokens
- Token reuse across releases
- Offline authorization generation
- Casual modification of authorization state

## Consequences

- Authorization is server-validated, not client-side
- Private keys never transmitted
- Compromised clone cannot manufacture valid tokens

---

**Related ADRs:**
- ADR-0002: Authorization Boundary
- ADR-0004: Private Key Separation
