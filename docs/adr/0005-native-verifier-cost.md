# ADR-0005: Native Verifier Cost

**Status:** Accepted  
**Date:** 2026-08-18

---

## Decision

A native verifier (C extension / .so / binary) raises the cost of casual modification.

It is **NOT** cryptographic enforcement and **DOES NOT** prevent determined modification.

Native code increases friction: user must either:
- Recompile the binary
- Modify Python to bypass the native call
- Reverse-engineer the native code

This is a **practical deterrent**, not a security boundary.

## Rules

- Native verifier MUST NOT embed private keys
- Native verifier MUST NOT use obfuscation as cryptographic security
- Native verifier MUST NOT strip symbols as a security measure
- Documentation MUST NOT claim native code is unmodifiable
- Tests MUST verify both Python and native code paths

## Consequences

- Modification is detectable (integrity fails)
- Modification requires more effort (binary modification)
- But modification is still possible (no cryptographic barrier)

---

**Related ADRs:**
- ADR-0001: Public Clone Integrity
- ADR-0002: Authorization Boundary
