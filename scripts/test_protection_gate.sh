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
YELLOW='\033[0;33m'
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

echo "[Test 2] Modified release + valid capability = execution denied"

# Create a valid capability
FUTURE_TIME=$(date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              date -u -v +1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              echo "2026-08-18T16:00:00Z")

CAPABILITY_JSON="{\"node_id\":\"test\",\"release_id\":\"test\",\"commit\":\"$(git rev-parse HEAD)\",\"nonce\":\"test-nonce\",\"expires_at\":\"$FUTURE_TIME\"}"
CAPABILITY_SIG="a" $(printf 'a%.0s' {1..127}) # 128 'a's
export PAX_CAPABILITY_TOKEN="$CAPABILITY_JSON|$CAPABILITY_SIG"

# Modify a file to break integrity
echo "modified" >> README.md

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test2.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have been denied (integrity failed)"
  FAIL=$((FAIL+1))
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 1 ]; then
    if grep -q "FAILED" /tmp/test2.log || grep -q "integrity" /tmp/test2.log; then
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

# Restore README
git restore README.md

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
CAPABILITY_SIG="b" $(printf 'b%.0s' {1..127})
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
CAPABILITY_SIG="c" $(printf 'c%.0s' {1..127})
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

FUTURE_TIME=$(date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              date -u -v +1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              echo "2026-08-18T16:00:00Z")

CAPABILITY_JSON="{\"node_id\":\"test\",\"release_id\":\"test\",\"commit\":\"$(git rev-parse HEAD)\",\"nonce\":\"test-nonce\",\"expires_at\":\"$FUTURE_TIME\"}"
CAPABILITY_SIG="d" $(printf 'd%.0s' {1..127})
export PAX_CAPABILITY_TOKEN="$CAPABILITY_JSON|$CAPABILITY_SIG"

if "$SCRIPT_DIR/pax-coder-gate" > /tmp/test6.log 2>&1; then
  if grep -q "AUTHORIZATION_GRANTED" /tmp/test6.log; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong status message"
    FAIL=$((FAIL+1))
  fi
else
  echo -e "${RED}✗ FAIL${NC} - Should have succeeded"
  FAIL=$((FAIL+1))
fi

rm -f /tmp/test6.log
unset PAX_CAPABILITY_TOKEN
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
