# position-manager-skill

> Production-grade AI skill for managing concentrated liquidity positions on Solana.
> Built for the [Solana AI Kit](https://github.com/solanabr/solana-ai-kit).

## Problem

Concentrated liquidity positions (Meteora DLMM, Orca Whirlpools, Raydium CLMM) require
active management. Positions that drift out of range earn **zero fees** while still
carrying impermanent loss risk. Most builders lack tooling to:

- Know when positions go out of range
- Understand their real P&L (fees minus IL)
- Decide when and how to rebalance

This skill solves all three.

## Features

| Feature | Description |
|---------|-------------|
| **Position Tracking** | Fetch all open CLMM positions across Meteora, Orca, Raydium |
| **Impermanent Loss** | Real IL calculation accounting for concentrated liquidity math |
| **Range Alerts** | Discord/Telegram notifications when positions drift out of range |
| **Rebalance Engine** | Strategy suggestions (SPOT/CURVE/BID_ASK) based on volatility |
| **P&L Tracking** | SQLite persistence with historical snapshots and APR calculation |

## Install

```bash
git clone https://github.com/Xanoutas/position-manager-skill
cd position-manager-skill
chmod +x install.sh && ./install.sh
```

## Quick Start

```bash
cp .env.example .env
# Add RPC_URL and WALLET_ADDRESS

npm run positions    # show all positions
npm run alerts       # check out-of-range
npm run rebalance    # get suggestions
npm run portfolio    # P&L summary
```

## Claude Code Integration

```json
// .claude/settings.json
{
  "skills": ["path/to/position-manager-skill/skill/SKILL.md"]
}
```

Then use `/position-status`, `/position-alerts`, `/position-rebalance`, `/position-pnl`.

## Skill Structure

```
skill/
  SKILL.md                 ← entry point / routing
  positions.md             ← fetch open positions
  impermanent-loss.md      ← IL calculation
  range-alerts.md          ← out-of-range detection
  rebalance.md             ← rebalance suggestions
  pnl-tracker.md           ← SQLite P&L persistence
  setup.md                 ← install & config
agents/
  position-monitor-agent.md ← background monitor
commands/
  position-commands.md     ← /position-* slash commands
```

## Supported Protocols

- **Meteora DLMM** — `@meteora-ag/dlmm`
- **Orca Whirlpools** — `@orca-so/whirlpools-sdk`
- **Raydium CLMM** — `@raydium-io/raydium-sdk-v2`

## License

MIT
