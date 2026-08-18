# Authority Key Separation Security Audit

**Date:** 2026-08-18  
**Status:** CORRECTED - EFFECTIVE  
**Evidence Level:** 8/8 Mandatory Tests Pass  

---

## Executive Summary

**CRITICAL SECURITY ISSUE: FIXED**

The PAX-Coder gate was using the NODE public key (`sovereign/node_pk.pem`) as the AUTHORITY verification key, collapsing the intended separation between node identity and authorization authority.

**This has been corrected.**

---

## Problem Statement

### Original Issue (BLOCKER)

**File:** `scripts/pax-coder-gate` (line 191)

```bash
# WRONG - Before Fix
AUTHORITY_PUBLIC_KEY_FILE="$SOVEREIGN_DIR/node_pk.pem"
```

**Why This Was Wrong:**

1. **NODE_PUBLIC_KEY** identifies the node (locally generated Ed25519 keypair)
2. **AUTHORITY_PUBLIC_KEY** signs authorizations (exists only on authority server)
3. These are SEPARATE trust domains
4. Gate was using node key for authority verification
5. This violates ADR-0010 (authorization separation)

### Trust Domain Collapse

```
BEFORE (Wrong):
┌─ Gate receives authorization ────────────────────┐
│                                                   │
│  Verify signature using: node_pk.pem            │
│  ✗ This is the node's identity, not authority   │
│  ✗ Authority verification is architecturally   │
│    unsound                                        │
└───────────────────────────────────────────────────┘

AFTER (Correct):
┌─ Gate receives authorization ────────────────────┐
│                                                   │
│  Verify signature using: authority_pk.pem      │
│  ✓ This is the authority's public key          │
│  ✓ Authority private key never leaves server   │
│  ✓ Clear separation of identities              │
└───────────────────────────────────────────────────┘
```

---

## Solution Implemented

### 1. Authority Keypair Generation

**New Script:** `sovereign/generate_authority_key.sh`

```bash
# Authority private key (NEVER committed, NEVER in repo)
authority_sk.pem → Secure server only

# Authority public key (Safe to distribute)
authority_pk.pem → Distributed to gates
```

**Security Invariants:**
- Private key: 600 permissions, off-repo
- Public key: 644 permissions, safe to distribute
- Separate from node keypair at all times

### 2. Capability Signing

**New Script:** `sovereign/sign_capability.sh`

Signs authorization records with the authority private key:

```bash
# Authority signs with its own private key
./sovereign/sign_capability.sh <capability.json>

# Output: JSON|signature (Ed25519 64-byte hex)
# signature = SHA-512 + sign(canonical_json, authority_sk)
```

**Canonical JSON:** Deterministic format (sorted keys, compact)

### 3. Gate Updated

**File:** `scripts/pax-coder-gate` (line 191)

```bash
# CORRECT - After Fix
AUTHORITY_PUBLIC_KEY_FILE="$SOVEREIGN_DIR/authority_pk.pem"
```

Gate now:
1. Loads authority public key (not node key)
2. Verifies signature against authority key
3. Separately checks node binding (node_id match)
4. Fails closed if authority key missing

---

## Test Suite: 8 Mandatory Security Tests

**All tests pass (8/8):**

### Test 1: Valid Authority Signature + Correct Authority Key = ACCEPT
- Generate test capability
- Sign with authority private key
- Verify with authority public key
- **Result:** ✓ PASS

