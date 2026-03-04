#!/bin/bash
# Clanker pool swap for RED using cast
# Usage: ./swap-clanker.sh <amount_usd>
# RED uses Clanker's custom AMM router, not Uniswap v3

set -uo pipefail

source /Users/marcusrein/clawd/skills/crypto-wallet/.env 2>/dev/null || exit 1

RPC="https://mainnet.base.org"
CLANKER_ROUTER="0x21e99B325d53FE3d574ac948B9CB1519DA03E518"
WETH="0x4200000000000000000000000000000000000006"
RED="0x2e662015a501f066e043d64d04f77ffe551a4b07"

AMOUNT_USD=$1

# Get ETH price and calculate amount
ETH_PRICE=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | cut -d: -f2)
AMOUNT_WEI=$(python3 -c "print(int($AMOUNT_USD / $ETH_PRICE * 10**18))")

echo "Swapping $AMOUNT_USD USD for RED via Clanker"
echo "Amount: $AMOUNT_WEI wei (~$(python3 -c "print($AMOUNT_WEI/10**18)") ETH)"

# For Clanker, we need to wrap ETH to WETH first, then swap
# Or we can send native ETH to the router with the right calldata

# Check WETH balance
WETH_BAL=$(cast call $WETH "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $RPC)
echo "WETH balance: $WETH_BAL"

# Build the Clanker calldata
# Function: 0x0f27c5c1 (buy with specific pool params)
# This is decoded from actual RED buy transactions

DEADLINE=$(python3 -c "import time; print(int(time.time()) + 3600)")
RECIPIENT=$(echo $WALLET_ADDRESS | tr '[:upper:]' '[:lower:]')

# Generate calldata using Python (easier than bash for complex encoding)
CALLDATA=$(python3 << EOF
import sys

def pad_address(addr):
    return '0' * 24 + addr[2:].lower()

def u256(v):
    return format(v, '064x')

recipient = "$RECIPIENT"
deadline = $DEADLINE

# Clanker pool params (from RedBotster's script)
params = [
    u256(0),                                           # [0] amountOutMin
    u256(0x140),                                       # [1] offset  
    pad_address("0x7f77bad9eb06373fe3aee84f85a9d701ff820eeb"),  # [2]
    pad_address("0x571bb664cd515b533c2fe68a23367551f6fc559d"),  # [3] RED pool
    pad_address(recipient),                            # [4] recipient
    u256(0x0dac),                                      # [5] 3500
    u256(0x7d0),                                       # [6] 2000
    u256(0),                                           # [7]
    u256(0),                                           # [8]
    u256(deadline),                                    # [9] deadline
    u256(1),                                           # [10] array length
    u256(32),                                          # [11]
    pad_address("0x4200000000000000000000000000000000000006"),  # [12] WETH
    pad_address("0x2e662015a501f066e043d64d04f77ffe551a4b07"),  # [13] RED
    pad_address("0x6ff5693b99212da76ad316178a184ab56d299b43"),  # [14] Universal Router
    pad_address("0x0d5e0f971ed27fbff6c2837bf31316121532048d"),  # [15] hook
    u256(0x800000),                                    # [16]
    u256(0xc8),                                        # [17]
    pad_address("0xb429d62f8f3bffb98cdb9569533ea23bf0ba28cc"),  # [18] RED pool
    u256(0x100),                                       # [19]
    u256(0),                                           # [20]
]

calldata = "0x0f27c5c1" + "".join(params)
print(calldata)
EOF
)

echo "Executing Clanker swap..."

# Clanker uses native ETH, not WETH - need to unwrap first or use a different approach
# Actually, let's check if we need to approve WETH to Clanker router first

ALLOWANCE=$(cast call $WETH "allowance(address,address)(uint256)" $WALLET_ADDRESS $CLANKER_ROUTER --rpc-url $RPC)
if [ "$ALLOWANCE" = "0" ]; then
  echo "Approving Clanker router..."
  cast send $WETH "approve(address,uint256)" $CLANKER_ROUTER $(cast max-uint) \
    --mnemonic "$WALLET_MNEMONIC" --rpc-url $RPC
fi

# Send the transaction
RESULT=$(cast send $CLANKER_ROUTER \
  --mnemonic "$WALLET_MNEMONIC" \
  --rpc-url $RPC \
  --gas-limit 500000 \
  --value $AMOUNT_WEI \
  "$CALLDATA" 2>&1) || true

if echo "$RESULT" | grep -q "status.*1"; then
  echo "SUCCESS"
  echo "$RESULT" | grep -E "transactionHash|status"
  exit 0
else
  echo "FAILED"
  echo "$RESULT" | tail -10
  exit 1
fi
