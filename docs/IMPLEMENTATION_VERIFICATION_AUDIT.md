# PAX-Coder Implementation Verification Audit

**Date:** 2026-08-18  
**Status:** CRITICAL GAPS IDENTIFIED  
**Scope:** Verify that implementation matches documented commercial authorization flow

---

## Executive Summary

**Documentation vs. Implementation Mismatch Detected**

The documentation claims:
> PAX-Coder source is publicly cloneable for inspection and verification. Production authorization is separate: contact, approval, applicable commercial terms, and operator-issued Node Key provisioning are required before authorized production deployment.

The implementation has:
- ✅ **Integrity verification** (verify-clone): Real, working, cryptographic (Ed25519, Blake3)
- ✅ **Authorization record structure** (authorization.json): Defined, validated by verify-node-authorization
- ✅ **Node identity generation** (generate_node_key.sh): Creates identity only, does NOT auto-authorize
- ⚠️ **Authorization record creation**: **Placeholder only; no real provisioning mechanism exists**
- ❌ **Authority signature verification**: **NOT IMPLEMENTED** (line 184-191 in pax-coder-gate: "TODO: Wire this to server public key for real verification")
- ❌ **Authority keypair**: **NOT IN REPOSITORY** (correct), but **no external authority mechanism to create signatures**
- ⚠️ **Node authorization binding**: Structure exists, but cannot be provisioned without authority

---

## Detailed Findings

### 1. SELF-GENERATED NODE KEY CANNOT BECOME AUTHORIZED ✅

**Test:** Can a locally-generated node key self-authorize?

**Finding:** YES, the code prevents self-authorization.

**Evidence:**
- `sovereign/generate_node_key.sh` (line 9): "UNAUTHRIZED (not provisioned by PAX-Coder authority)"
- `sovereign/generate_node_key.sh` (line 12-16): Documents that authorization requires "signed authorization capability" from authority
- Script generates identity (node.json, node_pk.pem) but **cannot create authorization.json**

**Status:** ✅ PASS — Self-generation is identity only.

---

### 2. VALID NODE KEY WITHOUT OPERATOR AUTHORIZATION CANNOT AUTHORIZE PRODUCTION ⚠️ PARTIAL

**Test:** Does a node with valid identity but no authorization allow protected operations?

**Finding:** Partially enforced.

**Current state:**
- `scripts/verify-node-authorization` checks authorization.json status (line 76-100)
- Fails on REQUESTED, SUSPENDED, REVOKED, EXPIRED (correct logic)
- But the authorization.json in the repo has:
  - `authorization_status`: "REQUESTED" (not ACTIVE)
  - `revocation_status`: "REVOKED" (explicitly revoked)
  - `authority_signature`: "placeholder_pending_authority_implementation" (NOT A REAL SIGNATURE)

**Problem:**
- There is **NO MECHANISM TO CREATE A REAL authorization.json**
- The one in the repo is a test fixture with status="REQUESTED" and revoked
- No script exists that creates a production-valid authorization.json with:
  - `authorization_status`: "ACTIVE"
  - Real `authority_signature` (not placeholder)
  - Future `expires_at_utc`

**Status:** ⚠️ PARTIAL — Structure exists, enforcement works for test fixture, but no real provisioning mechanism.

---

### 3. EXPIRED/REVOKED AUTHORIZATION FAILS ✅

**Test:** Does the gate deny expired or revoked authorization?

**Finding:** YES, in the test fixture.

**Evidence:**
- `scripts/verify-node-authorization` (line 102-115): Checks revocation_status, denies if REVOKED
- Line 118-127: Checks expiration_time, denies if past expires_at_utc
- `scripts/test_node_authorization.sh`: All tests pass (7/7), including expiration and revocation

**Status:** ✅ PASS — Expiration and revocation checks work correctly.

---

### 4. AUTHORIZATION BOUND TO INTENDED NODE ✅

**Test:** Can authorization.json be used with a different node's keypair?

**Finding:** NO, binding is enforced.

