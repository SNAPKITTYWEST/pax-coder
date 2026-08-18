# Authority Key Deployment Guide

**Purpose:** Instructions for authority operators to sign capabilities and provision nodes.

**Audience:** PAX-Coder Authority Operator (not public)

---

## 1. Authority Setup (One-Time)

### 1.1 Generate Authority Keypair

**Location:** Authority server (secure environment)

```bash
cd pax-coder
bash sovereign/generate_authority_key.sh
```

**Output:**
- `sovereign/authority_sk.pem` — Private key (KEEP SECURE)
- `sovereign/authority_pk.pem` — Public key (distribute to nodes)

**Security:**
```bash
# Verify file permissions
ls -la sovereign/authority_sk.pem  # Should be 600
ls -la sovereign/authority_pk.pem  # Should be 644
```

### 1.2 Distribute Authority Public Key

**File:** `sovereign/authority_pk.pem`

Distribute to all nodes that will verify authorizations:

```bash
# Copy to known location on all nodes
cp sovereign/authority_pk.pem /etc/authority/pax-coder-authority-pk.pem
```

Or bake into deployment image:
```bash
# In Docker image or VM template
COPY sovereign/authority_pk.pem /etc/authority/pax-coder-authority-pk.pem
```

**Do NOT commit authority_pk.pem to public repositories.**

---

## 2. Create Authorization Records

### 2.1 Authorization Request Flow

```
Developer/Customer
    ↓ (Request)
Authority Operator
    ↓ (Review)
Authorization Database
    ↓ (Create)
authorization.json template
    ↓ (Sign)
Signed Capability
    ↓ (Deliver)
Developer/Customer
```

### 2.2 Create Capability Record

**Filename:** `capability_NODE_ID.json`

```json
{
  "node_id": "pax-coder-prod-12345",
  "release_id": "1.0.0",
  "commit": "abc123def456789abc123def456789abc123def4",
  "nonce": "nonce-2026-08-18-unique",
  "expires_at": "2026-12-31T23:59:59Z"
}
```

**Fields:**

| Field | Purpose | Example |
|-------|---------|---------|
| `node_id` | Unique node identifier | `pax-coder-prod-12345` |
| `release_id` | Allowed release version | `1.0.0` |
| `commit` | Exact git commit hash | `abc123...` |
| `nonce` | One-time use identifier | Date + random |
| `expires_at` | Expiration time (UTC) | ISO 8601 |

### 2.3 Sign Capability

**Command:**

```bash
bash sovereign/sign_capability.sh capability_NODE_ID.json
```

**Output:**

```
{"commit":"abc123...","expires_at":"2026-12-31T23:59:59Z",...}|b640c7a4f0af55c7abba64c8e444d39b0bd44431aabffeb814cd519b87e6352aaf0c63cbcb94bad1ae23ac52f1288dea7c0aa815158f76221cee56da9aad520a
```

Format: `CANONICAL_JSON|SIGNATURE_HEX`

**Signature:** 128 hex characters (64 bytes Ed25519)

### 2.4 Deliver to Node

**Send via secure channel:**

```bash
# Option 1: Email or secure message
PAX_CAPABILITY_TOKEN="$(bash sovereign/sign_capability.sh capability_NODE_ID.json)"
echo $PAX_CAPABILITY_TOKEN > /tmp/capability.txt
# Send /tmp/capability.txt to node operator (encrypted)

# Option 2: API endpoint
curl -X POST https://authority.example.com/provision \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "node_id": "pax-coder-prod-12345",
    "capability": "'$PAX_CAPABILITY_TOKEN'"
  }'

# Option 3: Kubernetes secret
kubectl create secret generic pax-capability-prod-12345 \
  --from-literal=token="$PAX_CAPABILITY_TOKEN"
```

---

## 3. Node Installation

### 3.1 Deploy Authority Public Key

**Automated (Terraform):**

```hcl
resource "local_file" "authority_pk" {
  content  = file("${path.module}/sovereign/authority_pk.pem")
  filename = "/etc/authority/pax-coder-authority-pk.pem"
}
```

