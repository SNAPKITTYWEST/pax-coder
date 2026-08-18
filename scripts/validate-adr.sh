#!/bin/bash
# ADR CI Validation
# Validates ADRs for required fields and consistency
# Usage: ./scripts/validate-adr.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADR_DIR="$REPO_ROOT/docs/adr"
ERRORS=0

echo "=== ADR Validation ==="
echo ""

# Check all ADRs exist
if [ ! -d "$ADR_DIR" ]; then
  echo "ERROR: $ADR_DIR does not exist"
  exit 1
fi

echo "[*] Validating ADRs in $ADR_DIR"
echo ""

# Validate each ADR
for adr in "$ADR_DIR"/[0-9]*.md; do
  if [ ! -f "$adr" ]; then
    continue
  fi

  FILENAME=$(basename "$adr")
  ADR_ID=$(echo "$FILENAME" | sed 's/-.*//')

  echo "[*] Checking $FILENAME"

  # Check required fields
  if ! grep -q "^# ADR-[0-9]*:" "$adr"; then
    echo "  ✗ Missing ADR title (# ADR-nnnn:)"
    ERRORS=$((ERRORS+1))
  fi

  if ! grep -q "**Status:**" "$adr"; then
    echo "  ✗ Missing Status field"
    ERRORS=$((ERRORS+1))
  fi

  if ! grep -q "**Date:**" "$adr"; then
    echo "  ✗ Missing Date field"
    ERRORS=$((ERRORS+1))
  fi

  if ! grep -q "## Context" "$adr"; then
    echo "  ✗ Missing Context section"
    ERRORS=$((ERRORS+1))
  fi

  if ! grep -q "## Decision" "$adr"; then
    echo "  ✗ Missing Decision section"
    ERRORS=$((ERRORS+1))
  fi

  if ! grep -q "## Rules" "$adr"; then
    echo "  ✗ Missing Rules section"
    ERRORS=$((ERRORS+1))
  fi

  if ! grep -q "## Consequences" "$adr"; then
    echo "  ✗ Missing Consequences section"
    ERRORS=$((ERRORS+1))
  fi

  # Check status is valid
  STATUS=$(grep "**Status:**" "$adr" | sed 's/.*Status: *//' | sed 's/ .*//')
  if [[ ! "$STATUS" =~ ^(Accepted|Proposed|Superseded|Rejected)$ ]]; then
    echo "  ✗ Invalid Status: $STATUS (must be: Accepted, Proposed, Superseded, Rejected)"
    ERRORS=$((ERRORS+1))
  fi

  echo "  ✓ Valid ADR"
done

echo ""

# Check for private key patterns in code
echo "[*] Scanning for private key patterns in repository..."

PRIVATE_KEY_PATTERNS=(
  "-----BEGIN.*PRIVATE"
  "-----END.*PRIVATE"
  "private_key.*="
  "secret_key.*="
  "PRIVATE_KEY.*="
)

FOUND_KEYS=0
for pattern in "${PRIVATE_KEY_PATTERNS[@]}"; do
  if grep -r "$pattern" "$REPO_ROOT" --include="*.py" --include="*.js" --include="*.sh" 2>/dev/null | grep -v "docs/adr" | grep -v ".gitignore" | head -1; then
    FOUND_KEYS=$((FOUND_KEYS+1))
  fi
done

if [ $FOUND_KEYS -gt 0 ]; then
  echo "  ✗ Found private key patterns in code"
  ERRORS=$((ERRORS+1))
else
  echo "  ✓ No private key patterns found"
fi

# Check .gitignore
echo "[*] Checking .gitignore for private key protection..."

REQUIRED_IGNORES=(
  "sovereign/.node_sk"
  "*.pem"
  "*.key"
)

for pattern in "${REQUIRED_IGNORES[@]}"; do
  if grep -q "^$pattern$" "$REPO_ROOT/.gitignore" 2>/dev/null; then
    echo "  ✓ $pattern in .gitignore"
  else
    echo "  ⚠ $pattern not in .gitignore (may be intentional)"
  fi
done

echo ""

if [ $ERRORS -eq 0 ]; then
  echo "=== VALIDATION PASSED ==="
  echo "All ADRs are valid and consistent"
  exit 0
else
  echo "=== VALIDATION FAILED ==="
  echo "$ERRORS errors found"
  exit 1
fi
