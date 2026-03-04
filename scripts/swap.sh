#!/bin/bash
# Direct swap via Uniswap V3 SwapRouter using cast
# Usage: ./swap.sh <token_out_address> <amount_in_usd>

set -uo pipefail

# Load wallet config (don't log secrets!)
source /Users/marcusrein/clawd/skills/crypto-wallet/.env 2>/dev/null || {
  echo "Error: Could not load wallet env"
  exit 1
}

# Config
RPC_URL="https://mainnet.base.org"
WETH="0x4200000000000000000000000000000000000006"
SWAP_ROUTER="0x2626664c2603336E57B271c5C0b26F421741e481"  # Uniswap V3 SwapRouter02 on Base

TOKEN_OUT=$1
AMOUNT_USD=$2

# Get current ETH price
ETH_PRICE=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | cut -d: -f2)

# Calculate WETH amount (with 18 decimals)
AMOUNT_WETH=$(python3 -c "print(int($AMOUNT_USD / $ETH_PRICE * 10**18))")
echo "Swapping $AMOUNT_USD USD (~$AMOUNT_WETH wei WETH) for token $TOKEN_OUT"

# Check WETH balance first
BALANCE=$(cast call $WETH "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $RPC_URL 2>/dev/null || echo "0")
echo "WETH balance: $BALANCE"

if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
  echo "Error: No WETH balance"
  exit 1
fi

# First approve WETH to SwapRouter (if needed)
echo "Checking/setting approval..."
ALLOWANCE=$(cast call $WETH "allowance(address,address)(uint256)" $WALLET_ADDRESS $SWAP_ROUTER --rpc-url $RPC_URL 2>/dev/null || echo "0")

if [ "$ALLOWANCE" = "0" ] || [ -z "$ALLOWANCE" ]; then
  echo "Approving WETH..."
  cast send $WETH "approve(address,uint256)" $SWAP_ROUTER $(cast max-uint) \
    --mnemonic "$WALLET_MNEMONIC" \
    --rpc-url $RPC_URL \
    --gas-limit 100000 2>&1 | grep -E "transactionHash|status"
fi

# Execute swap via exactInputSingle
echo "Executing swap..."

# Try different fee tiers: 3000 (0.3%), 10000 (1%), 500 (0.05%)
for FEE in 3000 10000 500; do
  echo "Trying fee tier $FEE..."
  
  RESULT=$(cast send $SWAP_ROUTER \
    "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))" \
    "($WETH,$TOKEN_OUT,$FEE,$WALLET_ADDRESS,$AMOUNT_WETH,0,0)" \
    --mnemonic "$WALLET_MNEMONIC" \
    --rpc-url $RPC_URL \
    --gas-limit 300000 2>&1)
  
  TX_HASH=$(echo "$RESULT" | grep -oE "transactionHash\s+0x[a-f0-9]{64}" | grep -oE "0x[a-f0-9]{64}" || echo "")
  STATUS=$(echo "$RESULT" | grep -oE "status\s+[0-9]+" | grep -oE "[0-9]+" || echo "0")
  
  echo "transactionHash $TX_HASH"
  echo "status $STATUS"
  
  if [ "$STATUS" = "1" ]; then
    echo "SUCCESS: Swap completed!"
    exit 0
  fi
done

echo "FAILED: All fee tiers failed"
exit 1
