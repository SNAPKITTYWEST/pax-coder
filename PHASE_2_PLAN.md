# PAX-Coder Phase 2: ADR-Governed Verification & Authorization

**Status:** In Progress  
**Started:** 2026-08-18  
**Goals:**
1. Refactor verify-clone for ADR-0001 (integrity-only, no authorization logic)
2. Create verify-release for ADR-0002 (explicit authorization boundary)
3. Add test suite (6 tests minimum)
4. Enable CI gate enforcement

---

## Step 1: Refactor verify-clone (ADR-0001)

**Current:** Mixed integrity + authorization logic  
**Target:** Pure integrity verification, non-destructive, repeatable

Changes:
- Remove any authorization checks
- Explicit success/failure only
- All 9 checks pass independently
- No degraded mode on partial verification
- Output stable across runs

**Key invariant:** Run twice, get same result both times

---

## Step 2: Create verify-release (ADR-0002)

**New script:** verify-release  
**Purpose:** Explicit authorization boundary

Design:
- Phase 1: Integrity check (calls verify-clone)
- Phase 2: Authorization check (separate function)
  - Requires server capability OR held secret
  - Returns AUTHORIZATION_REQUIRED if missing
  - Clear error message
  - No fallback execution

**Example output:**
```
INTEGRITY_VERIFIED: Clone is authentic
AUTHORIZATION_REQUIRED: Protected operation requires external capability
  → Contact release authority for authorization token
  → See: docs/adr/0006-server-challenge-protocol.md
```

---

## Step 3: Test Suite

6 tests minimum:
1. test_integrity_verification_independent
2. test_authorization_required_for_protected_ops
3. test_modified_file_detected
4. test_signature_validation
5. test_no_silent_corruption
6. test_private_key_not_distributed

Location: scripts/test_verification.sh

---

## Step 4: CI Enforcement

Add to .github/workflows/adr-validation.yml:
- Run verify-clone on every commit
- Reject if integrity fails
- ADR compliance check

---

## ADR Constraints During Phase 2

From ADR-0007 (Codex Security Preservation):
- ✓ Read applicable ADRs first
- ✓ Pass CI validation
- ✓ Preserve existing artifacts (all 55 files)
- ✓ Document security claims clearly
- ✗ Do not silently ignore violated ADRs
- ✗ Do not delete or rename artifacts
- ✗ Do not implement unspecified security properties

---

## Success Criteria

- [ ] verify-clone output stable (run twice = same result)
- [ ] verify-release has explicit authorization boundary
- [ ] All 6 tests pass
- [ ] No files deleted or weakened
- [ ] ADR constraints maintained
- [ ] CI can enforce ADR violations
- [ ] Documentation updated

---

## Commits

Will create new commits for:
1. verify-clone refactor
2. verify-release implementation
3. test suite
4. CI configuration

Each commit includes verification that ADR constraints are maintained.

