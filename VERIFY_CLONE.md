# Verify Your PAX-Coder Clone

This document explains how to verify that your clone of PAX-Coder matches an official release.

## Why Verification Matters

When you clone PAX-Coder from GitHub, you receive files over the network. An official PAX-Coder release is cryptographically signed with a Sovereign Node Key. This verification system lets you confirm:

✓ **Integrity** — Files have not been modified  
✓ **Authenticity** — This is an official release from SNAPKITTYWEST  
✓ **Timestamp** — The release existed at a specific point in time  
✓ **Commitment** — Every tracked file matches the official manifest  

## Quick Start

After cloning:

```bash
git clone https://github.com/SNAPKITTYWEST/pax-coder.git
cd pax-coder

./scripts/verify-clone
```

If verification passes, you'll see:

```
========================================
STATUS: AUTHENTIC PAX-CODER RELEASE
========================================
```

If verification fails, you'll see:

```
========================================
STATUS: VERIFICATION FAILED
========================================
```

**Do NOT use a release that fails verification.**

## What Verification Checks

The `verify-clone` script performs a hard gate with 9 critical checks:

### [1] Release Metadata
Checks that `sovereign/release.json` exists and is valid.

### [2] Git Commit
Verifies your clone is at the exact git commit specified in the release.

```bash
git rev-parse HEAD
# Should match: "git_commit" in sovereign/release.json
```

### [3] Release Version
Checks that `VERSION` file matches the release version.

### [4] Canonical Manifest
Reads the official file manifest for this release.

### [5] File Integrity
Verifies every tracked file's SHA-256 hash against the manifest.

If any file is modified, verification fails.

### [6] Manifest Commitment
Computes the SHA-256 of the entire manifest.

Must match the value in `sovereign/release.json`.

### [7] Node Key Fingerprint
Verifies the public Ed25519 key matches the release.

### [8] Release Signature
Verifies the Ed25519 signature on the manifest.

Uses the public key from the release to check authenticity.

### [9] Prior-Art Timestamp
Checks that a prior-art record exists with a UTC timestamp.

## Understanding the Results

### PASS

All 9 checks passed. The clone is authentic and unmodified.

You can safely use PAX-Coder's proofs, kernels, and specifications.

### FAIL

One or more checks failed. Possible reasons:

- **Commit mismatch** — Your clone is not at the official release commit
- **Files modified** — Someone or something has modified tracked files
- **Files missing** — Expected files are not present
- **Signature invalid** — The release signature does not verify
- **Manifest corrupted** — The release manifest is invalid JSON

**Do not trust a clone that fails verification.**

#### Common Failure Scenarios

**"Commit mismatch"**
- Your clone is on a different branch
- Your clone is ahead of the release
- Someone force-pushed to the repository

**Solution:** Clone fresh from the official repository.

**"Files modified"**
- You edited tracked files
- A tool or script modified files
- Network corruption during clone

**Solution:** Re-clone or restore files from git.

**"Signature invalid"**
- The release was tampered with
- You're using an unofficial clone
- The public key is incorrect

**Solution:** Clone from the official GitHub repository only.

## Manual Verification

If you want to verify manually instead of using the script:

### 1. Get the Release Information

```bash
cat sovereign/release.json | jq .
```

You'll see:
- `repository` — SNAPKITTYWEST/pax-coder
- `release_version` — e.g., 1.0.0
- `git_commit` — The exact commit hash
- `manifest_sha256` — The file manifest hash
- `node_id` — The signer's node identity
- `node_public_key_hex` — The Ed25519 public key
- `signature_hex` — The signature (hex-encoded)

### 2. Verify the Git Commit

```bash
git rev-parse HEAD
# Compare with release.json: git_commit
```

### 3. Verify File Integrity

```bash
# For each file in sovereign/manifest-VERSION.json:
sha256sum PATH/TO/FILE
# Compare with the value in the manifest
```

### 4. Verify the Manifest Commitment

```bash
sha256sum sovereign/manifest-1.0.0.json
# Compare with release.json: manifest_sha256
```

### 5. Verify the Signature

Extract the public key and convert to PEM:

```bash
# Get public key hex from sovereign/release.json
PUB_KEY_HEX="..."
echo "$PUB_KEY_HEX" | xxd -r -p > /tmp/pk.der

# Get signature hex and convert to binary
SIGNATURE_HEX="..."
echo "$SIGNATURE_HEX" | xxd -r -p > /tmp/sig.bin

# Verify
openssl dgst -sha256 -verify <(openssl pkey -inform DER -pubin -in /tmp/pk.der) \
  -signature /tmp/sig.bin sovereign/manifest-1.0.0.json
```

If the signature is valid:

```
Verified OK
```

## How Releases Are Created

Official PAX-Coder releases are created with:

```bash
cd sovereign
./generate_release.sh 1.0.0
```

This creates:

- `release.json` — Public release metadata + signature
- `manifest-1.0.0.json` — File manifest

Both files are committed to git and published on the GitHub release page.

The **private key is never published** and never appears in the clone.

## What Verification Does NOT Prove

**Important:** Verification proves integrity and authenticity, but:

✗ **Does NOT prove legality** — The code is still under the tri-license (BSL-1.1 / AGPL-3.0 / MPL-2.0)  
✗ **Does NOT prove correctness** — Verified code could still have bugs  
✗ **Does NOT prove safety** — Always review untrusted code  
✗ **Does NOT prove Bitcoin confirmation** — Unless explicitly stated  

See [SOVEREIGN_NODE.md](SOVEREIGN_NODE.md) for the complete security model.

## If Verification Fails

### Step 1: Check Your Git State

```bash
git status
git log --oneline -5
```

If you've made local changes, the clone is no longer official.

### Step 2: Re-Clone

```bash
cd /tmp
git clone https://github.com/SNAPKITTYWEST/pax-coder.git pax-clean
cd pax-clean
./scripts/verify-clone
```

If the fresh clone verifies, your original clone was modified.

### Step 3: Report a Security Issue

If a fresh clone from the official repository still fails verification:

**Email:** jessica@collectivekitty.com  
**Subject:** `[SECURITY] PAX-Coder Clone Verification Failed`  
**Include:**
- Output of `./scripts/verify-clone`
- Your git version
- Your OS and platform
- Steps you took

## FAQ

**Q: Is this blockchain-based?**  
A: No. Verification uses cryptographic signatures. Optional: Bitcoin anchoring via OpenTimestamps.

**Q: What if the GitHub repository is hacked?**  
A: If the release files are modified on GitHub, verification will fail. Clone from a backup source.

**Q: Can I verify without running a script?**  
A: Yes. Manual verification is documented in "Manual Verification" section above.

**Q: What if I don't have `openssl`?**  
A: The verification script requires: `bash`, `git`, `jq`, `openssl`, `sha256sum`. These are standard on Linux/macOS.

**Q: Should I trust verification if it passes?**  
A: Verification proves this is an authentic, unmodified PAX-Coder release. Still review the code before use—verification is not a code review.

**Q: Can I modify the code after verification?**  
A: Yes. Verification confirms the initial state. You can modify files locally. Re-verification will fail (as expected).

---

**For more details:**
- [SOVEREIGN_NODE.md](SOVEREIGN_NODE.md) — Security model and what's proved
- [SECURITY.md](SECURITY.md) — Incident response and key management
- [sovereign/README.md](sovereign/README.md) — Full Sovereign Node Key system guide

---

**Last updated:** 2026-08-18  
**Status:** Production release verification system  
**License:** BSL-1.1 / AGPL-3.0 / MPL-2.0
