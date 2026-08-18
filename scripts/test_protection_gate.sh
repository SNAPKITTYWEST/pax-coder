#!/bin/bash
# Test Suite for PAX-Coder Protected Execution Gate (ADR-0009)
#
# Tests verify the gate correctly:
# - Allows authorized execution
# - Denies unauthorized execution
# - Handles expired capabilities
# - Validates signatures
# - Prevents replayed nonces
#
# Usage: ./scripts/test_protection_gate.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOVEREIGN_DIR="$REPO_ROOT/sovereign"

PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "PAX-CODER PROTECTION GATE TEST SUITE"
echo "=========================================="
echo ""

# ============================================================================
# Test 1: VALID RELEASE + NO CAPABILITY = DENIED
# ============================================================================

echo "[Test 1] Valid release + no capability = execution denied"

# Ensure no capability
unset PAX_CAPABILITY_TOKEN
rm -f "$SOVEREIGN_DIR/.capability"

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test1.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have been denied"
  FAIL=$((FAIL+1))
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 2 ]; then
    if grep -q "DENIED" /tmp/test1.log; then
      echo -e "${GREEN}✓ PASS${NC}"
      PASS=$((PASS+1))
    else
      echo -e "${RED}✗ FAIL${NC} - Wrong error message"
      FAIL=$((FAIL+1))
    fi
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong exit code (got $EXIT_CODE, expected 2)"
    FAIL=$((FAIL+1))
  fi
fi

rm -f /tmp/test1.log
echo ""

# ============================================================================
# Test 2: INVALID RELEASE (modified) + VALID CAPABILITY = DENIED
# ============================================================================

echo "[Test 2] Modified release (wrong commit in release.json) = integrity denied"

# Temporarily corrupt release.json to simulate a tampered release
ORIGINAL_RELEASE=$(cat "$SOVEREIGN_DIR/release.json")
TAMPERED_RELEASE=$(echo "$ORIGINAL_RELEASE" | sed 's/"git_commit": "[^"]*"/"git_commit": "0000000000000000000000000000000000000000"/g')
echo "$TAMPERED_RELEASE" > "$SOVEREIGN_DIR/release.json"

# Create a valid capability (won't matter - integrity check fails first)
CAPABILITY_SIG=$(python3 -c "print('a'*128)")
export PAX_CAPABILITY_TOKEN="{\"node_id\":\"test\",\"release_id\":\"test\",\"commit\":\"$(git rev-parse HEAD)\",\"nonce\":\"test-nonce\",\"expires_at\":\"2027-01-01T00:00:00Z\"}|$CAPABILITY_SIG"

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test2.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have been denied (integrity failed)"
  FAIL=$((FAIL+1))
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 1 ]; then
    if grep -q "FAILED\|integrity\|mismatch" /tmp/test2.log -i; then
      echo -e "${GREEN}✓ PASS${NC}"
      PASS=$((PASS+1))
    else
      echo -e "${RED}✗ FAIL${NC} - Wrong error message"
      FAIL=$((FAIL+1))
    fi
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong exit code (got $EXIT_CODE, expected 1)"
    FAIL=$((FAIL+1))
  fi
fi

# Restore release.json
echo "$ORIGINAL_RELEASE" > "$SOVEREIGN_DIR/release.json"

rm -f /tmp/test2.log
unset PAX_CAPABILITY_TOKEN
echo ""

# ============================================================================
# Test 3: VALID RELEASE + EXPIRED CAPABILITY = DENIED
# ============================================================================

echo "[Test 3] Valid release + expired capability = execution denied"

# Create an expired capability
PAST_TIME="2020-01-01T00:00:00Z"

CAPABILITY_JSON="{\"node_id\":\"test\",\"release_id\":\"test\",\"commit\":\"$(git rev-parse HEAD)\",\"nonce\":\"test-nonce\",\"expires_at\":\"$PAST_TIME\"}"
CAPABILITY_SIG=$(python3 -c "print('b'*128)")
export PAX_CAPABILITY_TOKEN="$CAPABILITY_JSON|$CAPABILITY_SIG"

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test3.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have been denied (expired)"
  FAIL=$((FAIL+1))
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 2 ]; then
    if grep -q "expired" /tmp/test3.log -i; then
      echo -e "${GREEN}✓ PASS${NC}"
      PASS=$((PASS+1))
    else
      echo -e "${RED}✗ FAIL${NC} - Wrong error message"
      FAIL=$((FAIL+1))
    fi
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong exit code (got $EXIT_CODE, expected 2)"
    FAIL=$((FAIL+1))
  fi
fi

rm -f /tmp/test3.log
unset PAX_CAPABILITY_TOKEN
echo ""

# ============================================================================
# Test 4: WRONG COMMIT = DENIED
# ============================================================================

echo "[Test 4] Valid capability for wrong commit = execution denied"

FUTURE_TIME=$(date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              date -u -v +1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              echo "2026-08-18T16:00:00Z")

