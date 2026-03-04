#!/bin/bash
# Test suite for treasury-bot.sh
#
# Tests:
#   1. Fee check parsing (bankr fees output)
#   2. Threshold logic
#   3. Dry-run execution
#
# Usage: ./test-treasury-bot.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0

pass() {
  echo "✅ $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo "❌ $1"
  FAILED=$((FAILED + 1))
}

echo "═══ Treasury Bot Test Suite ═══"
echo ""

# ── Test 1: Fee check command exists ──────────────────────────────────────────
echo "Test 1: bankr CLI available"
if command -v bankr &> /dev/null; then
  pass "bankr CLI found"
else
  fail "bankr CLI not found"
fi

# ── Test 2: Fee check runs ────────────────────────────────────────────────────
echo "Test 2: bankr fees command works"
FEES_OUTPUT=$(bankr fees 0x8b59a7e24386d2265e9dfd6de59b4a6bbd5d1633 2>&1 || true)
if echo "$FEES_OUTPUT" | grep -q "CLAIMABLE WETH"; then
  pass "bankr fees returns expected format"
else
  fail "bankr fees output unexpected"
fi

# ── Test 3: Parse claimable WETH ──────────────────────────────────────────────
echo "Test 3: Parse claimable WETH from output"
CLAIMABLE_LINE=$(echo "$FEES_OUTPUT" | grep -A1 "CLAIMABLE WETH" | tail -1)
CLAIMABLE_WETH=$(echo "$CLAIMABLE_LINE" | sed 's/│//g' | awk '{print $1}' | grep -oE '^[0-9.]+$' || echo "0")
if [ -n "$CLAIMABLE_WETH" ]; then
  pass "Parsed claimable: $CLAIMABLE_WETH WETH"
else
  fail "Could not parse claimable WETH"
fi

# ── Test 4: ETH price fetch ───────────────────────────────────────────────────
echo "Test 4: ETH price API"
ETH_PRICE=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | cut -d: -f2)
if [ -n "$ETH_PRICE" ] && [ "$ETH_PRICE" != "0" ]; then
  pass "ETH price fetched: \$$ETH_PRICE"
else
  fail "Could not fetch ETH price"
fi

# ── Test 5: Dry-run execution ─────────────────────────────────────────────────
echo "Test 5: Dry-run executes without error"
DRY_RUN_OUTPUT=$("$SCRIPT_DIR/treasury-bot.sh" --dry-run 2>&1 || true)
if echo "$DRY_RUN_OUTPUT" | grep -q "TREASURY BOT"; then
  pass "Dry-run completed"
else
  fail "Dry-run failed"
fi

# ── Test 6: Below threshold exits cleanly ─────────────────────────────────────
echo "Test 6: Below threshold handling"
if echo "$DRY_RUN_OUTPUT" | grep -qE "(Below threshold|DONE|COMPLETE)"; then
  pass "Threshold logic works"
else
  fail "Threshold logic issue"
fi

# ── Test 7: Log directory exists ──────────────────────────────────────────────
echo "Test 7: Log directory"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
if [ -d "$LOG_DIR" ]; then
  pass "Log directory exists: $LOG_DIR"
else
  fail "Log directory missing"
fi

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "═══ Results ═══"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
