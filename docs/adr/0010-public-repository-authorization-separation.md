# ADR-0010: Public Repository vs. Production Authorization Separation

**Status:** Accepted  
**Date:** 2026-08-18  
**Architects:** SnapKitty PAX-Coder Authority  

---

## Context

PAX-Coder has multiple layers of access control:

1. **Repository visibility** (GitHub)
2. **Clone capability** (git)
3. **Source inspection** (local verification)
4. **Production authorization** (commercial provisioning)

These are separate concerns and must not be confused.

---

## Problem

Without explicit separation, future maintainers or automated agents may inadvertently:

1. **False claim**: "Node Key prevents cloning" (it does not)
2. **Feature creep**: Add checkout-time gates (complicates verification)
3. **Access model drift**: Treat "public repository" as synonymous with "public access to protected operations"
4. **Security regression**: Move from explicit authorization boundary to implicit/default-allow

---

## Decision

**Explicit permanent separation:**

### Layer 1: Repository Visibility (PUBLIC)

- Source code is publicly readable on GitHub
- Clone is unrestricted (`git clone` succeeds for anyone)
- Integrity verification is public and non-destructive
- **Purpose:** Enable inspection, verification, and confidence building

### Layer 2: Production Authorization (COMMERCIAL PROVISIONING ONLY)

- Protected operations require external authorization
- Node Key is an Ed25519 keypair (identity, not authorization)
- Provisioning requires: contact → approval → commercial agreement → operator signature
- Authorization cannot be generated locally or self-created
- **Purpose:** Control who can deploy to production and sign releases

### Critical Invariants (LOCKED)

```
INVARIANT 1: Public Clone ≠ Production Authorization
  Anyone can clone the repository.
  Cloning does NOT grant production authorization.
  Clone remains unprovisioned, unregistered, unauthorized.

INVARIANT 2: Node Key Identity ≠ Node Key Authorization
  Locally-generated keypair creates node IDENTITY.
  Operator-signed authorization record creates production AUTHORIZATION.
  Identity alone is insufficient; authorization requires operator signature.

INVARIANT 3: Repository Access ≠ Protected Operation Authorization
  Access to source ≠ access to protected operations.
  Verification (read) ≠ authorization (execute).
  Public inspection ≠ commercial deployment.

INVARIANT 4: Provisioning Flow is Explicit and Linear
  contact (user-initiated)
    ↓
  approval (authority reviews)
    ↓
  commercial agreement (terms established)
    ↓
  provisioning (operator-signed authorization)
    ↓
  protected operation (now authorized)
  
  No step can be skipped or automated.
  No developer can self-provision.
  No payment processor can create authorization (payment triggers review only).
```

---

## Communication

All documentation must include this sentence or equivalent:

> **PAX-Coder source is publicly cloneable for inspection and verification. Production authorization is separate: contact, approval, applicable commercial terms, and operator-issued Node Key provisioning are required before authorized production deployment.**

This appears in:
- README.md (prominently)
- SOVEREIGN_NODE_KEY.md (authorization section)
- CONTACT.md (provisioning form)
- All customer-facing docs

---

## Architecture

```
┌─ PUBLIC GITHUB REPOSITORY ──────────────────────┐
│                                                  │
│  $ git clone https://...pax-coder              │
│  $ ./scripts/verify-clone                       │
│  $ cat sovereign/authorization.json             │
│  $ ./scripts/verify-pax-coder                   │
│                                                  │
│  Result: INTEGRITY_VERIFIED, UNAUTHORIZED      │
│  (This is correct. Public clone has no auth.)   │
│                                                  │
└──────────────────────────────────────────────────┘
                      ↓
        (User wants production deployment)
                      ↓
┌─ COMMERCIAL PROVISIONING FLOW ──────────────────┐
│                                                  │
│ Step 1: Contact (pax-coder@snapkittywest.com)  │
│ Step 2: Approval (authority reviews, 1-3 days) │
│ Step 3: Agreement (commercial terms)            │
│ Step 4: Provisioning (operator-signed auth)     │
│                                                  │
│ Result: authorization.json with ACTIVE status   │
│         (Now production operations are allowed)  │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Implications

### What This Enables

✅ **Transparency**
- Anyone can inspect source code without friction
- Verification is public and repeatable
- No secret gates or hidden requirements

✅ **Security**
- Production authorization is explicit and verifiable
- Cannot be accidentally granted
- Cannot be self-created

✅ **Clarity**
- Public developers understand they have access to source, not production access
- Commercial customers understand provisioning is required
- Enterprise buyers understand authorization is explicit and time-limited

### What This Prevents

❌ **False Security Claims**
- No "Node Key prevents cloning" (it doesn't)
- No "Repository access implies authorization" (it doesn't)
- No "Default allow with gate" (authorization is default deny)

❌ **Confusion**
- Public ≠ authorized
- Identity ≠ authorization
- Verification ≠ execution

❌ **Regressions**
- Future maintainers cannot add checkout-time gates
- Cannot shift to implicit authorization
- Cannot automate provisioning (must stay explicit)

---

## Decisions Locked

1. **Repository remains PUBLIC** — Never make it private
2. **Clone remains unrestricted** — Never add pre-clone gates
3. **Authorization is explicit** — Never default-allow
4. **Provisioning is manual** — Never auto-provision
5. **Operator signature required** — Never remove from critical path

---

## Related ADRs

- **ADR-0002**: First principles on boundaries (superseded by 0009+0010)
- **ADR-0009**: Protected execution capability gate architecture
- **ADR-0001-0008**: Authorization decision records

---

## Review Criteria

If a future change or proposal violates any of the four invariants above, it requires:

1. Explicit justification (why the invariant was wrong)
2. Legal review (commercial/liability implications)
3. Security review (new attack surface)
4. Customer notification (existing provisioning terms may no longer apply)

Simple agent recommendations to "consolidate" or "improve" access control do NOT override this ADR.

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*
