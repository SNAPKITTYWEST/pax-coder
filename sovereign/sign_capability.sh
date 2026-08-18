#!/bin/bash
# Sign a Capability with Authority Private Key
#
# This script is run by the authority to sign capability records.
# It takes a capability JSON and produces an Ed25519 signature.
#
# Usage: ./sovereign/sign_capability.sh <capability.json>
#
# Outputs: JSON with signature attached
#
# Exit codes:
#   0 = Success
#   1 = File not found or invalid JSON
#   2 = Authority key not accessible
#   3 = Signature failed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Configuration
# ============================================================================

AUTHORITY_SK="$SCRIPT_DIR/authority_sk.pem"
CAPABILITY_FILE="${1:-}"

# ============================================================================
# Validation
# ============================================================================

if [ -z "$CAPABILITY_FILE" ]; then
  echo "ERROR: Usage: $0 <capability.json>" >&2
  exit 1
fi

if [ ! -f "$CAPABILITY_FILE" ]; then
  echo "ERROR: Capability file not found: $CAPABILITY_FILE" >&2
  exit 1
fi

if [ ! -f "$AUTHORITY_SK" ]; then
  echo "ERROR: Authority private key not found: $AUTHORITY_SK" >&2
  echo "HINT: Generate with: ./sovereign/generate_authority_key.sh" >&2
  exit 2
fi

# ============================================================================
# Sign Capability
# ============================================================================

# Create temporary files for normalization
TEMP_NORMALIZE="/tmp/pax-normalize-$$.py"
TEMP_CANONICAL="/tmp/pax-canonical-$$.json"
TEMP_MSG="/tmp/pax-msg-$$.bin"
TEMP_SIG="/tmp/pax-sig-$$.bin"

trap "rm -f '$TEMP_NORMALIZE' '$TEMP_CANONICAL' '$TEMP_MSG' '$TEMP_SIG'" EXIT

# Create Python script for JSON normalization
cat > "$TEMP_NORMALIZE" << 'PYTHON_EOF'
import json
import sys

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    # Sort keys and use compact format
    print(json.dumps(data, sort_keys=True, separators=(',', ':')), end='')
except Exception as e:
    sys.stderr.write(f"ERROR: {e}\n")
    sys.exit(1)
PYTHON_EOF

# Normalize JSON using Python
if ! python3 "$TEMP_NORMALIZE" "$CAPABILITY_FILE" > "$TEMP_CANONICAL" 2>/dev/null; then
  echo "ERROR: Invalid JSON or normalization failed" >&2
  exit 1
fi

# Read canonical JSON
CAPABILITY_CANONICAL=$(cat "$TEMP_CANONICAL")

if [ -z "$CAPABILITY_CANONICAL" ]; then
  echo "ERROR: Failed to read canonical JSON" >&2
  exit 1
fi

# Write canonical JSON to file for signing
echo -n "$CAPABILITY_CANONICAL" > "$TEMP_MSG"

# Sign with authority private key (Ed25519)
if ! openssl pkeyutl -sign -inkey "$AUTHORITY_SK" \
                     -in "$TEMP_MSG" \
                     -out "$TEMP_SIG" 2>/dev/null; then
  echo "ERROR: Signature operation failed" >&2
  exit 3
fi

# Convert signature to hex
SIGNATURE_HEX=$(xxd -p -c 256 < "$TEMP_SIG" | tr -d '\n')

# Verify signature is correct length (128 hex chars = 64 bytes)
SIG_LEN=${#SIGNATURE_HEX}
if [ "$SIG_LEN" -ne 128 ]; then
  echo "ERROR: Signature has invalid length: $SIG_LEN (expected 128)" >&2
  exit 3
fi

# ============================================================================
# Output
# ============================================================================

echo "$CAPABILITY_CANONICAL|$SIGNATURE_HEX"

exit 0
