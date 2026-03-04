# Clawdmatey 🏴‍☠️🤖

**clawd-matey.eth**

**Clawdmatey** is an AI-powered DeFi treasury bot that claims Clanker creator fees for $YARR on Base and automatically reinvests them into a diversified on-chain portfolio — fully automated.

---

## 💰 Tokenomics & Buyback

### Buyback Mechanism
- **20% of all claimed fees** are used to buy YARR on the open market
- Creates constant buy pressure from trading activity
- Purchased YARR held in treasury

### Burn Mechanism  
- If treasury holds **>5% of YARR supply** → excess is burned
- Deflationary pressure when treasury grows
- Prevents treasury from becoming a whale

### Fee Source
- **57% creator share** of all YARR trading fees (Clanker v3)
- Fees accumulate in WETH + YARR
- Claimed hourly when >$10 threshold

### Net Effect
```
Trading Activity → Fees → Auto-Claim → 20% Buyback → Hold/Burn
                                     → 80% Diversify → Treasury Growth
```

---

## What It Does

Every hour:
1. Checks unclaimed Clanker creator fees for $YARR on Base
2. If fees ≥ $10: claims them, splits across the portfolio
3. Always: swaps 5% of treasury WETH into the portfolio
4. If holding >5% of YARR supply: burns only the excess above the 5% floor

## Portfolio Allocation

| Token | Chain | Split | Why | Contract |
|-------|-------|-------|-----|----------|
| **RED** | Base | 20% | AI agent ecosystem token | [`0x2e66...`](https://basescan.org/token/0x2e662015a501f066e043d64d04f77ffe551a4b07) |
| **GRT** | Arbitrum | 20% | The Graph — indexing infrastructure | [`0x9623...`](https://arbiscan.io/token/0x9623063377AD1B27544C965cCd7342f7EA7e88C7) |
| **WBTC** | Base | 20% | Bitcoin exposure, store of value | [`0x0555...`](https://basescan.org/token/0x0555E30da8f98308EdB960aa94C0Db47230d2B9c) |
| **CLAWD** | Base | 20% | AI agent ecosystem | [`0x9f86...`](https://basescan.org/token/0x9f86dB9fc6f7c9408e8Fda3Ff8ce4e78ac7a6b07) |
| **YARR** | Base | 20% | Buyback — own token | [`0x3097...`](https://basescan.org/token/0x309792e8950405f803c0e3f2c9083bdff4466ba3) |

## How It Works

```
Every hour (cron):
  1. Check Clanker fees for YARR on Base
     ├─ No fees / below $10 threshold
     │    └─ Sweep YARR → treasury
     │    └─ Swap 5% of treasury WETH into portfolio
     └─ Fees ≥ $10
          └─ Claim all fees (swap non-WETH to WETH)
          └─ Split WETH 20/20/20/20/20
          └─ Buy each token via Uniswap v3 / Clanker pools
               GRT: bridge WETH Base→Arbitrum via Across, then swap
               RED/YARR: Clanker pool router (custom AMM)
               WBTC/CLAWD: Uniswap v3 on Base
          └─ If >5% YARR supply held: burn excess above 5% floor
          └─ Swap 5% of treasury WETH into portfolio
```

## Running It

```bash
# Manual run
./scripts/fee-claim-and-buy.sh

# Dry run (simulates responses, no real transactions)
./scripts/fee-claim-and-buy.sh --dry-run
```

## Config (`config.json`)

```json
{
  "minThresholdUSD": 10,
  "wethFallbackMin": 1,
  "redSplitPct": 20,
  "grtSplitPct": 20,
  "wbtcSplitPct": 20,
  "clawdSplitPct": 20,
  "yarrSplitPct": 20,
  "yarrBurnThresholdPct": 5,
  "blockedContracts": ["0xca586c77e4753b343c76e50150abc4d410f6b011"]
}
```

## Stack

- [Bankr](https://bankr.bot) — Natural language DeFi execution (fee claims)
- [Uniswap v3](https://uniswap.org) — Direct on-chain swaps
- [Across Protocol](https://across.to) — Base → Arbitrum WETH bridge for GRT buys
- [Clanker](https://clanker.world) — YARR/RED token AMM (custom pool router)

## Security

- No private keys or API keys in this repo
- Credentials loaded from secure vault at runtime
- Blocked contract list in `config.json` prevents interaction with known honeypots
- See `.gitignore` for full exclusion list

## Follow Along

- ENS: [clawd-matey.eth](https://app.ens.domains/clawd-matey.eth)
- X: [@clawdmatey](https://x.com/clawdmatey)
- Token: [$YARR on Base](https://basescan.org/token/0x309792e8950405f803c0e3f2c9083bdff4466ba3)
- Runs log: `runs.md`
