# position-manager-skill

A production-grade AI skill for managing concentrated liquidity positions on Solana.
Covers Meteora DLMM, Orca Whirlpools, and Raydium CLMM — tracking P&L, impermanent loss,
out-of-range alerts, and rebalance suggestions.

## Routing

Load the focused skill file that matches your task:

| Task | Load |
|------|------|
| Track open positions / portfolio overview | [positions.md](positions.md) |
| Calculate impermanent loss | [impermanent-loss.md](impermanent-loss.md) |
| Check if positions are in range | [range-alerts.md](range-alerts.md) |
| Get rebalance suggestions | [rebalance.md](rebalance.md) |
| P&L tracking with SQLite | [pnl-tracker.md](pnl-tracker.md) |
| Full setup & install | [setup.md](setup.md) |

## Quick Start

```bash
# Install
git clone https://github.com/Xanoutas/position-manager-skill
cd position-manager-skill
chmod +x install.sh && ./install.sh

# Track positions
/position-status

# Check alerts
/position-alerts
```

## Supported Protocols

- **Meteora DLMM** — Dynamic Liquidity Market Maker (bin-based)
- **Orca Whirlpools** — Tick-based CLMM
- **Raydium CLMM** — Concentrated liquidity pools

## Dependencies

- Node.js >= 18
- `@meteora-ag/dlmm` SDK
- `@orca-so/whirlpools-sdk`
- `@raydium-io/raydium-sdk-v2`
- `@solana/web3.js`
- `better-sqlite3`
