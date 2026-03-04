#!/bin/bash
# Uniswap V3 swap for WBTC/CLAWD using cast
# Usage: ./swap-v3.sh <token_symbol> <amount_usd>

set -o pipefail

source /Users/marcusrein/clawd/skills/crypto-wallet/.env 2>/dev/null || exit 1

RPC="https://mainnet.base.org"
ROUTER="0x2626664c2603336E57B271c5C0b26F421741e481"
WETH="0x4200000000000000000000000000000000000006"

TOKEN_SYM=${1:-""}
AMOUNT_USD=${2:-"0"}

# Token addresses
case "$TOKEN_SYM" in
  WBTC)  TOKEN_OUT="0x0555E30da8f98308EdB960aa94C0Db47230d2B9c" ;;
  CLAWD) TOKEN_OUT="0x9f86dB9fc6f7c9408e8Fda3Ff8ce4e78ac7a6b07" ;;
  *)     echo "Unknown token: $TOKEN_SYM (use WBTC or CLAWD)"; exit 1 ;;
esac

# Get ETH price and calculate amount
ETH_PRICE=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | cut -d: -f2)
AMOUNT_WEI=$(python3 -c "print(int($AMOUNT_USD / $ETH_PRICE * 10**18))")

echo "Swapping $AMOUNT_USD USD for $TOKEN_SYM via Uniswap v3"
echo "Amount: $AMOUNT_WEI wei WETH"

# Check balance
BAL=$(cast call $WETH "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $RPC)
echo "WETH balance: $BAL"

# Approve if needed
ALLOWANCE=$(cast call $WETH "allowance(address,address)(uint256)" $WALLET_ADDRESS $ROUTER --rpc-url $RPC)
if [ "$ALLOWANCE" = "0" ]; then
  echo "Approving..."
  cast send $WETH "approve(address,uint256)" $ROUTER $(cast max-uint) \
    --mnemonic "$WALLET_MNEMONIC" --rpc-url $RPC
fi

# Try fee tiers: 3000 (0.3%), 10000 (1%), 500 (0.05%)
for FEE in 3000 10000 500; do
  echo "Trying fee tier $FEE..."
  
  RESULT=$(cast send $ROUTER \
    "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))" \
    "($WETH,$TOKEN_OUT,$FEE,$WALLET_ADDRESS,$AMOUNT_WEI,0,0)" \
    --mnemonic "$WALLET_MNEMONIC" \
    --rpc-url $RPC \
    --gas-limit 300000 2>&1) || true
  
  if echo "$RESULT" | grep -q "status.*1"; then
    echo "SUCCESS"
    echo "$RESULT" | grep -E "transactionHash|status"
    exit 0
  fi
done

echo "FAILED: No liquidity pool found"
exit 1