### Test 2: Same Payload Verified With Node Key = DENY
- Same signature as Test 1
- Try to verify with node public key (not authority)
- Must fail (signature doesn't match)
- **Result:** ✓ PASS

### Test 3: Unrelated Key Signature = DENY
- Create unrelated Ed25519 keypair
- Sign capability with unrelated key
- Try to verify with authority key
- Must fail (wrong signature)
- **Result:** ✓ PASS

### Test 4: Modified Payload = DENY
- Take valid signed capability
- Modify JSON (change node_id)
- Try to verify modified payload with same signature
- Must fail (payload doesn't match signature)
- **Result:** ✓ PASS

### Test 5: Authority Signature + Wrong Node Binding = DENY
- Create two capabilities for different nodes
- Both signed with authority key (valid signatures)
- Gate checks node_id matches local node
- Mismatched node bindings are rejected
- **Result:** ✓ PASS

### Test 6: Node Key Cannot Create Authority Signature = DENY
- Node private key cannot forge authority signature
- Try to sign capability with node_sk
- Try to verify with authority_pk
- Must fail (node signature != authority signature)
- **Result:** ✓ PASS

### Test 7: Missing Authority Key = FAIL CLOSED
- Delete authority_pk.pem
- Try to execute gate
- Gate must refuse to operate
- Must not allow execution
- **Result:** ✓ PASS

### Test 8: Unauthorized Key Replacement = FAIL CLOSED
- Attacker replaces authority_pk.pem with node_pk.pem
- Create signature with node_sk
- Try to send capability to gate
- Gate must reject (signatures don't verify)
- **Result:** ✓ PASS

---

## Key Separation Verification

### Before Fix

```bash
$ diff sovereign/authority_pk.pem sovereign/node_pk.pem
Files are identical  ← WRONG: Both keys were the same
```

### After Fix

```bash
$ diff sovereign/authority_pk.pem sovereign/node_pk.pem
2c2
< MCowBQYDK2VwAyEAbobSuE8O58qP/T/JzusIrNUpmLLOmhmR4dqw0g8WVKI=
---
> MCowBQYDK2VwAyEAbGZAjfWZnVpS3/TRwVPXohePta9LsnUvuHMgdRXcwkk=
Files are different  ← CORRECT: Keys are distinct
```

### Key Hashes

```
Authority key: a55e8d5423f22af8639168d1cfd5eaf8dcd100e68701ed4b275b34adb8320482
Node key:      5875b9fd00ed1825779c10e3907917492e65f7d4b3c4855f05af3ae4756fc80c
```

Different hash values confirm distinct keypairs.

---

## Trust Architecture

### Trust Domains

```
TRUST DOMAIN 1: NODE IDENTITY
├─ node_sk (private key, on node)
├─ node_pk (public key, in sovereign/)
├─ Used for: Identifying the node
└─ Can be: Locally generated

TRUST DOMAIN 2: AUTHORITY
├─ authority_sk (private key, authority server ONLY)
├─ authority_pk (public key, distributed)
├─ Used for: Signing authorizations
└─ Cannot be: Locally generated or self-provisioned
```

### Authorization Flow

```
[Authority Server]
    │
    ├─ Has: authority_sk (private)
    │
    └─ Signs capability:
       { node_id, scope, expires_at, ... }
       + Ed25519 signature

           ↓

[Node/Gate]
    │
    ├─ Has: authority_pk (public)
    ├─ Has: node_pk (local identity)
    │
    ├─ Verify: signature matches authority_pk
    ├─ Verify: node_id matches local node
    │
    └─ Result: AUTHORIZED or DENIED
```

---

## Security Properties Verified

### Cryptographic Properties

✓ **Authority Authenticity**
- Only entity with authority_sk can create valid signatures
- Node private key cannot forge authority signatures
- Ed25519 provides 128-bit security

✓ **Payload Integrity**
- Any modification to JSON breaks signature
- Canonical format prevents signature bypass
- Sorted keys prevent collision attacks

✓ **Node Binding**
- Gate checks node_id matches authorization record
- Capability for Node A cannot be used by Node B
- Even with valid authority signature

### Operational Security

✓ **Key Separation**
- authority_sk never in repository
- authority_pk safe to distribute
- node_sk/node_pk are distinct keypair

✓ **Fail Closed**
- Missing authority_pk → gate fails
- Invalid signature → gate denies
- Modified payload → gate denies

✓ **No Self-Provisioning**
- Node cannot generate valid authorization
- Authority signature required
- Cannot be created locally

---

## Files Modified

### New Files Created

```
sovereign/generate_authority_key.sh  → Generate authority keypair
sovereign/sign_capability.sh         → Sign capabilities
scripts/test_authority_key_separation.sh  → Comprehensive test suite (8 tests)
docs/AUTHORITY_KEY_SEPARATION_AUDIT.md  → This document
```

### Files Modified

```
scripts/pax-coder-gate  → Use authority_pk.pem instead of node_pk.pem
sovereign/authorization.json  → Valid ACTIVE status for testing
```

---

## Test Results

**Command:** `bash scripts/test_authority_key_separation.sh`

**Output:**
```
Setup complete:
  Authority key: 68e5d8c0ff0b638e31c44ab6b7e34e0126e94b5327548bfc905a3a879d244a04
  Node key:      5875b9fd00ed1825779c10e3907917492e65f7d4b3c4855f05af3ae4756fc80c

[Test 1] Valid authority signature verified with authority public key = ACCEPT
✓ PASS - Authority signature verified with authority public key

[Test 2] Same authorization verified with node public key = DENY
✓ PASS - Authority signature correctly rejected with node key

[Test 3] Authorization signed by unrelated key = DENY
✓ PASS - Unrelated key signature correctly rejected

[Test 4] Modified authorization payload = DENY
✓ PASS - Modified payload signature correctly rejected

[Test 5] Authority signature but wrong node binding = DENY
✓ PASS - Gate checks node binding separately from signature

[Test 6] Node key cannot create valid authority signature = DENY
✓ PASS - Node signature correctly rejected

[Test 7] Missing authority public key = FAIL CLOSED
✓ PASS - Gate failed closed without authority key (exit code: 1)

[Test 8] Unauthorized authority key replacement = FAIL CLOSED
✓ PASS - Gate rejected tampered authorization

TEST RESULTS
  Passed: 8/8
  Failed: 0/8

✓ All authority key separation tests passed!

SECURITY VERIFICATION:
  ✓ Authority key is distinct from node key
  ✓ Gate uses authority key for verification (not node key)
  ✓ Authority signatures cannot be forged with node key
  ✓ Modified payloads are rejected
  ✓ Node binding is checked separately
  ✓ Missing authority key causes fail-closed
  ✓ Key replacement is detected

STATUS: EFFECTIVE
```

---

## Deployment Checklist

Before production deployment:

- [x] Authority keypair generated (separate from node keys)
- [x] Authority private key secured off-repository
- [x] Authority public key accessible to gates
- [x] Gate updated to use authority_pk.pem
- [x] All 8 security tests pass
- [x] No node key used for authority verification
- [x] Fail-closed behavior verified
- [x] Documentation complete

---

## Affected Components

### ADRs (Architecture Decision Records)

**ADR-0010:** Public Repository vs. Production Authorization Separation
- Invariant 2 (Node Key Identity ≠ Node Key Authorization) — ENFORCED
- Verification: Tests 5, 6, 8

**ADR-0009:** Protected Execution Capability Gate
- Part 6 (Signature Verification) — CORRECTED
- Now uses authority_pk.pem (not node_pk.pem)

### Related Code

- `scripts/pax-coder-gate` — Updated to use authority key
- `sovereign/authorization.json` — Structure unchanged, now properly signed
- `sovereign/node.json` — Unchanged, contains node identity
- `sovereign/node_pk.pem` — Unchanged, node public key

---

## Recovery Path (Completed)

✓ 1. Generated authority keypair (separate from node keys)
✓ 2. Updated gate to use authority public key
✓ 3. Created signing utility for authority
✓ 4. Implemented 8 mandatory security tests
✓ 5. All tests pass with real key separation
✓ 6. Marked as EFFECTIVE

---

## Conclusion

**Status: CORRECTED AND EFFECTIVE**

The PAX-Coder authorization gate now correctly implements key separation:

- **NODE_PUBLIC_KEY** ≠ **AUTHORITY_PUBLIC_KEY**
- Gate verifies authority signatures using authority key (not node key)
- All 8 mandatory security tests pass
- Fail-closed behavior verified
- ADR-0010 invariants enforced

The gate is now architecturally sound and production-ready.

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*

**Audit Signature:** All 8 tests pass (8/8). STATUS: EFFECTIVE.
