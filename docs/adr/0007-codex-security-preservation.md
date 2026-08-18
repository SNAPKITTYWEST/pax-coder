# ADR-0007: Codex Security Preservation Policy

**Status:** Accepted  
**Date:** 2026-08-18

---

## Decision

All modifications to the PAX-Coder security and provenance layer MUST:

1. **Read applicable ADRs first** — Understand architectural constraints
2. **Propose new ADR or update** — If changing security decisions
3. **Pass CI validation** — Commits that violate accepted ADRs are rejected
4. **Preserve existing artifacts** — No deletions without explicit ADR justification
5. **Document security claims clearly** — No unverifiable assertions

## ADR CI Gate

Before accepting security-layer changes, CI validates:

```
✓ ADR syntax (valid YAML)
✓ ADR IDs (no duplicates)
✓ Status transitions (accepted/superseded/etc)
✓ Required fields (context, decision, rules, consequences)
✓ No private keys in commits
✓ No embedded secrets
✓ Prohibited patterns not in code
✓ Verification artifacts present
```

Commits violating ADRs are rejected with:

```
COMMIT REJECTED: Violates ADR-0002 (Authorization Boundary)
Violation: Authorization check is client-side conditional only

See: docs/adr/0002-authorization-boundary.md

To proceed:
1. Update the authorization implementation
2. Create/update ADR explaining the change
3. Resubmit
```

## What Codex Must NOT Do

- Delete existing security artifacts (proofs, kernels, manifests)
- Implement authorization as removable Python conditionals
- Embed private keys in code or binaries
- Use silent corruption for security failures
- Make unverifiable security claims
- Bypass ADR constraints without new ADR

## What Codex Can Do

- Implement new ADRs (with justification)
- Update verification logic (if ADR-compliant)
- Add authorization service integration (following ADR-0006)
- Improve documentation (more precise, not weaker)
- Refactor verification (same boundaries, clearer code)

## Process

```
Proposed Change
    ↓
Does it modify security layer?
    ├─ NO → Standard PR review
    └─ YES → Check ADRs
         ↓
Does it align with accepted ADRs?
    ├─ YES → CI validation
    │    ↓
    │ Pass CI → Approve
    └─ NO → New ADR required
         ↓
    Propose new ADR
         ↓
    ADR-0001/0002/etc conflict resolution
         ↓
    Accept new ADR or modify existing
         ↓
    Re-submit with updated ADR
```

## Codex Authorization

Codex is authorized to:

- Create new ADRs for security features
- Update ADRs to reflect agreed changes
- Reject changes that violate accepted ADRs
- Propose ADR supersessions with justification

Codex is NOT authorized to:

- Silently ignore violated ADRs
- Implement unspecified security properties
- Delete or rename ADRs
- Bypass the ADR process

---

**Related ADRs:**
- All other ADRs in docs/adr/
