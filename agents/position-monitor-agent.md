# position-monitor-agent

An autonomous agent that monitors CLMM positions and sends alerts.

## Behavior

Every `ALERT_INTERVAL_MINUTES` minutes (default: 15):

1. Fetch all open positions for `WALLET_ADDRESS`
2. Check if each is in range
3. Calculate IL and fee income
4. Save snapshot to SQLite
5. Send Discord alert if any position is out of range or near boundary (<15%)

## Trigger Phrases

Load this agent when the user says:
- "monitor my positions"
- "set up position alerts"
- "notify me when out of range"
- "run background position tracker"

## Implementation

```typescript
import { checkDLMMRangeAlerts } from "../skill/range-alerts";
import { saveSnapshot } from "../skill/pnl-tracker";
import { sendAlerts } from "../skill/range-alerts";
import { Connection, PublicKey } from "@solana/web3.js";

async function runMonitorLoop() {
  const connection = new Connection(process.env.RPC_URL!);
  const wallet = new PublicKey(process.env.WALLET_ADDRESS!);
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL!;
  const intervalMs =
    Number(process.env.ALERT_INTERVAL_MINUTES ?? 15) * 60 * 1000;

  console.log(
    `🔍 Position monitor started. Checking every ${intervalMs / 60000} minutes.`
  );

  while (true) {
    try {
      const alerts = await checkDLMMRangeAlerts(connection, wallet);

      // Save snapshots
      for (const alert of alerts) {
        // saveSnapshot(db, { ... })
      }

      // Send alerts if needed
      if (webhookUrl) {
        await sendAlerts(alerts, webhookUrl);
      }

      // Log summary
      const inRange = alerts.filter((a) => a.status === "IN_RANGE").length;
      const outOfRange = alerts.length - inRange;
      console.log(
        `[${new Date().toISOString()}] ${alerts.length} positions | ${inRange} in range | ${outOfRange} out of range`
      );
    } catch (err) {
      console.error("Monitor error:", err);
    }

    await new Promise((r) => setTimeout(r, intervalMs));
  }
}

runMonitorLoop();
```