**Evidence:**
- `scripts/verify-node-authorization` (line 130-142): Checks that node_id in authorization.json matches node.json
- Fails if IDs don't match (exit 2)
- Cannot use node B's private key with node A's authorization

**Status:** ✅ PASS — Node binding is verified.

---

### 5. AUTHORIZATION SCOPE IS ENFORCED ⚠️ PLACEHOLDER

**Test:** Are different authorization scopes enforced with different capabilities?

**Finding:** Scope field exists but is NOT enforced in protected operations.

**Evidence:**
- `sovereign/authorization.json` (line 6): Has `"authorization_scope": "protected-execution"`
- `scripts/verify-node-authorization` (line 55): Extracts scope but only logs it
- `scripts/pax-coder-gate` (line 108-135): Does NOT check scope at all
- No capability mechanism validates scope against operation

**Problem:** Scope exists in authorization record but is not enforced anywhere.

**Status:** ⚠️ PARTIAL — Structure exists, enforcement missing.

---

### 6. PRIVATE SIGNING AUTHORITY IS NOT IN REPOSITORY ✅

**Test:** Is the authority's private key exposed?

**Finding:** NO, correctly not in repository.

**Evidence:**
- `sovereign/authorization.json`: Contains only `node_public_key_hex` (public)
- Authority signature is a placeholder string
- No `.authority_sk`, `.auth_private_key`, or similar files in repo
- Authority would be external (not in codebase)

**Status:** ✅ PASS — Authority key correctly kept external.

---

### 7. VERIFIER IS NOT ACCEPTING LOCAL CONFIG AS AUTHORITY ⚠️ PARTIAL

**Test:** Is the verifier trusting locally-provided authorization values?

**Finding:** Yes, partially. The authorization.json is **read from the local repository**.

**Current implementation:**
- `scripts/verify-node-authorization` (line 24): Reads `sovereign/authorization.json` from local filesystem
- Uses that JSON's status field directly (line 54)
- No cryptographic verification of the authority_signature (line 11: placeholder)

