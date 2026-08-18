#!/bin/bash
# Sovereign Node Identity Generator
#
# Creates a node IDENTITY REQUEST (not an authorized credential).
# This is PUBLIC — does not require authorization.
#
# The identity created here is:
#   - UNREGISTERED (no provision yet)
#   - UNAUTHRIZED (not provisioned by PAX-Coder authority)
#
# To become AUTHORIZED for protected execution, the node must:
#   1. Request provisioning from the authority
#   2. Receive a signed authorization capability
#   3. Pass the capability to protected operations
#
# This script creates the identity. It does NOT auto-authorize.

set -e

SOVEREIGN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SOVEREIGN_DIR")")

NODE_ID="pax-coder-$(date +%s)"
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(cd "$REPO_ROOT" && git rev-parse HEAD)

echo "[*] Generating Sovereign Node Key for PAX-Coder"
echo "    Node ID: $NODE_ID"
echo "    Created: $CREATED_AT"
echo "    Git Commit: $GIT_COMMIT"

# Step 1: Generate Ed25519 keypair (private key NOT committed)
echo "[*] Generating Ed25519 keypair..."
openssl genpkey -algorithm Ed25519 -out "$SOVEREIGN_DIR/.node_sk" 2>/dev/null
openssl pkey -in "$SOVEREIGN_DIR/.node_sk" -pubout -out "$SOVEREIGN_DIR/node_pk.pem" 2>/dev/null

# Extract public key in hex
PUB_KEY_HEX=$(openssl pkey -in "$SOVEREIGN_DIR/node_pk.pem" -pubin -outform DER -out /tmp/pk.der 2>/dev/null && xxd -p /tmp/pk.der | tr -d '\n' && rm /tmp/pk.der)

# Step 2: Create node.json manifest
echo "[*] Creating node identity manifest..."
cat > "$SOVEREIGN_DIR/node.json" <<EOF
{
  "node_id": "$NODE_ID",
  "algorithm": "Ed25519",
  "public_key_hex": "$PUB_KEY_HEX",
  "created_at_utc": "$CREATED_AT",
  "repository": "SNAPKITTYWEST/pax-coder",
  "git_commit": "$GIT_COMMIT",
  "version": "1.0.0"
}
EOF

chmod 444 "$SOVEREIGN_DIR/node.json"
echo "    ✓ $SOVEREIGN_DIR/node.json"

# Step 3: Generate repository manifest and commitment
echo "[*] Computing repository commitment..."
cd "$REPO_ROOT"

# Find tracked files, normalize, hash each
MANIFEST_FILE="$SOVEREIGN_DIR/manifest.json"
cat > "$MANIFEST_FILE" <<'MANIFEST_EOF'
{
  "files": [
MANIFEST_EOF

git ls-tree -r HEAD | awk '{print $4}' | sort | while read file; do
  if [ -f "$file" ]; then
    FILE_HASH=$(sha256sum "$file" | cut -d' ' -f1)
    echo "    \"$file\": \"$FILE_HASH\"," >> "$MANIFEST_FILE"
  fi
done

# Remove trailing comma and close JSON
sed -i '$ s/,$//' "$MANIFEST_FILE"
cat >> "$MANIFEST_FILE" <<'MANIFEST_EOF'
  ],
  "generated_at_utc": "GENERATED_AT_PLACEHOLDER",
  "git_commit": "GIT_COMMIT_PLACEHOLDER"
}
MANIFEST_EOF

# Replace placeholders
sed -i "s/GENERATED_AT_PLACEHOLDER/$CREATED_AT/g" "$MANIFEST_FILE"
sed -i "s/GIT_COMMIT_PLACEHOLDER/$GIT_COMMIT/g" "$MANIFEST_FILE"

# Compute manifest hash
REPO_COMMITMENT=$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)

echo "    Repository Commitment: $REPO_COMMITMENT"

# Step 4: Create prior-art timestamp record
echo "[*] Creating prior-art timestamp record..."
cat > "$SOVEREIGN_DIR/prior_art.json" <<EOF
{
  "artifact": "PAX-Coder",
  "repository": "SNAPKITTYWEST/pax-coder",
  "git_commit": "$GIT_COMMIT",
  "repository_sha256": "$REPO_COMMITMENT",
  "node_id": "$NODE_ID",
  "created_at_utc": "$CREATED_AT",
  "timestamp_method": "local-generation",
  "status": "UNCONFIRMED",
  "node_public_key": "$PUB_KEY_HEX"
}
EOF

chmod 444 "$SOVEREIGN_DIR/prior_art.json"
echo "    ✓ $SOVEREIGN_DIR/prior_art.json"

# Step 5: Create verification record
echo "[*] Creating cryptographic record..."
cat > "$SOVEREIGN_DIR/verification.json" <<EOF
{
  "node_id": "$NODE_ID",
  "algorithm": "Ed25519",
  "repository_commitment_algorithm": "SHA-256",
  "repository_commitment": "$REPO_COMMITMENT",
  "git_commit": "$GIT_COMMIT",
  "manifest_file": "manifest.json",
  "prior_art_file": "prior_art.json",
  "verification_timestamp": "$CREATED_AT"
}
EOF

chmod 444 "$SOVEREIGN_DIR/verification.json"
echo "    ✓ $SOVEREIGN_DIR/verification.json"

# Step 6: Secure private key
echo "[*] Securing private key..."
chmod 400 "$SOVEREIGN_DIR/.node_sk"
echo "    ⚠ PRIVATE KEY: $SOVEREIGN_DIR/.node_sk (permissions: 400)"
echo "    ⚠ NEVER commit, share, or upload this file"

echo ""
echo "[✓] Sovereign Node Key generated successfully"
echo ""
echo "Files created:"
echo "  Public:"
echo "    - sovereign/node.json (public identity)"
echo "    - sovereign/node_pk.pem (public key PEM)"
echo "    - sovereign/manifest.json (repository fingerprint)"
echo "    - sovereign/prior_art.json (prior-art timestamp)"
echo "    - sovereign/verification.json (cryptographic record)"
echo ""
echo "  Private (LOCAL ONLY, DO NOT COMMIT):"
echo "    - sovereign/.node_sk (PRIVATE KEY - 400 perms)"
echo ""
echo "Next steps:"
echo "  1. Verify: ./sovereign/verify_node_key.sh"
echo "  2. Commit public files (sovereign/node.json, etc) - DO NOT COMMIT .node_sk"
echo "  3. Keep .node_sk secure"
echo "  4. For signing: set PAX_NODE_KEY=\$(cat sovereign/.node_sk | xxd -p | tr -d '\\n')"
