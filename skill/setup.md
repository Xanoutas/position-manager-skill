# setup.md — Installation & Configuration

## Prerequisites

- Node.js >= 18
- npm or yarn
- Solana wallet with positions on Meteora DLMM / Orca / Raydium

## Install

```bash
git clone https://github.com/Xanoutas/position-manager-skill
cd position-manager-skill
npm install
cp .env.example .env
# Edit .env with your settings
npm run build
```

## .env Configuration

```bash
# Required
RPC_URL=https://mainnet.helius-rpc.com/?api-key=YOUR_KEY
WALLET_ADDRESS=YOUR_SOLANA_WALLET_ADDRESS

# Optional — for alerts
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
ALERT_INTERVAL_MINUTES=15

# Optional — P&L DB path (default: ~/.position-manager/pnl.db)
PNL_DB_PATH=/root/.position-manager/pnl.db

# Optional — price source
COINGECKO_API_KEY=YOUR_KEY
```

## Commands

```bash
# Show all open positions
npm run positions

# Check IL for all positions
npm run il

# Check range alerts
npm run alerts

# Get rebalance suggestions
npm run rebalance

# Show P&L report for a position
npm run pnl -- --position POSITION_ADDRESS

# Show portfolio summary
npm run portfolio

# Start background monitor (saves snapshots every 15min)
npm run monitor
```

## Systemd Service (background monitor)

```bash
# Install as systemd service
sudo cp systemd/position-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now position-monitor.service
sudo journalctl -u position-monitor -f
```

## Claude Code / Codex Integration

Add to your `.claude/settings.json`:

```json
{
  "skills": [
    "path/to/position-manager-skill/skill/SKILL.md"
  ]
}
```

Then in Claude Code:

```
/position-status       — show all positions
/position-alerts       — check out-of-range  
/position-rebalance    — get rebalance plan
/position-pnl          — show P&L report
```