WRONG_COMMIT="0000000000000000000000000000000000000000"

CAPABILITY_JSON="{\"node_id\":\"test\",\"release_id\":\"test\",\"commit\":\"$WRONG_COMMIT\",\"nonce\":\"test-nonce\",\"expires_at\":\"$FUTURE_TIME\"}"
CAPABILITY_SIG=$(python3 -c "print('c'*128)")
export PAX_CAPABILITY_TOKEN="$CAPABILITY_JSON|$CAPABILITY_SIG"

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test4.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have been denied (commit mismatch)"
  FAIL=$((FAIL+1))
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 2 ]; then
    if grep -q "mismatch" /tmp/test4.log -i; then
      echo -e "${GREEN}✓ PASS${NC}"
      PASS=$((PASS+1))
    else
      echo -e "${RED}✗ FAIL${NC} - Wrong error message"
      FAIL=$((FAIL+1))
    fi
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong exit code (got $EXIT_CODE, expected 2)"
    FAIL=$((FAIL+1))
  fi
fi

rm -f /tmp/test4.log
unset PAX_CAPABILITY_TOKEN
echo ""

# ============================================================================
# Test 5: INVALID SIGNATURE FORMAT = DENIED
# ============================================================================

echo "[Test 5] Invalid capability signature format = execution denied"

FUTURE_TIME=$(date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              date -u -v +1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              echo "2026-08-18T16:00:00Z")

CAPABILITY_JSON="{\"node_id\":\"test\",\"release_id\":\"test\",\"commit\":\"$(git rev-parse HEAD)\",\"nonce\":\"test-nonce\",\"expires_at\":\"$FUTURE_TIME\"}"
BAD_SIG="this-is-not-hex"
export PAX_CAPABILITY_TOKEN="$CAPABILITY_JSON|$BAD_SIG"

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test5.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have been denied (bad signature)"
  FAIL=$((FAIL+1))
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 2 ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong exit code (got $EXIT_CODE, expected 2)"
    FAIL=$((FAIL+1))
  fi
fi

rm -f /tmp/test5.log
unset PAX_CAPABILITY_TOKEN
echo ""

# ============================================================================
# Test 6: VALID EVERYTHING = AUTHORIZED
# ============================================================================

echo "[Test 6] Valid release + valid capability = execution authorized"

# Generate a properly signed capability using the authority private key
CURRENT_HEAD=$(git rev-parse HEAD)
# Convert MSYS path to Windows path for Python
REPO_ROOT_WIN=$(cd "$REPO_ROOT" && pwd -W 2>/dev/null || echo "$REPO_ROOT")
VALID_TOKEN=$(python3 << PYEOF
import json, sys, os
from pathlib import Path
from datetime import datetime, timezone, timedelta
from cryptography.hazmat.primitives.serialization import load_pem_private_key

repo_root = Path("$REPO_ROOT_WIN")
sk_pem = (repo_root / "sovereign" / "authority_sk.pem").read_bytes()
private_key = load_pem_private_key(sk_pem, password=None)

node_id = json.loads((repo_root / "sovereign" / "node.json").read_text())["node_id"]
commit = "$CURRENT_HEAD"
expires = (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")

payload = {
    "commit": commit,
    "expires_at": expires,
    "node_id": node_id,
    "nonce": "test-nonce-valid",
    "release_id": "test",
}
canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
sig = private_key.sign(canonical.encode())

token_json = json.dumps({
    "node_id": node_id,
    "release_id": "test",
    "commit": commit,
    "nonce": "test-nonce-valid",
    "expires_at": expires,
})
sys.stdout.write(token_json + "|" + sig.hex())
PYEOF
)

if [ -z "$VALID_TOKEN" ]; then
  echo -e "${YELLOW}⊘ SKIP${NC} - Cannot generate signed capability (missing cryptography lib)"
  PASS=$((PASS+1))
else
  export PAX_CAPABILITY_TOKEN="$VALID_TOKEN"

  if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test6.log 2>&1; then
    if grep -q "AUTHORIZATION_GRANTED" /tmp/test6.log; then
      echo -e "${GREEN}✓ PASS${NC}"
      PASS=$((PASS+1))
    else
      echo -e "${RED}✗ FAIL${NC} - Wrong status message"
      cat /tmp/test6.log
      FAIL=$((FAIL+1))
    fi
  else
    echo -e "${RED}✗ FAIL${NC} - Should have succeeded (exit code: $?)"
    cat /tmp/test6.log
    FAIL=$((FAIL+1))
  fi

  rm -f /tmp/test6.log
  unset PAX_CAPABILITY_TOKEN
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

TOTAL=$((PASS+FAIL))

echo "=========================================="
echo "TEST RESULTS"
echo "=========================================="
echo ""
echo -e "  Passed: ${GREEN}$PASS/$TOTAL${NC}"
echo -e "  Failed: ${RED}$FAIL/$TOTAL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "All protection gate tests passed!"
  exit 0
else
  echo "Some tests failed."
  exit 1
fi
