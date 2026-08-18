# Sovereign Node Key System

This directory contains the cryptographic authorization infrastructure for PAX-Coder.

## What This Is

The Sovereign Node Key system provides:

1. **Ed25519 Node Authorization** — cryptographic identity with authorization for protected operations
2. **Node Authorization Record** — external authority-signed proof that this node is authorized
3. **Repository Commitment** — SHA-256 hash of the repository state at key generation time
4. **Prior-Art Timestamp** — tamper-evident record that this work existed at a particular git commit
5. **Authorization Verification** — tools to verify node authorization status
6. **Verification Scripts** — tools to independently verify integrity and authorization

## How to Use

### Step 1: Generate a New Node

```bash
cd pax-coder/sovereign
./generate_node_key.sh
```

This creates:
- `node.json` — Public identity manifest
- `node_pk.pem` — Public key (PEM format)
- `manifest.json` — Repository file list with hashes
- `prior_art.json` — Prior-art timestamp record
- `verification.json` — Cryptographic verification record
- `.node_sk` — **PRIVATE KEY** (never committed, permissions 400)

### Step 2: Request Authorization

Contact PAX-Coder at:
- Email: pax-coder@snapkittywest.com
- Form: https://snapkittywest.com/pax-coder/request

Provide your `node.json` (public identity only). Do NOT share `.node_sk`.

### Step 3: Receive Authorization Record

After approval and provisioning, you receive:
- `authorization.json` — Authority-signed authorization record for your node

The authorization record contains:
- Your node ID and public key
- Authorization status (ACTIVE, REQUESTED, SUSPENDED, REVOKED, EXPIRED)
- Authorization scope (what operations you can perform)
- Issue/expiration dates
- Authority signature

### Step 4: Verify Authorization

```bash
./verify_node_key.sh     # Verify node identity integrity
../scripts/verify-node-authorization  # Verify authorization status
```

### Verify Existing Authorization

```bash
./verify_node_key.sh     # Verify node key integrity
../scripts/verify-node-authorization  # Verify authorization status
```

Checks (node key):
- All public files are present and valid JSON
- Private key has correct permissions
- Git commit exists in repository
- Repository commitment hash is correct

Checks (authorization):
- Authorization record exists
- Authorization status is ACTIVE
- Authorization has not expired
- Node ID matches
- Revocation status is not REVOKED

## Security Model

### What This Proves

✓ **Node Identity** — Cryptographic identity of the node (Ed25519 public key)
✓ **Node Authorization** — External authority has approved this node for protected operations
✓ **Authorization Status** — Node is ACTIVE, REQUESTED, SUSPENDED, REVOKED, or EXPIRED
✓ **Authorization Scope** — What protected operations this node is authorized to perform
✓ **Integrity** — Repository state at a specific git commit  
✓ **Timestamp** — Work existed no later than this UTC time  
✓ **Authenticity** — Outputs are signed with a specific Ed25519 key  
✓ **Non-repudiation** — Holder of the private key can sign artifacts

### What This Does NOT Prove

✗ **Alone without authorization record** — Node identity alone does not prove authority
✗ **Legal ownership** — No embedded legal claims  
✗ **Blockchain confirmation** — Timestamp is local only (unconfirmed)  
✗ **Work quality** — Only proves authorization and existence, not correctness or usefulness

### Public vs. Private

**Never commit to git:**
- `.node_sk` (private key file)
- Any file containing the private key material
- Passwords or passphrases

**Safe to commit:**
- `node.json` (public identity)
- `node_pk.pem` (public key)
- `manifest.json` (repository fingerprint)
- `prior_art.json` (prior-art record)
- `verification.json` (cryptographic metadata)

## Files

### node.json

Public identity manifest. Contains:
- `node_id` — Unique identifier
- `algorithm` — "Ed25519"
- `public_key_hex` — Public key in hex format
- `created_at_utc` — ISO 8601 timestamp
- `repository` — GitHub repo path
- `git_commit` — Commit hash at generation time
- `version` — System version

### manifest.json

