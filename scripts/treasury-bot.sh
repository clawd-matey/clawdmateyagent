#!/bin/bash
# Clawdmatey Treasury Bot — Simplified
#
# Flow:
#   1. Check fees via `bankr fees <wallet>`
#   2. If above threshold, claim via Bankr natural language
#   3. Split into portfolio: 20% each RED/GRT/WBTC/CLAWD/YARR
#
# Usage: ./treasury-bot.sh [--dry-run]

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
CREATOR_WALLET="0x8b59a7e24386d2265e9dfd6de59b4a6bbd5d1633"
YARR_TOKEN="0x309792e8950405f803c0e3f2c9083bdff4466ba3"
MIN_THRESHOLD_USD=10

# Portfolio tokens
RED_TOKEN="0x2e662015a501f066e043d64d04f77ffe551a4b07"
GRT_TOKEN="0x9623063377AD1B27544C965cCd7342f7EA7e88C7"  # Arbitrum
WBTC_TOKEN="0x0555E30da8f98308EdB960aa94C0Db47230d2B9c"
CLAWD_TOKEN="0x9f86dB9fc6f7c9408e8Fda3Ff8ce4e78ac7a6b07"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/$(date +%Y-%m-%d).log"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log() {
  local msg="[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
  echo "$msg" >&2
  echo "$msg" >> "$LOGFILE"
}

# ── Get ETH price ─────────────────────────────────────────────────────────────
get_eth_price() {
  curl -s "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd" | \
    grep -o '"usd":[0-9.]*' | cut -d: -f2
}

# ── Step 1: Check fees via bankr fees ─────────────────────────────────────────
log "═══ TREASURY BOT START ═══"
log "DRY_RUN=$DRY_RUN | threshold=\$$MIN_THRESHOLD_USD"

ETH_PRICE=$(get_eth_price)
log "ETH price: \$$ETH_PRICE"

log "Checking fees via 'bankr fees'..."
FEES_OUTPUT=$(bankr fees "$CREATOR_WALLET" 2>&1 || true)

# Parse claimable WETH from the box format (line after "CLAIMABLE WETH", before "pending")
# Format: │ 0.034666             │
CLAIMABLE_LINE=$(echo "$FEES_OUTPUT" | grep -A1 "CLAIMABLE WETH" | tail -1)
CLAIMABLE_WETH=$(echo "$CLAIMABLE_LINE" | sed 's/│//g' | awk '{print $1}' | grep -oE '^[0-9.]+$' || echo "0")
if [ -z "$CLAIMABLE_WETH" ]; then
  CLAIMABLE_WETH="0"
fi

CLAIMABLE_USD=$(echo "$CLAIMABLE_WETH $ETH_PRICE" | awk '{printf "%.2f", $1 * $2}')
log "Claimable: $CLAIMABLE_WETH WETH (\$$CLAIMABLE_USD)"

# ── Step 2: Threshold check ───────────────────────────────────────────────────
ABOVE_THRESHOLD=$(echo "$CLAIMABLE_USD $MIN_THRESHOLD_USD" | awk '{print ($1 >= $2) ? "yes" : "no"}')

if [ "$ABOVE_THRESHOLD" = "no" ]; then
  log "Below threshold (\$$CLAIMABLE_USD < \$$MIN_THRESHOLD_USD) — skipping"
  log "═══ DONE (below threshold) ═══"
  exit 0
fi

log "Above threshold — proceeding to claim"

# ── Step 3: Claim fees ────────────────────────────────────────────────────────
if [ "$DRY_RUN" = "true" ]; then
  log "[DRY RUN] Would claim fees from LpLockerv2"
  CLAIMED_WETH="$CLAIMABLE_WETH"
else
  log "Claiming fees via Bankr..."
  CLAIM_RESULT=$(bankr "Claim all unclaimed fees from LpLockerv2 for YARR token ($YARR_TOKEN) on Base. Creator wallet is $CREATOR_WALLET. Execute the claim transaction and tell me the tx hash." 2>&1 || true)
  log "Claim result: $CLAIM_RESULT"
  CLAIMED_WETH="$CLAIMABLE_WETH"
fi

CLAIMED_USD=$(echo "$CLAIMED_WETH $ETH_PRICE" | awk '{printf "%.2f", $1 * $2}')
log "Claimed: \$$CLAIMED_USD"

# ── Step 4: Calculate splits (20% each) ───────────────────────────────────────
SPLIT_USD=$(echo "$CLAIMED_USD" | awk '{printf "%.2f", $1 / 5}')
log "Split: \$$SPLIT_USD each to RED, GRT, WBTC, CLAWD, YARR"

# ── Step 5: Buy portfolio tokens (batched single call) ───────────────────────
if [ "$DRY_RUN" = "true" ]; then
  log "[DRY RUN] Would buy \$$SPLIT_USD each of RED, GRT, WBTC, CLAWD, YARR"
else
  log "Buying all 5 tokens in single batch..."
  BUY_RESULT=$(bankr "Execute these 5 buys using WETH on Base:
1. Buy \$$SPLIT_USD of RED ($RED_TOKEN) on Base
2. Buy \$$SPLIT_USD of GRT ($GRT_TOKEN) on Arbitrum (bridge if needed)
3. Buy \$$SPLIT_USD of WBTC ($WBTC_TOKEN) on Base
4. Buy \$$SPLIT_USD of CLAWD ($CLAWD_TOKEN) on Base
5. Buy \$$SPLIT_USD of YARR ($YARR_TOKEN) on Base

Execute all 5 transactions. Use Clanker pools where available. Report results." 2>&1 || true)
  log "Batch buy result: $(echo "$BUY_RESULT" | tail -10)"
fi

log "═══ TREASURY BOT COMPLETE ═══"
log "Claimed: \$$CLAIMED_USD | Split: \$$SPLIT_USD x5"
