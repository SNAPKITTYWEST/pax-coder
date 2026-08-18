#!/bin/bash
# Test suite for ADR-governed verification scripts
#
# Tests:
#   1. verify-clone runs successfully on authentic clone
#   2. verify-clone fails on modified file
#   3. verify-clone fails on wrong commit
#   4. verify-release distinguishes integrity from authorization
#   5. verify-release AUTHORIZED when token present
#   6. verify-release NOT_AUTHORIZED when token missing
#
# Usage: ./scripts/test_verification.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOVEREIGN_DIR="$REPO_ROOT/sovereign"
TEST_DIR="/tmp/pax-test-$$"

PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "PAX-CODER VERIFICATION TEST SUITE"
echo "========================================"
echo ""

# ============================================================================
# Test 1: verify-clone succeeds on authentic clone
# ============================================================================

echo "[Test 1] verify-clone succeeds on authentic clone"

if "$SCRIPT_DIR/verify-clone" > /tmp/test1.log 2>&1; then
  if grep -q "STATUS: INTEGRITY_VERIFIED" /tmp/test1.log; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - No INTEGRITY_VERIFIED status"
    FAIL=$((FAIL+1))
  fi
else
  echo -e "${RED}✗ FAIL${NC} - Script failed"
  FAIL=$((FAIL+1))
fi

rm -f /tmp/test1.log
echo ""

# ============================================================================
# Test 2: verify-clone fails on modified file
# ============================================================================

echo "[Test 2] verify-clone fails when manifest is modified"

# Create backup
cp "$SOVEREIGN_DIR/release.json" "$SOVEREIGN_DIR/release.json.bak"

# Modify manifest hash in release.json
sed -i 's/"manifest_sha256": "[^"]*"/"manifest_sha256": "0000000000000000000000000000000000000000000000000000000000000000"/g' "$SOVEREIGN_DIR/release.json"

if "$SCRIPT_DIR/verify-clone" > /tmp/test2.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have failed on modified manifest"
  FAIL=$((FAIL+1))
else
  if grep -q "Hash mismatch" /tmp/test2.log || grep -q "VERIFICATION FAILED" /tmp/test2.log; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong error message"
    FAIL=$((FAIL+1))
  fi
fi

# Restore
mv "$SOVEREIGN_DIR/release.json.bak" "$SOVEREIGN_DIR/release.json"

rm -f /tmp/test2.log
echo ""

# ============================================================================
# Test 3: verify-clone fails on commit mismatch
# ============================================================================

echo "[Test 3] verify-clone fails when commit doesn't match"

# Create backup
cp "$SOVEREIGN_DIR/release.json" "$SOVEREIGN_DIR/release.json.bak"

# Modify commit in release.json
sed -i 's/"git_commit": "[^"]*"/"git_commit": "0000000000000000000000000000000000000000"/g' "$SOVEREIGN_DIR/release.json"

if "$SCRIPT_DIR/verify-clone" > /tmp/test3.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have failed on commit mismatch"
  FAIL=$((FAIL+1))
else
  if grep -q "Commit mismatch" /tmp/test3.log; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong error message"
    FAIL=$((FAIL+1))
  fi
fi

# Restore
mv "$SOVEREIGN_DIR/release.json.bak" "$SOVEREIGN_DIR/release.json"

rm -f /tmp/test3.log
echo ""

# ============================================================================
# Test 4: verify-release separates integrity from authorization
# ============================================================================

echo "[Test 4] verify-release distinguishes integrity from authorization"

# Temporarily hide .node_sk to simulate public clone
if [ -f "$SOVEREIGN_DIR/.node_sk" ]; then
  mv "$SOVEREIGN_DIR/.node_sk" "$SOVEREIGN_DIR/.node_sk.hidden"
fi

if "$SCRIPT_DIR/verify-release" > /tmp/test4.log 2>&1; then
  echo -e "${RED}✗ FAIL${NC} - Should have failed authorization check"
  FAIL=$((FAIL+1))
else
  if grep -q "VERIFIED_NOT_AUTHORIZED" /tmp/test4.log && grep -q "Integrity verified" /tmp/test4.log; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong status"
    FAIL=$((FAIL+1))
  fi
fi

# Restore .node_sk
if [ -f "$SOVEREIGN_DIR/.node_sk.hidden" ]; then
  mv "$SOVEREIGN_DIR/.node_sk.hidden" "$SOVEREIGN_DIR/.node_sk"
fi

rm -f /tmp/test4.log
echo ""

# ============================================================================
# Test 5: verify-release grants authorization with private key
# ============================================================================

echo "[Test 5] verify-release succeeds when .node_sk is present"

if [ -f "$SOVEREIGN_DIR/.node_sk" ]; then
  if "$SCRIPT_DIR/verify-release" > /tmp/test5.log 2>&1; then
    if grep -q "VERIFIED_AND_AUTHORIZED" /tmp/test5.log; then
      echo -e "${GREEN}✓ PASS${NC}"
      PASS=$((PASS+1))
    else
      echo -e "${RED}✗ FAIL${NC} - Wrong status"
      FAIL=$((FAIL+1))
    fi
  else
    echo -e "${RED}✗ FAIL${NC} - Script failed"
    FAIL=$((FAIL+1))
  fi
else
  echo -e "${YELLOW}⊘ SKIP${NC} - .node_sk not present (expected in development)"
fi

rm -f /tmp/test5.log
echo ""

# ============================================================================
# Test 6: verify-release grants authorization with PAX_AUTH_TOKEN
# ============================================================================

echo "[Test 6] verify-release succeeds with PAX_AUTH_TOKEN environment variable"

# Hide .node_sk to force environment variable check
if [ -f "$SOVEREIGN_DIR/.node_sk" ]; then
  mv "$SOVEREIGN_DIR/.node_sk" "$SOVEREIGN_DIR/.node_sk.hidden"
fi

export PAX_AUTH_TOKEN="test-token-123"

if "$SCRIPT_DIR/verify-release" > /tmp/test6.log 2>&1; then
  if grep -q "VERIFIED_AND_AUTHORIZED" /tmp/test6.log; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗ FAIL${NC} - Wrong status"
    FAIL=$((FAIL+1))
  fi
else
  echo -e "${RED}✗ FAIL${NC} - Script failed"
  FAIL=$((FAIL+1))
fi

unset PAX_AUTH_TOKEN

# Restore .node_sk
if [ -f "$SOVEREIGN_DIR/.node_sk.hidden" ]; then
  mv "$SOVEREIGN_DIR/.node_sk.hidden" "$SOVEREIGN_DIR/.node_sk"
fi

rm -f /tmp/test6.log
echo ""

# ============================================================================
# Summary
# ============================================================================

TOTAL=$((PASS+FAIL))

echo "========================================"
echo "TEST RESULTS"
echo "========================================"
echo ""
echo -e "  Passed: ${GREEN}$PASS/$TOTAL${NC}"
echo -e "  Failed: ${RED}$FAIL/$TOTAL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "All tests passed!"
  exit 0
else
  echo "Some tests failed."
  exit 1
fi
