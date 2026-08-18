#!/bin/bash
# Generate PAX-Coder Authority Keypair (Ed25519)
#
# This script generates the authority's keypair for signing capabilities.
# The authority private key (authority_sk.pem) MUST remain secure and off-repo.
# The authority public key (authority_pk.pem) is distributed to verifiers.
#
# SECURITY INVARIANT:
#   - authority_sk.pem: NEVER committed, NEVER in repo, NEVER shared
#   - authority_pk.pem: SAFE to distribute, used by gate for verification
#
# Exit codes:
#   0 = Success
#   1 = Error

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Configuration
# ============================================================================

AUTHORITY_SK="$SCRIPT_DIR/authority_sk.pem"
AUTHORITY_PK="$SCRIPT_DIR/authority_pk.pem"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ============================================================================
# Generate keypair
# ============================================================================

echo "Generating PAX-Coder Authority Keypair (Ed25519)..."
echo ""

if [ -f "$AUTHORITY_SK" ]; then
  echo "WARNING: authority_sk.pem already exists"
  echo "Use the existing key or manually delete it to regenerate."
  exit 0
fi

# Generate Ed25519 private key
openssl genpkey -algorithm Ed25519 -out "$AUTHORITY_SK"

# Extract public key
openssl pkey -in "$AUTHORITY_SK" -pubout -out "$AUTHORITY_PK"

# Set restrictive permissions on private key
chmod 600 "$AUTHORITY_SK"
chmod 644 "$AUTHORITY_PK"

echo ""
echo "=========================================="
echo "Authority Keypair Generated"
echo "=========================================="
echo ""
echo "Private Key:  $AUTHORITY_SK"
echo "Public Key:   $AUTHORITY_PK"
echo ""
echo "CRITICAL SECURITY INSTRUCTIONS:"
echo "  1. PRIVATE KEY ($AUTHORITY_SK):"
echo "     - MUST be kept secure"
echo "     - MUST NOT be committed to git"
echo "     - MUST be protected with file permissions (600)"
echo "     - MUST be backed up securely"
echo "     - Store on: authority server ONLY"
echo ""
echo "  2. PUBLIC KEY ($AUTHORITY_PK):"
echo "     - Safe to distribute"
echo "     - Used by gate for verification"
echo "     - Added to .gitignore (not committed)"
echo "     - Can be shared with all nodes"
echo ""
echo "NEXT STEPS:"
echo "  1. Verify file permissions: ls -la $AUTHORITY_SK $AUTHORITY_PK"
echo "  2. Test signature: ./sovereign/test_authority_signature.sh"
echo "  3. Deploy public key to nodes"
echo "  4. Update gate configuration with authority_pk.pem path"
echo ""

exit 0
