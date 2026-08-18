#!/bin/bash
# PAX-Coder Official Release Signing
# Generates canonical manifest + signs with Sovereign Node Key
# Output: release.json (publishable on GitHub)

set -e

SOVEREIGN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SOVEREIGN_DIR")"
RELEASE_VERSION="${1:-1.0.0}"
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(cd "$REPO_ROOT" && git rev-parse HEAD)

# Verify private key exists
if [ ! -f "$SOVEREIGN_DIR/.node_sk" ]; then
  echo "[ERROR] Private key not found: $SOVEREIGN_DIR/.node_sk"
  echo "        Generate with: ./generate_node_key.sh"
  exit 1
fi

echo "[*] Generating PAX-Coder Official Release Signature"
echo "    Version: $RELEASE_VERSION"
echo "    Commit: $GIT_COMMIT"
echo "    Date: $CREATED_AT"

# Step 1: Read existing node identity
echo "[*] Reading node identity..."
NODE_ID=$(jq -r '.node_id' "$SOVEREIGN_DIR/node.json")
PUB_KEY_HEX=$(jq -r '.public_key_hex' "$SOVEREIGN_DIR/node.json")

echo "    Node ID: $NODE_ID"

# Step 2: Generate canonical file manifest for this release
echo "[*] Generating canonical release manifest..."
MANIFEST_FILE="/tmp/pax-release-manifest-$RELEASE_VERSION.json"
cat > "$MANIFEST_FILE" <<'MANIFEST_JSON'
{
  "project": "PAX-Coder",
  "repository": "SNAPKITTYWEST/pax-coder",
  "release_version": "RELEASE_VERSION_PLACEHOLDER",
  "git_commit": "GIT_COMMIT_PLACEHOLDER",
  "node_id": "NODE_ID_PLACEHOLDER",
  "node_public_key_hex": "PUB_KEY_PLACEHOLDER",
  "release_timestamp_utc": "TIMESTAMP_PLACEHOLDER",
  "files": {
MANIFEST_JSON

# Hash each tracked file
cd "$REPO_ROOT"
git ls-tree -r HEAD | awk '{print $4}' | sort | while read file; do
  if [ -f "$file" ]; then
    FILE_HASH=$(sha256sum "$file" | cut -d' ' -f1)
    echo "    \"$file\": \"$FILE_HASH\"," >> "$MANIFEST_FILE"
  fi
done

# Remove trailing comma and close JSON
sed -i '$ s/,$//' "$MANIFEST_FILE"
cat >> "$MANIFEST_FILE" <<'MANIFEST_JSON'
  },
  "manifest_schema_version": "1.0.0"
}
MANIFEST_JSON

# Replace placeholders
sed -i "s/RELEASE_VERSION_PLACEHOLDER/$RELEASE_VERSION/g" "$MANIFEST_FILE"
sed -i "s/GIT_COMMIT_PLACEHOLDER/$GIT_COMMIT/g" "$MANIFEST_FILE"
sed -i "s/NODE_ID_PLACEHOLDER/$NODE_ID/g" "$MANIFEST_FILE"
sed -i "s/PUB_KEY_PLACEHOLDER/$PUB_KEY_HEX/g" "$MANIFEST_FILE"
sed -i "s/TIMESTAMP_PLACEHOLDER/$CREATED_AT/g" "$MANIFEST_FILE"

# Validate JSON
if ! jq . "$MANIFEST_FILE" > /dev/null 2>&1; then
  echo "[ERROR] Generated manifest is invalid JSON"
  exit 1
fi

echo "    ✓ Manifest generated"

# Step 3: Compute manifest commitment
echo "[*] Computing manifest commitment..."
MANIFEST_SHA256=$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)
echo "    Commitment: $MANIFEST_SHA256"

# Step 4: Sign manifest with private key
echo "[*] Signing manifest..."
SIGNATURE_FILE="/tmp/pax-release-$RELEASE_VERSION.sig"
openssl dgst -sha256 -sign "$SOVEREIGN_DIR/.node_sk" "$MANIFEST_FILE" > "$SIGNATURE_FILE" 2>/dev/null

# Convert signature to hex
SIGNATURE_HEX=$(xxd -p "$SIGNATURE_FILE" | tr -d '\n')

echo "    ✓ Signature created (${#SIGNATURE_HEX} hex chars)"

# Step 5: Create release record (publishable)
echo "[*] Creating release record..."
RELEASE_FILE="$SOVEREIGN_DIR/release.json"
cat > "$RELEASE_FILE" <<RELEASE_JSON
{
  "project": "PAX-Coder",
  "repository": "SNAPKITTYWEST/pax-coder",
  "release_version": "$RELEASE_VERSION",
  "git_commit": "$GIT_COMMIT",
  "node_id": "$NODE_ID",
  "node_public_key_hex": "$PUB_KEY_HEX",
  "release_timestamp_utc": "$CREATED_AT",
  "manifest_sha256": "$MANIFEST_SHA256",
  "signature_hex": "$SIGNATURE_HEX",
  "signature_algorithm": "Ed25519",
  "verification_method": "Ed25519",
  "prior_art_record": {
    "artifact": "PAX-Coder",
    "repository": "SNAPKITTYWEST/pax-coder",
    "git_commit": "$GIT_COMMIT",
    "release_version": "$RELEASE_VERSION",
    "repository_manifest_sha256": "$MANIFEST_SHA256",
    "node_id": "$NODE_ID",
    "created_at_utc": "$CREATED_AT",
    "timestamp_method": "local-generation",
    "status": "UNCONFIRMED"
  }
}
RELEASE_JSON

chmod 444 "$RELEASE_FILE"

echo "    ✓ $RELEASE_FILE"

# Step 6: Copy manifest to sovereign directory for reference
cp "$MANIFEST_FILE" "$SOVEREIGN_DIR/manifest-$RELEASE_VERSION.json"
chmod 444 "$SOVEREIGN_DIR/manifest-$RELEASE_VERSION.json"

# Clean temp files
rm -f "$SIGNATURE_FILE"

echo ""
echo "[✓] Release signature complete"
echo ""
echo "Files created (publishable):"
echo "  - sovereign/release.json"
echo "  - sovereign/manifest-$RELEASE_VERSION.json"
echo ""
echo "Next steps:"
echo "  1. Commit both files to git"
echo "  2. Push to GitHub"
echo "  3. Create GitHub Release"
echo "  4. Attach release.json and manifest-$RELEASE_VERSION.json to release"
echo "  5. External users can verify with: ./scripts/verify-clone"
echo ""
echo "Release summary:"
echo "  Version: $RELEASE_VERSION"
echo "  Commit: $GIT_COMMIT"
echo "  Manifest SHA-256: $MANIFEST_SHA256"
echo "  Signature: ${SIGNATURE_HEX:0:64}..."
echo "  Node ID: $NODE_ID"
echo "  Timestamp: $CREATED_AT"
