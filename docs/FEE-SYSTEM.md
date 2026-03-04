# YARR Fee System — Source of Truth

## Overview

YARR was deployed via **Clanker v3**, which uses **LpLockerv2** for fee distribution.

## Key Addresses

| Component | Address | Chain |
|-----------|---------|-------|
| YARR Token | `0x309792e8950405f803c0e3f2c9083bdff4466ba3` | Base |
| Creator Wallet | `0x8b59a7e24386d2265e9dfd6de59b4a6bbd5d1633` | Base |
| LpLockerv2 | `0xFd235968e65B0990584585763f837A5b5330e6DE` | Base |

## Fee Claiming

### Check Fees
```bash
bankr fees 0x8b59a7e24386d2265e9dfd6de59b4a6bbd5d1633
```

Output shows:
- **CLAIMABLE WETH** — pending fees to claim
- **CLAIMED WETH** — historical claims

### Claim Fees
Use natural language via Bankr (NOT `bankr claim` which only works for Bankr-launched tokens):

```bash
bankr "Claim all unclaimed fees from LpLockerv2 for YARR token (0x309792e8950405f803c0e3f2c9083bdff4466ba3) on Base. Creator wallet is 0x8b59a7e24386d2265e9dfd6de59b4a6bbd5d1633."
```

## What Doesn't Work

| Command | Why It Fails |
|---------|--------------|
| `bankr claim <wallet>` | Only works for Bankr-launched tokens |
| v4 ClankerFeeLocker | YARR is v3, not v4 |
| Direct LpLockerv2 calls | Need Bankr as intermediary |

## Portfolio Diversification (Stability-First Strategy)

After claiming (WETH + YARR):
1. **Sell all claimed YARR for WETH** — reduces volatility exposure
2. **Split total WETH 25% each into:**
   - **RED** (`0x2e662015a501f066e043d64d04f77ffe551a4b07`) — Base
   - **WBTC** (`0x0555E30da8f98308EdB960aa94C0Db47230d2B9c`) — Base  
   - **CLAWD** (`0x9f86dB9fc6f7c9408e8Fda3Ff8ce4e78ac7a6b07`) — Base
   - **WETH** — Reserve for gas + stability

**Why no YARR in the split?** YARR is volatile. We already earn YARR exposure through LP fees — converting to stable assets locks in gains from that volatility.

## Historical Claims

| Date | WETH Claimed | USD Value | TX |
|------|--------------|-----------|-----|
| 2026-03-04 | 1.2194 | ~$2,600 | (first claim) |
| 2026-03-04 | 0.0347 | ~$74 | `0x0fcd36790815f3beaa98bb1be00a2cf39069a692e187878b2f701f43bf4a1e46` |

## Automation

Treasury bot runs hourly via cron:
```bash
./treasury-bot.sh
```

Threshold: $10 minimum to trigger claim + diversification.
