# ADR-0004: Private Key Separation

**Status:** Accepted  
**Date:** 2026-08-18  
**Author:** SNAPKITTYWEST PAX-Coder Security Team

---

## Context

The Sovereign Node private key is the most sensitive cryptographic material in the system. It signs official releases, establishes prior-art timestamps, and proves PAX-Coder provenance.

If the private key is distributed to the public clone, assume it can eventually be extracted:
- Reversed from binaries
- Dumped from memory
- Recovered from CUDA/.so/.pyd files
- Extracted from encrypted constants

## Decision

The private Sovereign Node key MUST:

1. **Never be committed to git** — .gitignore enforces this
2. **Never be distributed in releases** — Only public key is published
3. **Never be embedded in binaries** — No compiled constants
4. **Never be in encrypted secrets** — No key-derivation in code
5. **Never be in environment variables** — Except for signing operations in secure environments

The public clone must contain ONLY:

```
node ID
public key (PEM)
public key fingerprint
release signatures
verification metadata
prior-art timestamps
```

The private key is held ONLY by the release signer and protected by access controls.

## Rules

```yaml
rules:
  - private Sovereign Node key MUST NOT be committed to git
  - private key MUST NOT appear in releases
  - private key MUST NOT be distributed in source tarballs
  - private key MUST NOT be embedded in binaries
  - private key MUST NOT be derived from environment configuration
  - private key MUST NOT be recoverable from public cryptographic material
  - .gitignore MUST explicitly block all private-key patterns
  - CI MUST scan for accidentally committed private keys
  - CI MUST reject commits containing private-key patterns
```

## Protected Patterns

CI MUST reject commits matching:

```
-----BEGIN.*PRIVATE
-----END.*PRIVATE
-----BEGIN.*KEY
-----BEGIN.*RSA
-----BEGIN.*EC
-----BEGIN.*OPENSSH
private_key.*=
secret_key.*=
PRIVATE_KEY.*=
AWS_SECRET_ACCESS_KEY
AZURE_CLIENT_SECRET
api_key.*secret
```

## Public Material Only

The clone MUST contain:

```
sovereign/node.json
  ├─ node_id
  ├─ algorithm
  ├─ public_key_hex
  ├─ created_at_utc
  ├─ repository
  ├─ git_commit
  └─ version

sovereign/node_pk.pem
  └─ [Public key in PEM format]

sovereign/release.json
  ├─ node_id
  ├─ node_public_key_hex
  ├─ signature_hex (signed by private key, but signature is public)
  ├─ git_commit
  ├─ release_version
  ├─ manifest_sha256
  └─ timestamp_utc

sovereign/manifest-*.json
  └─ [File hashes and release metadata]
```

MUST NOT contain:

```
.node_sk (private key binary)
node_sk.pem (private key PEM)
Any file with private key material
Any encrypted constants used to recover the key
```

## Key Storage & Management

Release signing happens in a secure environment:

```
Offline Environment
  ├─ private_key.pem
  ├─ git clone
  ├─ sovereign/generate_release.sh
  └─ Sign release
       ├─ Hash manifest
       ├─ Sign hash with private key
       └─ Generate release.json
```

The public release artifact contains:

```
release.json (public)
  ├─ public key
  ├─ signature (hex)
  ├─ manifest hash
  └─ timestamp
```

The private key is NOT transmitted or stored in the public repository.

## Key Rotation

When rotating to a new private key:

1. Generate new Sovereign Node key
2. Create rotation record with old public key signature
3. Document reason and timestamp
4. Do NOT delete old public key (preserve release history)
5. Mark old key as superseded

```yaml
rotation:
  old_node_id: pax-coder-1787047913
  new_node_id: pax-coder-1787048999
  rotation_reason: scheduled rotation
  rotation_timestamp: 2026-12-18T00:00:00Z
  signature_by_old_key: ...
```

## Tests Required

- `test_no_private_keys_in_repo`: Scan for accidentally committed keys
- `test_no_embedded_secrets`: Scan binaries for hardcoded keys
- `test_public_key_only_distribution`: Verify releases contain only public material
- `test_gitignore_coverage`: Verify all private-key patterns are ignored
- `test_ci_rejects_private_keys`: Verify CI blocks key commits

## CI Gate

```bash
#!/bin/bash
# Pre-commit hook
git diff --cached --name-only | xargs -I {} bash -c '
  if grep -l "PRIVATE\|BEGIN.*KEY\|secret_key" {} 2>/dev/null; then
    echo "ERROR: Private key material detected in: {}"
    exit 1
  fi
'
```

## Consequences

- Private key never leaks through version control
- Public clone contains only verifiable public material
- Key rotation does not break release history
- Compromise of one key does not affect other releases
- Private key management is manual and external to the repository

---

**Related ADRs:**
- ADR-0001: Public Clone Integrity
- ADR-0002: Authorization Boundary
- ADR-0006: Server Challenge Protocol