Repository state snapshot. Contains:
- `files` — Object mapping each tracked file to its SHA-256 hash
- `generated_at_utc` — When manifest was created
- `git_commit` — Which commit this reflects

### prior_art.json

Prior-art timestamp record. Contains:
- `artifact` — "PAX-Coder"
- `repository` — GitHub path
- `git_commit` — Commit hash
- `repository_sha256` — Hash of the manifest
- `node_id` — Node that signed it
- `created_at_utc` — UTC timestamp
- `status` — "UNCONFIRMED" (or "BITCOIN-CONFIRMED" if anchored)

### verification.json

Cryptographic record. Contains:
- `node_id` — Node identifier
- `algorithm` — "Ed25519"
- `repository_commitment_algorithm` — "SHA-256"
- `repository_commitment` — The actual commitment hash
- `git_commit` — Which commit
- `manifest_file` — Path to manifest
- `verification_timestamp` — When verified

### .node_sk

**PRIVATE KEY FILE** — Never commit, share, or upload.

File permissions: 400 (owner read-only)

Stored locally for signing operations:
```bash
export PAX_NODE_KEY=$(cat sovereign/.node_sk | xxd -p | tr -d '\n')
```

## Workflow

### 1. Generate Key (Once)

```bash
./generate_node_key.sh
```

Outputs all files. Private key is generated once and kept secure.

### 2. Commit Public Files

```bash
git add sovereign/node.json sovereign/manifest.json sovereign/prior_art.json sovereign/verification.json
git commit -m "Add Sovereign Node Key public identity"
```

**DO NOT** commit `.node_sk`.

### 3. Verify (Any time)

```bash
./verify_node_key.sh
```

Confirms all artifacts are consistent.

### 4. Sign Outputs

Use the private key (externally or via environment):
```bash
openssl dgst -sha256 -sign sovereign/.node_sk -out output.sig output.ptx
```

Verify with public key:
```bash
openssl dgst -sha256 -verify <(openssl pkey -in sovereign/node_pk.pem -pubin -outform DER) -signature output.sig output.ptx
```

## Key Rotation

To rotate to a new key:

1. Generate new key in a new subdirectory (e.g., `sovereign/v2/`)
2. Record the old public key in a rotation record
3. Sign the rotation record with the old key
4. Commit new key and rotation record
5. Keep old private key in secure archive (not in git)

Example rotation record:
```json
{
  "old_node_id": "pax-coder-1234567890",
  "new_node_id": "pax-coder-1234567999",
  "rotation_reason": "scheduled rotation",
  "rotation_timestamp": "2026-08-18T00:00:00Z",
  "signature_by_old_key": "..."
}
```

## Verification for Others

To verify this artifact (without the private key):

1. Clone the repository
2. Run `./sovereign/verify_node_key.sh`
3. Check that all files are present and valid
4. Compare the git commit hash with the timestamp
5. Verify the repository commitment by spot-checking a few files:
   ```bash
   sha256sum sovereign/node.json  # Should match value in manifest.json
   ```
6. Confirm the node's public key (from `node.json`) against any signatures

## CI/CD Integration

Add to `.github/workflows/security.yml`:

```yaml
- name: Check for private key material
  run: |
    if grep -r "BEGIN.*PRIVATE\|-----END.*PRIVATE" sovereign/ --include="*.json"; then
      echo "ERROR: Private key material in public files"
      exit 1
    fi

- name: Verify node key integrity
  run: |
    cd sovereign
    bash verify_node_key.sh
```

## Questions?

- **What does this prove?** See "Security Model" section above.
- **Is this blockchain-based?** No, it's local + optional Bitcoin anchoring. See `prior_art.json` status.
- **Can I use a different algorithm?** Yes, but Ed25519 is recommended. Update `algorithm` field in `node.json`.
- **What if I lose the private key?** Key rotation required; new public identity generated; old key recorded.
- **Can I backup the private key?** Yes, but store encrypted in a secure vault outside git.

---

**Generated by:** PAX-Coder Sovereign Node Key System  
**License:** Same as PAX-Coder (BSL-1.1 / AGPL-3.0 / MPL-2.0)
