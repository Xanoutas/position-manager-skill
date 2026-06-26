# /position-status

Show all open CLMM positions for the configured wallet.

Load: skill/positions.md

Steps:
1. Read WALLET_ADDRESS from .env
2. Fetch all Meteora DLMM positions
3. Fetch all Orca Whirlpool positions  
4. Display table with: protocol, pool, range, current price, in/out status, value USD

---

# /position-alerts

Check all positions for out-of-range status and boundary proximity.

Load: skill/range-alerts.md

Steps:
1. Run checkDLMMRangeAlerts() for wallet
2. Display ✅/⚠️/❌ status per position
3. Show recommendation for each

---

# /position-rebalance

Get rebalance suggestions for all positions.

Load: skill/range-alerts.md, skill/rebalance.md

Steps:
1. Get range status for all positions
2. For out-of-range or near-boundary positions, run suggestRebalance()
3. Display action plan with steps

---

# /position-pnl [address]

Show P&L report for a specific position or all positions.

Load: skill/pnl-tracker.md, skill/impermanent-loss.md

Steps:
1. If address provided: show report for that position
2. If no address: show portfolio summary
3. Display fee income, IL, and net P&L
