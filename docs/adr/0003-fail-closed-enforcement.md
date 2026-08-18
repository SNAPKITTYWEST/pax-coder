# ADR-0003: Fail-Closed Enforcement

**Status:** Accepted  
**Date:** 2026-08-18  
**Author:** SNAPKITTYWEST PAX-Coder Security Team

---

## Context

When integrity verification fails or authorization is unavailable, the system must produce a clear, explicit error state.

The worst failure mode is **silent corruption**: executing with degraded assurance but not informing the user.

## Decision

All security-critical failures must:

1. **Exit with non-zero status** — Prevent accidental progression
2. **Produce clear error messages** — User knows why execution stopped
3. **Preserve uncorrupted state** — No partial writes, no corrupted output
4. **Never silently downgrade** — No "authorization missing so continuing anyway"

## Rules

```yaml
rules:
  - integrity failure MUST exit with status != 0
  - authorization failure MUST exit with status != 0
  - error messages MUST be human-readable and non-corrupted
  - no protected operation MUST proceed without authorization
  - no output MUST be generated when security requirements fail
  - no state MUST be modified when requirements fail
  - error messages MUST NOT contain secrets
  - errors MUST NOT be caught and silently discarded
```

## Error State Format

```
PAX-CODER AUTHORIZATION REQUIRED

Repository Status
  ├─ Integrity:        VERIFIED
  ├─ Release Version:   1.0.0
  ├─ Git Commit:        f58c9d02...
  └─ Node ID:           pax-coder-...

Authorization Status
  ├─ Authorization:     NOT GRANTED
  ├─ Service:           Available at [URL]
  └─ Action Required:   Authenticate to continue

Protected Capability
  ├─ Operation:         Proof kernel access
  ├─ Status:            UNAVAILABLE (authorization required)
  └─ To Proceed:        ./scripts/authenticate

Exit Code: 1
```

## Integrity Failure Format

```
PAX-CODER INTEGRITY VERIFICATION FAILED

Release Verification
  ├─ Repository:        SNAPKITTYWEST/pax-coder
  ├─ Release Version:    1.0.0
  └─ Expected Commit:    f58c9d02...

Verification Result
  ├─ Git Commit:         MISMATCH
  │  ├─ Expected:        f58c9d02...
  │  └─ Actual:          xxxxxxxx...
  └─ Status:             FAILED

This clone does not match the official release.

To recover:
  git clone https://github.com/SNAPKITTYWEST/pax-coder.git clean
  cd clean
  ./scripts/verify-release

Exit Code: 1
```

## Implementation

```python
# Pseudo-code
def verify_release():
    try:
        integrity = check_integrity()
        if not integrity.valid:
            print_integrity_error(integrity)
            sys.exit(1)
        
        authorization = check_authorization()
        if not authorization.valid:
            print_authorization_error(authorization)
            sys.exit(1)
        
        execute_protected_operation()
    except Exception as e:
        print_unexpected_error(e)
        sys.exit(1)

def print_integrity_error(result):
    """Print clear integrity failure, never corrupted output"""
    print("PAX-CODER INTEGRITY VERIFICATION FAILED\n")
    for check, status in result.checks.items():
        print(f"  [{status}] {check}")
    print("\nExit Code: 1")

def print_authorization_error(result):
    """Print clear authorization failure, never corrupted output"""
    print("PAX-CODER AUTHORIZATION REQUIRED\n")
    print(f"  Status: {result.status}")
    print(f"  Reason: {result.reason}")
    print(f"  To proceed: {result.action}\n")
    print("Exit Code: 1")
```

## Tests Required

- `test_integrity_failure_exits_nonzero`: Check exit code == 1
- `test_authorization_failure_exits_nonzero`: Check exit code == 1
- `test_no_corrupted_output`: Verify no garbage output on failure
- `test_no_partial_writes`: Verify no partial state on failure
- `test_error_message_clarity`: Verify user can understand error
- `test_no_silent_continuation`: Verify no degraded-mode execution

## Consequences

- All security failures are explicit and visible
- Users cannot accidentally use compromised releases
- No mysterious crashes or partial outputs
- CI must validate that all failure paths exit nonzero
- Documentation must list all possible failure states

---

**Related ADRs:**
- ADR-0001: Public Clone Integrity
- ADR-0002: Authorization Boundary
