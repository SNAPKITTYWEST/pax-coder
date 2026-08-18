# Sovereign Node Key — Security & Integrity

This document explains what the Sovereign Node Key system is, what it proves, and how to use it safely.

## Overview

Every PAX-Coder output is signed with a **Sovereign Node Key** — an Ed25519 keypair that cryptographically commits to:

1. The exact git commit that produced the output
2. The repository state at that moment (SHA-256 commitment)
3. A tamper-evident prior-art timestamp
4. The signer's identity (public key)

## What It Proves

### Integrity
✓ The repository has not been tampered with since the key was generated  
✓ Every file's hash is recorded in `manifest.json`  
✓ The manifest itself is committed in `prior_art.json`  

### Timestamp
✓ This code existed at a specific UTC time  
✓ The git commit hash is cryptographically tied to that moment  
✓ No claim is made about what the code does, only when it existed

### Authenticity
✓ Outputs signed with this key were produced by the holder of `.node_sk`  
✓ The public key (`node_pk.pem`) can verify any signature  
✓ No one else can sign with this key (assuming the private key remains private)

### Non-Repudiation
✓ The signer cannot later deny having created the signature  
✓ The signature proves possession of the private key at the time of signing

## What It Does NOT Prove

### Authority
✗ Who actually controls this key?  
✗ Does the key holder have legal authority?  
✗ Is the key holder trustworthy?

**Outside this system.** Authority is established separately (e.g., GitHub organization, legal contracts, institutional review).

### Legal Ownership
✗ Does the signer own the work?  
✗ Can the signer license it?  
✗ Are there copyright claims?

**Not embedded in the crypto.** Use separate legal instruments (licenses, trust deeds, copyright notices).

### Work Quality
✗ Is the code correct?  
✗ Does it do what it claims?  
✗ Is it actually proven?

**Not proven by this system.** Use formal verification, testing, and code review.

### Blockchain Confirmation
✗ Is this anchored to Bitcoin?  
✗ Is the timestamp immutable?  
✗ Can this be reversed?

**Not unless explicitly anchored.** The timestamp is local; see `prior_art.json` status for Bitcoin confirmation status.

## Security Properties

### Confidentiality
- The private key MUST remain private
- If compromised, all signatures are worthless
- Rotate the key immediately if compromise is suspected

### Integrity
- The public key is safe to share
- The manifest and prior-art record must not be modified after commitment
- Verification scripts detect tampering

### Authenticity
- Only the private-key holder can create valid signatures
- The public key proves who signed

### Accountability
- The public key is permanently associated with all outputs
- There is no anonymous signing

## Private Key Management

### Never Do This
✗ Commit `.node_sk` to git  
✗ Upload `.node_sk` to GitHub  
✗ Email or message the private key  
✗ Store in plaintext in cloud storage  
✗ Share the private key with anyone  
✗ Use weak file permissions (must be 400)  
✗ Keep the private key in a public directory  

### Do This Instead
✓ Generate the key with `./generate_node_key.sh`  
✓ File permissions are set to 400 automatically  
✓ Keep in a secure local directory (e.g., `~/.pax-node-keys/`)  
✓ Backup encrypted (e.g., to a YubiKey, hardware wallet, or encrypted USB)  
✓ Rotate periodically (e.g., annually)  
✓ Use environment variables when signing (never hardcode the key)  

Example secure usage:
```bash
export PAX_NODE_KEY=$(cat ~/.pax-node-keys/node_sk | xxd -p | tr -d '\n')
openssl dgst -sha256 -sign ~/.pax-node-keys/node_sk output.ptx
unset PAX_NODE_KEY  # Clear from environment after use
```

## Verification Procedure

### For Your Own Outputs

Verify that all cryptographic artifacts are consistent:
```bash
cd sovereign
./verify_node_key.sh
```

Checks:
- Public files exist and are valid JSON
- Private key has correct permissions (400)
- Git commit is in repository history
- Repository commitment hash is correct
- No private key material leaked to git

### For Someone Else's Outputs

1. **Get the public key**  
   From their `node.json`:
   ```json
   "public_key_hex": "..." 
   ```

2. **Get the prior-art record**  
   From their `prior_art.json`:
   ```json
   {
     "git_commit": "...",
     "repository_sha256": "...",
     "created_at_utc": "..."
   }
   ```

3. **Verify the signature**  
   ```bash
   openssl dgst -sha256 -verify <(echo "PUBLIC_KEY_HEX" | xxd -r -p) \
     -signature output.sig output.ptx
   ```

4. **Check the timestamp**  
   The `created_at_utc` field is when they claimed the key was generated  
   The `git_commit` is the repository state at that time  
   Compare both to independent sources

5. **Spot-check the manifest**  
   Pick a few files from `manifest.json` and verify:
   ```bash
   sha256sum file1 file2 file3  # Should match values in manifest
   ```

## Trust Boundaries

### Trust Assumption: Private Key is Private
If the private key is compromised, all signatures are worthless. The security model collapses.

### Trust Assumption: Public Key is Authentic
If you receive the public key through an insecure channel, you cannot trust the signatures. Use a secure channel (e.g., GitHub, verified fingerprints, institutional databases).

### Trust Assumption: Git History is Honest
The system assumes git commits are immutable. If the repository is force-pushed or the git history is rewritten, the timestamps are no longer reliable.

### Weaker Assumption: Clocks are Roughly Synchronized
Timestamps are local UTC. No assumption is made about perfect clock accuracy; only that times are roughly correct.