**Manual:**

```bash
mkdir -p /etc/authority
cp authority_pk.pem /etc/authority/pax-coder-authority-pk.pem
chmod 644 /etc/authority/pax-coder-authority-pk.pem
```

### 3.2 Set Capability Token

**Environment Variable:**

```bash
export PAX_CAPABILITY_TOKEN="$(cat /path/to/capability.txt)"
```

**File:**

```bash
mkdir -p pax-coder/sovereign
echo "$PAX_CAPABILITY_TOKEN" > pax-coder/sovereign/.capability
chmod 600 pax-coder/sovereign/.capability
```

**Kubernetes Secret:**

```bash
kubectl create secret generic pax-capability \
  --from-file=capability=/path/to/capability.txt \
  -n pax-system

# Mount in pod
volumeMounts:
  - name: pax-capability
    mountPath: /opt/pax/sovereign/.capability
    subPath: capability
volumes:
  - name: pax-capability
    secret:
      secretName: pax-capability
```

### 3.3 Verify Setup

**Test gate:**

```bash
cd pax-coder
bash scripts/pax-coder-gate
```

**Expected output:**

```
PAX-CODER PROTECTED EXECUTION GATE
[1/5] Verifying release integrity...
✓ Release integrity verified
[2/5] Verifying node authorization status...
✓ Node authorization verified
[3/5] Checking for capability...
✓ Capability token found
[4/5] Parsing capability...
✓ Capability parsed
[5/5] Validating capability...
✓ Commit matches
✓ Capability not expired
✓ Node ID matches
[6/6] Verifying capability signature...
✓ Signature verified (cryptographic validation)

STATUS: AUTHORIZATION_GRANTED
Node pax-coder-prod-12345 is authorized for:
  Scope: protected-execution
```

---

## 4. Authority Operations

### 4.1 Rotate Authority Keys

**When:** Compromise suspected, key expires, policy change

**Steps:**

1. Generate new authority keypair:
   ```bash
   bash sovereign/generate_authority_key.sh
   ```

2. Distribute new authority_pk.pem to all nodes

3. Continue signing with new authority_sk.pem

4. Mark old capabilities as REVOKED (if managed in database)

**Old capabilities:** Will fail verification once authority_pk.pem is updated

### 4.2 Revoke Capability

**Option 1: Expiration (Automatic)**

Capabilities expire at `expires_at` timestamp.

**Option 2: Revocation (Operational)**

If compromise or revocation needed before expiration:

1. Update authorization database
2. Add to revocation list
3. Gate checks against revocation list (if implemented)

Current gate does not check revocation list; implement if needed.

### 4.3 Audit Trail

**Maintain log:**

```
Date          | Node ID          | Action    | Signature
2026-08-18    | pax-coder-12345  | PROVISION | b640c7a4...
2026-08-20    | pax-coder-12345  | REVOKE    | (reason: compromise)
2026-08-21    | pax-coder-12346  | PROVISION | f8a6008c...
```

---

## 5. Security Best Practices

### 5.1 Private Key Protection

```bash
# Generate on secure server, NEVER transfer
authority_sk.pem → KEEP ONLY ON AUTHORITY SERVER

# Backup encrypted
openssl enc -aes-256-cbc -in authority_sk.pem -out authority_sk.pem.enc

# Verify file permissions
ls -la sovereign/authority_sk.pem  # Must be 600
stat -c "%a" sovereign/authority_sk.pem  # Should print 600
```

### 5.2 Public Key Distribution

```bash
# Safe to distribute, verify integrity:
# Use signed manifest or checksum

sha256sum sovereign/authority_pk.pem > authority_pk.sha256
gpg --sign authority_pk.sha256  # Sign with operator key

# Nodes verify before deployment:
gpg --verify authority_pk.sha256.gpg
sha256sum -c authority_pk.sha256
```

### 5.3 Secure Channels

- Use TLS for capability delivery
- Sign capabilities with operator signature (GPG)
- Encrypt in transit
- Audit who can provision

