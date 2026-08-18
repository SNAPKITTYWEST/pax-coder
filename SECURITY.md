# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in PAX-Coder, please **do not** open a public GitHub issue. Instead:

1. Email `jessica@collectivekitty.com` with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Your contact information

2. Subject line: `[SECURITY] PAX-Coder vulnerability report`

We will:
- Acknowledge receipt within 48 hours
- Investigate the issue
- Develop a fix
- Release a patch
- Credit you in release notes (if desired)

## Security Model

### Sovereign Node Key — Production Authorization

All production-authorized PAX-Coder operations are signed with a provisioned Sovereign Node Key (Ed25519 keypair). See [SOVEREIGN_NODE.md](SOVEREIGN_NODE.md) for full details.

**What it proves:**
- **Node Authorization** — The PAX-Coder authority has provisioned and authorized this node
- **Integrity** — Repository state at a specific git commit
- **Prior-art timestamp** — Code existed at time X
- **Authenticity** — Signer has the private key for this node
- **Non-repudiation** — Signer cannot deny signing

**What it does NOT prove (without authorization record):**
- **Node authorization alone** — Node identity without operator signature does not grant authorization
- **Legal ownership** — No embedded legal claims
- **Code quality** — Only proves authorization and existence, not correctness
- **Blockchain confirmation** — Unless explicitly anchored to Bitcoin

### Private Key Protection

The Sovereign Node Key private material MUST:
- Never be committed to git
- Never be uploaded to GitHub
- Never be emailed or messaged
- Never be stored in plaintext in cloud storage
- Never be shared with anyone
- Have file permissions 400 (owner read-only)

**If compromised:**
1. All signatures become untrustworthy
2. Rotate immediately to a new key
3. Publish a security notice
4. Mark old key as revoked (see `sovereign/README.md`)

### Git Security

**Best practices:**
- Enable branch protection on master
- Require pull request reviews before merge
- Require signed commits
- Use GitHub's secret scanning
- Monitor for suspicious commits
- Keep a backup clone (to detect force-push attacks)

**Verification:**
```bash
# Verify commit signature
git log --pretty=format:"%H %s" | head -1
git verify-commit COMMIT_HASH

# Check for unsigned commits
git log --oneline --all | while read commit; do
  git verify-commit $(echo $commit | awk '{print $1}') || echo "UNSIGNED: $commit"
done
```

### Dependency Security

PAX-Coder depends on:
- `openssl` (key generation, signing)
- `jq` (JSON validation)
- Python standard library (scripts)
- Lean 4 toolchain (proof verification)

All dependencies are mature, well-audited projects. Upgrade regularly:

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Audit Python dependencies
pip install --upgrade pip
pip audit

# Audit Lean packages
lake update
```

### Code Review

Before deploying PAX-Coder:

1. **Review proof obligations** in `PAX/` Lean modules
   - Every theorem should be closed (no `sorry`)
   - Use `lake build` to verify

2. **Review kernel code** in `src/`
   - Check for race conditions
   - Verify memory access patterns
   - Compare against Futhark spec

3. **Review training pipeline** in `train.py`, `export_training_data.py`
   - Verify data sources
   - Check loss functions
   - Validate evaluation metrics

4. **Automated checks** (CI/CD):
   - Secret scanning
   - Linting
   - Type checking
   - Proof verification

### Hardware Security

**RTX 3080 (primary target):**
- NVIDIA's NVIDIA-SMI provides basic driver verification
- Check for firmware updates via NVIDIA's tools
- Monitor GPU memory errors via `nvidia-smi -q -d MEMORY`

**Deployment:**
- Use secure boot where available
- Disable unnecessary firmware/drivers
- Monitor for unauthorized access
- Keep PCIe lanes isolated when sensitive

## Compliance

### Cryptography

PAX-Coder uses:
- **Ed25519** (EDDSA, RFC 8032) for signatures
- **SHA-256** (NIST FIPS 180-4) for hashing
- **OpenSSL** (FIPS-capable, audited)

Both are NIST-approved for federal use.

### Licensing

PAX-Coder is released under a tri-license:
- **BSL-1.1** (Business Source License) — commercial
- **AGPL-3.0** — copyleft
- **MPL-2.0** — permissive

See `LICENSE.tri` for full terms.

### Data Protection

PAX-Coder does not:
- Collect telemetry
- Phone home
- Store user data
- Require API keys
- Contact external services by default

All computation is local.

## Testing & Validation

### Proof Validation

Verify all proofs compile:
```bash
cd PAX
lake build
lake test
```

Expected output:
```
All tests passed ✓
0 sorry terms
```

### Kernel Verification

Test kernel correctness:
```bash
python -m pytest tests/ -v
```

Tests verify:
- Mathematical correctness (vs Futhark spec)
- Memory safety (bounds checking)
- Pipeline correctness (stages execute correctly)
- FP16 rounding (within 0.5 ulp)

### Integration Tests

```bash
python test_end_to_end.py
```

Verifies:
- Proof → CUDA compilation
- CUDA → RTX 3080 execution
- Execution matches specification
- Proof remains valid after compilation

## Incident Response

### If a vulnerability is discovered:

1. **Acknowledge** (within 48 hours)
2. **Investigate** (reproduce, assess impact)
3. **Develop fix** (write and test patch)
4. **Release** (publish security patch)
5. **Communicate** (update documentation, credit researcher)

### Vulnerability timeline:

- **Days 0-2:** Acknowledge, triage
- **Days 3-7:** Fix development
- **Days 8-10:** Security review
- **Day 11:** Patch release
- **Day 12:** Public disclosure (responsible disclosure)

## Post-Quantum Cryptography

**Current state:** Ed25519 is NOT post-quantum secure.

**When PQC is standardized:** 
- We will upgrade to NIST-standardized post-quantum signatures
- ED448 (128-bit post-quantum security) is a candidate
- Migration path will be announced

**Until then:**
- Ed25519 remains the strongest practical choice
- All outputs should be assumed quantum-vulnerable long-term
- Critical long-lived artifacts should be re-signed post-quantum migration

## References

- [NIST Cryptographic Algorithm Validation Program](https://csrc.nist.gov/projects/cryptographic-algorithm-validation-program/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [OpenSSL Best Practices](https://wiki.openssl.org/index.php/Frequently_Asked_Questions)
- [Ed25519 RFC 8032](https://tools.ietf.org/html/rfc8032)

## License

This security policy is part of PAX-Coder and is licensed under the same tri-license (BSL-1.1 / AGPL-3.0 / MPL-2.0).

---

**Last updated:** 2026-08-18  
**Version:** 1.0.0  
**Maintainer:** SNAPKITTYWEST
