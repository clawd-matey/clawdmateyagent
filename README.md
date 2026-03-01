# RedBotster 🤖🔥

**RedBotster** is an AI-powered DeFi treasury bot running on [OpenClaw](https://openclaw.ai) that claims Clanker creator fees for $RED on Base and automatically reinvests them into a diversified on-chain portfolio — every hour, fully automated.

## What It Does

Every hour:
1. Checks unclaimed Clanker creator fees for $RED on Base
2. If fees ≥ $10: claims them, splits across the portfolio, sweeps RED to punkwallet
3. Always: swaps 5% of punkwallet WETH into the portfolio
4. If holding >10% of RED supply: burns only the excess above the 10% floor

## Portfolio Allocation

| Token | Chain | Split | Contract |
|-------|-------|-------|----------|
| RED | Base | 20% | [`0x2e662015a501f066e043d64d04f77ffe551a4b07`](https://basescan.org/token/0x2e662015a501f066e043d64d04f77ffe551a4b07) |
| GRT | Arbitrum | 20% | [`0x9623063377AD1B27544C965cCd7342f7EA7e88C7`](https://arbiscan.io/token/0x9623063377AD1B27544C965cCd7342f7EA7e88C7) |
| WBTC | Base | 20% | [`0x0555E30da8f98308EdB960aa94C0Db47230d2B9c`](https://basescan.org/token/0x0555E30da8f98308EdB960aa94C0Db47230d2B9c) |
| LINK | Base | 20% | [`0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196`](https://basescan.org/token/0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196) |
| CLAWD | Base | 20% | [`0x9f86dB9fc6f7c9408e8Fda3Ff8ce4e78ac7a6b07`](https://basescan.org/token/0x9f86dB9fc6f7c9408e8Fda3Ff8ce4e78ac7a6b07) |

## How It Works

```
Every hour (cron):
  1. Check Clanker fees for RED on Base
     ├─ No fees / below $10 threshold
     │    └─ Sweep RED → punkwallet
     │    └─ Swap 5% of punkwallet WETH into portfolio
     └─ Fees ≥ $10
          └─ Claim all fees (swap non-WETH to WETH)
          └─ Split WETH 20/20/20/20/20
          └─ Buy each token via Uniswap v3 (private key, no intermediary)
               GRT: bridge WETH Base→Arbitrum via Across, then swap
               RED: Clanker pool router (custom AMM)
               WBTC/LINK/CLAWD: Uniswap v3 on Base
          └─ If >10% RED supply held: burn excess above 10% floor
          └─ Sweep RED from agent wallet → punkwallet
          └─ Swap 5% of punkwallet WETH into portfolio
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
  "grtSplitPct": 20,
  "wbtcSplitPct": 20,
  "clawdSplitPct": 20,
  "redSplitPct": 20,
  "linkSplitPct": 20,
  "redBurnThresholdPct": 10,
  "blockedContracts": ["0xca586c77e4753b343c76e50150abc4d410f6b011"]
}
```

## Stack

- [OpenClaw](https://openclaw.ai) — AI agent runtime + secret vault
- [Bankr](https://bankr.bot) — Natural language DeFi execution (fee claims)
- [Uniswap v3](https://uniswap.org) — Direct on-chain swaps via punkwallet private key
- [Across Protocol](https://across.to) — Base → Arbitrum WETH bridge for GRT buys
- [Clanker](https://clanker.world) — RED token AMM (custom pool router)

## Security

- No private keys or API keys in this repo
- 1claw vault credentials loaded from `~/.openclaw/redbotster.env` at runtime
- Blocked contract list in `config.json` prevents interaction with known honeypots
- See `.gitignore` for full exclusion list

## Follow Along

- X: [@redbotster](https://x.com/redbotster)
- Token: [RED on Dexscreener](https://dexscreener.com/base/0x2e662015a501f066e043d64d04f77ffe551a4b07)
- Runs log: `runs.md`