### 5.4 Monitoring

```bash
# Log all capability issuances:
bash sovereign/sign_capability.sh capability_$NODE.json 2>&1 | \
  tee -a /var/log/pax-authority.log

# Alert on failures:
# - Failed signature operations
# - Missing authority_sk
# - Unauthorized sign requests
```

---

## 6. Troubleshooting

### Issue: "Authority public key not found"

**Solution:** Deploy authority_pk.pem to node:

```bash
mkdir -p /etc/authority
cp sovereign/authority_pk.pem /etc/authority/pax-coder-authority-pk.pem
```

### Issue: "Signature verification failed"

**Possible causes:**
1. Wrong authority_pk.pem (mismatched keypair)
2. Capability modified after signing
3. Gate using node_pk.pem instead of authority_pk.pem

**Verify:**
```bash
# Check gate is using correct key:
grep "AUTHORITY_PUBLIC_KEY_FILE" scripts/pax-coder-gate
# Should show: authority_pk.pem (not node_pk.pem)

# Test capability locally:
bash sovereign/sign_capability.sh test_cap.json
# Output should be: JSON|SIGNATURE_HEX
```

### Issue: "Node ID mismatch"

**Cause:** Capability for wrong node

**Solution:** Create new capability with correct node_id:
```bash
# Verify local node ID:
cat sovereign/node.json | grep node_id

# Create capability with matching node_id:
cat > capability_$NODE_ID.json << EOF
{
  "node_id": "$(cat sovereign/node.json | grep -o '"node_id":"[^"]*"' | cut -d'"' -f4)",
  ...
}
EOF
```

---

## 7. Testing

### 7.1 Test Authority Signatures

```bash
# Run comprehensive test suite:
bash scripts/test_authority_key_separation.sh

# Expected: 8/8 tests pass
```

### 7.2 Manual Verification

```bash
# Create test capability
cat > test_cap.json << EOF
{
  "node_id": "test-node",
  "release_id": "1.0.0",
  "commit": "abc123def456789abc123def456789abc123def4",
  "nonce": "test-nonce",
  "expires_at": "2026-12-31T23:59:59Z"
}
EOF

# Sign it
SIGNED=$(bash sovereign/sign_capability.sh test_cap.json)

# Verify signature (extract components)
JSON_PART=$(echo "$SIGNED" | cut -d'|' -f1)
SIG_PART=$(echo "$SIGNED" | cut -d'|' -f2)

# Verify with openssl
echo -n "$JSON_PART" > /tmp/msg.bin
printf '%s' "$(printf '%s' "$SIG_PART" | xxd -r -p)" > /tmp/sig.bin

openssl pkeyutl -verify -inkey sovereign/authority_pk.pem \
                 -pubin -sigfile /tmp/sig.bin \
                 -in /tmp/msg.bin

# Should output: "Signature Verified Successfully"
```

---

## 8. Reference

### Files

- `sovereign/authority_sk.pem` — Authority private key (secure server)
- `sovereign/authority_pk.pem` — Authority public key (distribute)
- `sovereign/sign_capability.sh` — Signing utility
- `scripts/pax-coder-gate` — Gate that verifies authorizations
- `scripts/test_authority_key_separation.sh` — Test suite

### Commands

- Generate keys: `bash sovereign/generate_authority_key.sh`
- Sign capability: `bash sovereign/sign_capability.sh <file.json>`
- Test gate: `bash scripts/test_authority_key_separation.sh`
- Verify clone: `bash scripts/verify-clone`

### Related Documentation

- [ADR-0010: Public Repository vs. Production Authorization Separation](./adr/0010-public-repository-authorization-separation.md)
- [ADR-0009: Protected Execution Capability Gate](./adr/0009-protected-execution-capability.md)
- [Authority Key Separation Audit](./AUTHORITY_KEY_SEPARATION_AUDIT.md)

---

*Bel Esprit D'Accord Irrevocable Trust · SnapKitty West · Evidence or Silence — 2026*