**Problem:**
- If an attacker modifies `sovereign/authorization.json` to set `authorization_status: ACTIVE`, the gate would allow it
- The `authority_signature` is not verified (it's just a string check for format in pax-coder-gate line 199)
- Real implementation would need:
  1. Authority's **public key** hardcoded or fetched securely
  2. Ed25519 signature verification of the entire authorization.json
  3. Rejection if signature doesn't match

**Status:** ⚠️ ISSUE — Local file is trusted. Signature verification is TODO.

---

## The Provisioning Flow Gap

**Documented flow:**
```
CONTACT
  ↓
APPROVAL
  ↓
COMMERCIAL AGREEMENT
  ↓
NODE PROVISIONING
  ↓
OPERATOR-SIGNED AUTHORIZATION
  ↓
PROTECTED OPERATION
```

**Actual implementation:**
```
CONTACT
  ↓ (documented in CONTACT.md)
APPROVAL
  ↓ (no code, manual process)
COMMERCIAL AGREEMENT
  ↓ (no code, manual process)
NODE PROVISIONING
  ↓ (no code to create authorization.json)
???
  ↓ (no script to sign authorization.json with authority key)
OPERATOR-SIGNED AUTHORIZATION
  ↓ (would require real Ed25519 signature)
LOCAL authorization.json with ACTIVE + valid signature
  ↓ (current code trusts status field, doesn't verify signature)
PROTECTED OPERATION
```

**Missing:**
1. **Script to create authorization.json** (currently only a test fixture with status="REQUESTED")
2. **Authority key** (would be external, not in repo — correct)
3. **Signing mechanism** to create real Ed25519 signatures over authorization.json
4. **Signature verification in pax-coder-gate** (currently just format check, see line 184-191: "TODO: Wire this to server public key")

---

## What Works ✅

1. **Integrity verification (verify-clone)** — Cryptographically sound
2. **Node identity generation** — Cannot self-authorize
3. **Authorization structure** — Correctly defined
4. **Status validation** — ACTIVE/REQUESTED/SUSPENDED/REVOKED/EXPIRED states work
5. **Expiration checking** — Works correctly
6. **Revocation checking** — Works correctly
7. **Node binding** — Verified against identity
8. **Test suite** — All 7 node authorization tests pass, all 6 gate tests pass
9. **Authority key separation** — Correctly external

---

## What Doesn't Work ❌

1. **Authority signature verification** — Not implemented (TODO in code)
2. **Authorization record provisioning** — No script to create real signed authorizations
3. **Scope enforcement** — Scope field exists but not checked
4. **Authority key integration** — Would need to wire external authority into gate

---

## Implications

### Current State: Theater + Placeholder

The gate currently:
- ✅ Verifies integrity (real)
- ⚠️ Reads authorization status (trusts local JSON, no signature check)
- ⚠️ Accepts capability tokens (format-checks hex, doesn't verify signature)
- ✅ Enforces node binding (real)
- ✅ Checks expiration (real)

**A user could:**
1. Clone the repo
2. Edit `sovereign/authorization.json` to set `authorization_status: "ACTIVE"`
3. The gate would now allow protected operations (because signature is not verified)

**This is NOT a security boundary yet.**

### Why This Matters

The documentation promises:
> operator-issued Node Key provisioning are required before authorized production deployment

The implementation provides:
> A placeholder authorization.json that can be locally modified (no signature verification)

**Gap:** Production authorization is documented but not cryptographically enforced.

---

## To Close the Gap

Three steps required:

### 1. Authority Provisioning Mechanism

Create a script (run by authority, not in repo):
```bash
# authority-sign-authorization.sh (on secure server only, NOT in public repo)
#
# Input:
#   - node_public_key_hex
#   - commercial_agreement_id
#   - tier (Individual/Commercial/Enterprise)
#   - expires_at_utc
#
# Output:
#   - authorization.json with real Ed25519 signature
#   - authority_signature = Ed25519_sign(authority_private_key, blake3(authorization_json))
```

### 2. Authority Public Key Hardcoding

Add to `docs/adr/0010` or pax-coder-gate:
```bash
# Public key of signing authority (Ed25519)
AUTHORITY_PUBLIC_KEY="base64_encoded_authority_public_key_hex"
```

This is safe to hardcode (only verification, not signing).

### 3. Signature Verification in Gate

Replace TODO at line 184-191:
```bash
# Verify capability signature using authority public key
if ! verify_ed25519_signature \
    "$AUTHORITY_PUBLIC_KEY" \
    "$CAPABILITY_JSON" \
    "$CAPABILITY_SIGNATURE"; then
  echo "DENIED: Capability signature invalid (failed verification)"
  exit 2
fi
```

---

## Recommendation

**Do NOT ship this as production authorization yet.**

The documentation is sound, but the implementation has a critical gap:
- Authority signatures are **not verified**
- Local authorization.json file **can be modified without detection**
- This is a placeholder gate, not a real one

**Before shipping:**
1. Create authority-provisioning mechanism (external script)
2. Add authority public key to gate
3. Implement Ed25519 signature verification
4. Re-run all tests with real signed authorizations
5. Document the external authority workflow

Until these steps are done, the gate is:
- ✅ Correct for **integrity verification**
- ⚠️ Incomplete for **production authorization**

---

## Test Outcomes

**Current test suite results:**
```
test_node_authorization.sh     7/7 ✓
test_protection_gate.sh        6/6 ✓
```

**These tests use a placeholder authorization.json.** They verify the *logic* but not the *security*.

**To verify security, would need:**
1. Test with real Ed25519-signed authorization.json
2. Test that locally-modified authorization.json is rejected
3. Test that tampered capability signatures fail
4. Test that authority public key verification works

These tests don't exist yet.

---

**Status:** IMPLEMENTATION COMPLETE FOR STRUCTURE; AUTHORITY VERIFICATION INCOMPLETE  
**Next:** Implement authority key integration and signature verification  
**Date:** 2026-08-18  
**ADR Reference:** ADR-0009 (Protected Execution Capability), ADR-0010 (Public/Authorization Separation)

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*
