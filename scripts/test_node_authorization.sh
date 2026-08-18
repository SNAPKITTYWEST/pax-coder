#!/bin/bash
# Node Authorization Test Suite
#
# Tests:
#   1. ACTIVE authorization -> ALLOW
#   2. REQUESTED authorization -> DENY
#   3. SUSPENDED authorization -> DENY
#   4. REVOKED authorization -> DENY
#   5. EXPIRED authorization -> DENY
#   6. Authorization matches node ID -> ALLOW
#   7. Authorization mismatched node ID -> DENY


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOVEREIGN_DIR="$REPO_ROOT/sovereign"
TEST_TEMP="/tmp/pax-node-auth-test-$$"
PASS=0
FAIL=0

mkdir -p "$TEST_TEMP"
trap "rm -rf $TEST_TEMP" EXIT

echo "=========================================="
echo "PAX-CODER NODE AUTHORIZATION TEST SUITE"
echo "=========================================="
echo ""

# Save original authorization
ORIGINAL_AUTH=$(cat "$SOVEREIGN_DIR/authorization.json")

test_case() {
  local test_num=$1
  local test_name=$2
  local expected_result=$3
  local auth_modification=$4

  echo "[Test $test_num] $test_name"

  # Apply modification
  eval "$auth_modification"

  # Run verification
  if "$SCRIPT_DIR/verify-node-authorization" > /dev/null 2>&1; then
    actual="ALLOW"
  else
    actual="DENY"
  fi

  # Check result
  if [ "$actual" = "$expected_result" ]; then
    echo "    ✓ PASS (expected: $expected_result, got: $actual)"
    ((PASS++))
  else
    echo "    ✗ FAIL (expected: $expected_result, got: $actual)"
    ((FAIL++))
  fi

  # Restore original
  echo "$ORIGINAL_AUTH" > "$SOVEREIGN_DIR/authorization.json"
  echo ""
}

# Test 1: ACTIVE authorization -> ALLOW
test_case 1 "ACTIVE authorization" "ALLOW" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"authorization_status\": \"[^\"]*\"|\"authorization_status\": \"ACTIVE\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Test 2: REQUESTED authorization -> DENY
test_case 2 "REQUESTED authorization" "DENY" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"authorization_status\": \"[^\"]*\"|\"authorization_status\": \"REQUESTED\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Test 3: SUSPENDED authorization -> DENY
test_case 3 "SUSPENDED authorization" "DENY" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"authorization_status\": \"[^\"]*\"|\"authorization_status\": \"SUSPENDED\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Test 4: REVOKED authorization -> DENY
test_case 4 "REVOKED authorization" "DENY" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"revocation_status\": \"[^\"]*\"|\"revocation_status\": \"REVOKED\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Test 5: EXPIRED authorization -> DENY
test_case 5 "EXPIRED authorization" "DENY" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"expires_at_utc\": \"[^\"]*\"|\"expires_at_utc\": \"2020-01-01T00:00:00Z\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Test 6: Authorization matches node ID -> ALLOW
test_case 6 "Authorization matches node ID" "ALLOW" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"authorization_status\": \"[^\"]*\"|\"authorization_status\": \"ACTIVE\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Test 7: Authorization mismatched node ID -> DENY
test_case 7 "Authorization mismatched node ID" "DENY" \
  'echo "$ORIGINAL_AUTH" | sed "s|\"node_id\": \"[^\"]*\"|\"node_id\": \"wrong-node-id-999999\"|" > "$SOVEREIGN_DIR/authorization.json"'

# Results
echo "=========================================="
echo "TEST RESULTS"
echo "=========================================="
echo "  Passed: $PASS/7"
echo "  Failed: $FAIL/7"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "All node authorization tests passed!"
  exit 0
else
  echo "Some tests failed!"
  exit 1
fi
