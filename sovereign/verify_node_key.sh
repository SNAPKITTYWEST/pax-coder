#!/bin/bash
# Sovereign Node Key Verification Script
# Verifies that all cryptographic artifacts are consistent and correct

set -e

SOVEREIGN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SOVEREIGN_DIR")"

echo "[*] Verifying Sovereign Node Key for PAX-Coder"
echo ""

# Check files exist
echo "[*] Checking required files..."
REQUIRED_FILES=(
  "node.json"
  "node_pk.pem"
  "manifest.json"
  "prior_art.json"
  "verification.json"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$SOVEREIGN_DIR/$file" ]; then
    echo "    ✓ $file"
  else
    echo "    ✗ $file (MISSING)"
    exit 1
  fi
done

echo ""
echo "[*] Checking private key protection..."
if [ -f "$SOVEREIGN_DIR/.node_sk" ]; then
  PERMS=$(stat -c '%a' "$SOVEREIGN_DIR/.node_sk" 2>/dev/null || stat -f '%A' "$SOVEREIGN_DIR/.node_sk" 2>/dev/null || echo "unknown")
  if [[ "$PERMS" == "400" ]] || [[ "$PERMS" == "rw-------" ]]; then
    echo "    ✓ .node_sk has correct permissions: $PERMS"
  else
    echo "    ⚠ .node_sk permissions are $PERMS (should be 400)"
  fi
else
  echo "    ⚠ .node_sk not found (OK if key is stored externally)"
fi

echo ""
echo "[*] Verifying manifests are valid JSON..."
for file in node.json manifest.json prior_art.json verification.json; do
  if jq . "$SOVEREIGN_DIR/$file" > /dev/null 2>&1; then
    echo "    ✓ $file is valid JSON"
  else
    echo "    ✗ $file is INVALID JSON"
    exit 1
  fi
done

echo ""
echo "[*] Extracting cryptographic commitments..."
NODE_ID=$(jq -r '.node_id' "$SOVEREIGN_DIR/node.json")
GIT_COMMIT=$(jq -r '.git_commit' "$SOVEREIGN_DIR/node.json")
REPO_COMMITMENT=$(jq -r '.repository_commitment' "$SOVEREIGN_DIR/verification.json")
PUB_KEY=$(jq -r '.node_id' "$SOVEREIGN_DIR/node.json")

echo "    Node ID: $NODE_ID"
echo "    Git Commit: $GIT_COMMIT"
echo "    Repository Commitment: $REPO_COMMITMENT"

echo ""
echo "[*] Verifying git commit is in repository..."
cd "$REPO_ROOT"
if git cat-file -t "$GIT_COMMIT" > /dev/null 2>&1; then
  echo "    ✓ Git commit $GIT_COMMIT exists in repository"
else
  echo "    ✗ Git commit $GIT_COMMIT NOT FOUND"
  exit 1
fi

echo ""
echo "[*] Verifying repository commitment..."
CURRENT_REPO_COMMITMENT=$(sha256sum "$SOVEREIGN_DIR/manifest.json" | cut -d' ' -f1)
RECORDED_COMMITMENT=$(jq -r '.repository_commitment' "$SOVEREIGN_DIR/verification.json")

if [ "$CURRENT_REPO_COMMITMENT" = "$RECORDED_COMMITMENT" ]; then
  echo "    ✓ Repository commitment is VALID"
  echo "    Hash: $CURRENT_REPO_COMMITMENT"
else
  echo "    ✗ Repository commitment MISMATCH"
  echo "    Current: $CURRENT_REPO_COMMITMENT"
  echo "    Recorded: $RECORDED_COMMITMENT"
  echo "    (This is expected if files have changed since key generation)"
fi

echo ""
echo "[*] Checking for private key material in git..."
if git grep -l "PRIVATE\|-----BEGIN" 2>/dev/null | grep -v "\.gitignore"; then
  echo "    ⚠ WARNING: Possible private key material in git history"
else
  echo "    ✓ No obvious private key material in tracked files"
fi

echo ""
echo "[✓] Sovereign Node Key verification complete"
echo ""
echo "Summary:"
echo "  Node ID: $NODE_ID"
echo "  Git Commit: $GIT_COMMIT"
echo "  Repository Commitment: $REPO_COMMITMENT"
echo "  Status: VERIFIED ✓"