## Attack Scenarios

### Scenario 1: Private Key Compromise
**If someone steals the private key:**  
- They can sign fake outputs
- All signatures become untrustworthy
- Immediate rotation is required

**Mitigation:**  
- Keep private key offline when not in use
- Use hardware security modules (YubiKey, etc.)
- Monitor signature usage for anomalies
- Rotate the key if compromise is suspected

### Scenario 2: Repository Tampering
**If git history is rewritten:**  
- Repository commitment hash no longer matches
- `verify_node_key.sh` will detect the mismatch
- The prior-art record is still valid (git commit hash is immutable once broadcast)

**Mitigation:**  
- Repository should use branch protection and signing requirements
- Keep clones as offline backups
- Publish git commits to multiple sources (GitHub, git server, etc.)

### Scenario 3: Timestamp Forgery
**If someone falsifies the timestamp:**  
- The `created_at_utc` field in `node.json` is under their control
- Only verifiable via external sources (blockchain, timestamping service)
- The git commit hash is the real proof (git commits are immutable once broadcast)

**Mitigation:**  
- Anchor the prior-art record to Bitcoin or a timestamping service (see OpenTimestamps)
- The unanchored timestamp is only as trustworthy as the git history
- `status` field in `prior_art.json` indicates confirmation level

### Scenario 4: Man-in-the-Middle Attack
**If someone intercepts the public key:**  
- You cannot trust signatures verified with the intercepted key
- You may be verifying signatures from an attacker, not the real signer

**Mitigation:**  
- Retrieve the public key from an authenticated source (GitHub, institutional database)
- Verify fingerprints over multiple channels
- Use HTTPS with certificate pinning
- Compare public key fingerprints across independent sources

## Rotation

### When to Rotate
- Annually (as part of security hygiene)
- Immediately if compromise is suspected
- When the key holder leaves the organization
- After a security audit recommends rotation

### How to Rotate
1. Generate a new key: `./sovereign/generate_node_key_v2.sh`
2. Create a rotation record that includes:
   - Old node ID
   - New node ID
   - Reason for rotation
   - Timestamp
   - Signature by the old key (proving continuity)
3. Commit new key files + rotation record
4. Keep old private key in secure archive (do not delete)
5. Announce the rotation (e.g., update documentation)

### Rotation Record Example
```json
{
  "old_node_id": "pax-coder-1234567890",
  "new_node_id": "pax-coder-1234567999",
  "old_public_key": "...",
  "new_public_key": "...",
  "rotation_timestamp": "2026-08-18T00:00:00Z",
  "reason": "scheduled annual rotation",
  "signed_by_old_key": "..."
}
```

## Disaster Recovery

### If Private Key is Lost
1. Create a key-loss record (signed by the new key)
2. Rotate to a new key
3. Document the loss (for audit trail)
4. Disable the old key if possible

### If Private Key is Stolen
1. Assume all signatures are compromised
2. Rotate immediately to a new key
3. Verify no unauthorized signatures exist
4. Publish a security notice
5. Update all dependent systems

### If Repository is Corrupted
1. Verify against a known-good clone
2. Check the git commit hash in prior-art records
3. If mismatch, investigate the corruption
4. Restore from backup if necessary

## CI/CD Integration

Add these checks to your CI/CD pipeline:

### Secret Scanning
```yaml
- name: Scan for private key material
  run: |
    if git grep -l "PRIVATE\|BEGIN.*KEY\|-----END" -- sovereign/ \
       | grep -v "\.md\|\.txt"; then
      echo "ERROR: Private key material detected in tracked files"
      exit 1
    fi
```

### Integrity Verification
```yaml
- name: Verify node key integrity
  run: |
    cd sovereign
    bash verify_node_key.sh
```

### Manifest Validation
```yaml
- name: Validate manifest JSON
  run: |
    jq . sovereign/manifest.json sovereign/node.json sovereign/verification.json
```

### Permissions Check
```yaml
- name: Ensure .node_sk is not tracked
  run: |
    if git ls-files | grep "\.node_sk"; then
      echo "ERROR: .node_sk should not be tracked by git"
      exit 1
    fi
```

## Questions & Answers

**Q: Is this blockchain-based?**  
A: No. The timestamps are local. Optional: anchor to Bitcoin via OpenTimestamps for immutability.

**Q: Can I use RSA instead of Ed25519?**  
A: Yes, but Ed25519 is smaller, faster, and more secure. RSA requires larger keys.

**Q: What if multiple people have the same private key?**  
A: Don't share the private key. Generate separate keys for each person; they'll have different node IDs.

**Q: Can I sign outputs retroactively?**  
A: Yes, but the signature will reflect the current date, not the date the code was written.

**Q: What about privacy?**  
A: The node ID and public key are publicly visible. If you want to hide your identity, use a different node identity for different projects.

**Q: Can I revoke a key?**  
A: Yes, through key rotation. Mark the old key as revoked in the rotation record. The old signatures remain valid (you can't revoke history).

## References

- **Ed25519:** [EdDSA signature scheme](https://en.wikipedia.org/wiki/EdDSA)
- **SHA-256:** [NIST FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf)
- **OpenTimestamps:** [Timestamp with Bitcoin](https://opentimestamps.org/)
- **GitHub Security:** [Commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification)

---

**Last updated:** 2026-08-18  
**System version:** 1.0.0  
**License:** BSL-1.1 / AGPL-3.0 / MPL-2.0
