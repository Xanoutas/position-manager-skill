# range-alerts.md — Out-of-Range Position Alerts

Monitor positions and alert when they drift out of range, stopping fee accrual.

## Out-of-Range Detection

```typescript
import DLMM from "@meteora-ag/dlmm";
import { Connection, PublicKey } from "@solana/web3.js";

interface RangeAlert {
  protocol: string;
  positionAddress: string;
  pool: string;
  status: "IN_RANGE" | "OUT_OF_RANGE_BELOW" | "OUT_OF_RANGE_ABOVE";
  currentPrice: number;
  lowerPrice: number;
  upperPrice: number;
  distanceToBoundaryPct: number; // how close to exiting range
  valueUSD?: number;
  recommendation: string;
}

async function checkDLMMRangeAlerts(
  connection: Connection,
  walletPubkey: PublicKey
): Promise<RangeAlert[]> {
  const positions = await DLMM.getPositionsByUser(connection, walletPubkey);
  const alerts: RangeAlert[] = [];

  for (const { publicKey, positionData } of positions) {
    const dlmmPool = await DLMM.create(connection, positionData.lbPair);
    const activeBin = await dlmmPool.getActiveBin();

    const lowerBinId = positionData.lowerBinId;
    const upperBinId = positionData.upperBinId;
    const currentBinId = activeBin.binId;

    const totalBins = upperBinId - lowerBinId;
    const binsFromLower = currentBinId - lowerBinId;
    const binsFromUpper = upperBinId - currentBinId;

    let status: RangeAlert["status"];
    let distanceToBoundaryPct: number;
    let recommendation: string;

    if (currentBinId < lowerBinId) {
      status = "OUT_OF_RANGE_BELOW";
      distanceToBoundaryPct = 0;
      recommendation =
        "Position fully in tokenX. Consider closing and reopening at current price, or wait for price recovery.";
    } else if (currentBinId > upperBinId) {
      status = "OUT_OF_RANGE_ABOVE";
      distanceToBoundaryPct = 0;
      recommendation =
        "Position fully in tokenY. Consider closing and reopening at current price, or wait for price reversal.";
    } else {
      status = "IN_RANGE";
      // Distance to nearest boundary as % of total range
      const nearestBoundaryDist = Math.min(binsFromLower, binsFromUpper);
      distanceToBoundaryPct = (nearestBoundaryDist / (totalBins / 2)) * 100;

      if (distanceToBoundaryPct < 10) {
        recommendation = `⚠️ WARNING: Only ${distanceToBoundaryPct.toFixed(1)}% from range boundary. Consider rebalancing soon.`;
      } else if (distanceToBoundaryPct < 25) {
        recommendation = `Price approaching ${binsFromLower < binsFromUpper ? "lower" : "upper"} boundary (${distanceToBoundaryPct.toFixed(1)}% away).`;
      } else {
        recommendation = "Position healthy, well within range.";
      }
    }

    const currentPrice = dlmmPool.fromPricePerLamport(
      Number(activeBin.price)
    );

    // Get boundary prices
    const lowerBin = await dlmmPool.getBinArrayForSwap(false);
    const upperBin = await dlmmPool.getBinArrayForSwap(true);

    alerts.push({
      protocol: "Meteora DLMM",
      positionAddress: publicKey.toBase58(),
      pool: positionData.lbPair.toBase58(),
      status,
      currentPrice,
      lowerPrice: 0, // computed from bin math
      upperPrice: 0,
      distanceToBoundaryPct,
      recommendation,
    });
  }

  return alerts;
}
```

## Discord / Telegram Alert Sender

```typescript
async function sendAlerts(alerts: RangeAlert[], webhookUrl: string) {
  const outOfRange = alerts.filter((a) => a.status !== "IN_RANGE");
  const nearBoundary = alerts.filter(
    (a) => a.status === "IN_RANGE" && a.distanceToBoundaryPct < 15
  );

  if (outOfRange.length === 0 && nearBoundary.length === 0) return;

  const lines = [
    `🚨 **Liquidity Position Alert** — ${new Date().toISOString()}`,
    "",
  ];

  for (const alert of outOfRange) {
    lines.push(
      `❌ OUT OF RANGE | ${alert.protocol} | \`${alert.positionAddress.slice(0, 8)}...\``
    );
    lines.push(`   ${alert.recommendation}`);
    lines.push("");
  }

  for (const alert of nearBoundary) {
    lines.push(
      `⚠️ NEAR BOUNDARY | ${alert.protocol} | \`${alert.positionAddress.slice(0, 8)}...\``
    );
    lines.push(`   ${alert.recommendation}`);
    lines.push("");
  }

  await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content: lines.join("
") }),
  });
}
```

## Cron Job Setup (systemd)

```ini
# /etc/systemd/system/position-alerts.service
[Unit]
Description=CLMM Position Range Alert Monitor
After=network.target

[Service]
Type=oneshot
WorkingDirectory=/root/position-manager-skill
ExecStart=/usr/bin/node dist/alerts.js
EnvironmentFile=/root/.env

# /etc/systemd/system/position-alerts.timer
[Unit]
Description=Run position alerts every 15 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

```bash
systemctl enable --now position-alerts.timer
```

## When to use this skill

- User asks "are my positions in range"
- User asks "set up alerts for my LP positions"
- Periodic monitoring (cron/timer)
