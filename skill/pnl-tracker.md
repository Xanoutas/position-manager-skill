# pnl-tracker.md — P&L Tracking with SQLite

Persist position snapshots, track historical P&L, and generate performance reports.

## Database Schema

```typescript
import Database from "better-sqlite3";
import path from "path";

const DB_PATH = process.env.PNL_DB_PATH ?? path.join(process.env.HOME!, ".position-manager", "pnl.db");

function initDB(): Database.Database {
  const db = new Database(DB_PATH);

  db.exec(`
    CREATE TABLE IF NOT EXISTS positions (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      address       TEXT NOT NULL UNIQUE,
      protocol      TEXT NOT NULL,          -- 'meteora_dlmm' | 'orca' | 'raydium'
      pool          TEXT NOT NULL,
      token_x       TEXT NOT NULL,
      token_y       TEXT NOT NULL,
      opened_at     INTEGER NOT NULL,       -- unix timestamp
      closed_at     INTEGER,
      status        TEXT DEFAULT 'open'     -- 'open' | 'closed'
    );

    CREATE TABLE IF NOT EXISTS snapshots (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      position_addr   TEXT NOT NULL,
      timestamp       INTEGER NOT NULL,
      token_x_amount  REAL NOT NULL,
      token_y_amount  REAL NOT NULL,
      fee_x           REAL NOT NULL DEFAULT 0,
      fee_y           REAL NOT NULL DEFAULT 0,
      price_x_usd     REAL NOT NULL,
      price_y_usd     REAL NOT NULL,
      value_usd       REAL NOT NULL,
      hodl_value_usd  REAL NOT NULL,
      il_usd          REAL NOT NULL DEFAULT 0,
      fee_income_usd  REAL NOT NULL DEFAULT 0,
      net_pnl_usd     REAL NOT NULL DEFAULT 0,
      is_in_range     INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (position_addr) REFERENCES positions(address)
    );

    CREATE TABLE IF NOT EXISTS rebalances (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      position_addr TEXT NOT NULL,
      timestamp     INTEGER NOT NULL,
      action        TEXT NOT NULL,
      old_lower     INTEGER,
      old_upper     INTEGER,
      new_lower     INTEGER,
      new_upper     INTEGER,
      gas_cost_sol  REAL,
      FOREIGN KEY (position_addr) REFERENCES positions(address)
    );

    CREATE INDEX IF NOT EXISTS idx_snapshots_pos ON snapshots(position_addr, timestamp);
  `);

  return db;
}
```

## Snapshot a Position

```typescript
interface SnapshotInput {
  positionAddr: string;
  tokenXAmount: number;
  tokenYAmount: number;
  feeX: number;
  feeY: number;
  priceXusd: number;
  priceYusd: number;
  isInRange: boolean;
  entrySnapshot?: SnapshotInput; // for IL calculation
}

function saveSnapshot(db: Database.Database, input: SnapshotInput) {
  const valueUSD =
    input.tokenXAmount * input.priceXusd +
    input.tokenYAmount * input.priceYusd;

  const feeIncomeUSD =
    input.feeX * input.priceXusd + input.feeY * input.priceYusd;

  let ilUSD = 0;
  let hodlValueUSD = valueUSD;

  if (input.entrySnapshot) {
    hodlValueUSD =
      input.entrySnapshot.tokenXAmount * input.priceXusd +
      input.entrySnapshot.tokenYAmount * input.priceYusd;
    ilUSD = hodlValueUSD - (valueUSD - feeIncomeUSD);
  }

  const netPnlUSD = feeIncomeUSD - ilUSD;

  db.prepare(`
    INSERT INTO snapshots
      (position_addr, timestamp, token_x_amount, token_y_amount,
       fee_x, fee_y, price_x_usd, price_y_usd, value_usd,
       hodl_value_usd, il_usd, fee_income_usd, net_pnl_usd, is_in_range)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    input.positionAddr,
    Math.floor(Date.now() / 1000),
    input.tokenXAmount,
    input.tokenYAmount,
    input.feeX,
    input.feeY,
    input.priceXusd,
    input.priceYusd,
    valueUSD,
    hodlValueUSD,
    ilUSD,
    feeIncomeUSD,
    netPnlUSD,
    input.isInRange ? 1 : 0
  );

  return { valueUSD, ilUSD, feeIncomeUSD, netPnlUSD };
}
```

## P&L Report

```typescript
function generatePnlReport(db: Database.Database, positionAddr: string) {
  const snapshots = db.prepare(`
    SELECT * FROM snapshots
    WHERE position_addr = ?
    ORDER BY timestamp ASC
  `).all(positionAddr) as any[];

  if (snapshots.length === 0) {
    return "No snapshots found for this position.";
  }

  const first = snapshots[0];
  const last = snapshots[snapshots.length - 1];

  const outOfRangeCount = snapshots.filter((s) => !s.is_in_range).length;
  const outOfRangePct = ((outOfRangeCount / snapshots.length) * 100).toFixed(1);

  const durationDays = (last.timestamp - first.timestamp) / 86400;
  const annualizedPnl =
    durationDays > 0
      ? (last.net_pnl_usd / first.value_usd) * (365 / durationDays) * 100
      : 0;

  return `
📊 P&L Report — ${positionAddr.slice(0, 8)}...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Duration:        ${durationDays.toFixed(1)} days
Snapshots:       ${snapshots.length}
Out-of-Range:    ${outOfRangePct}% of time

Initial Value:   $${first.value_usd.toFixed(2)}
Current Value:   $${last.value_usd.toFixed(2)}
HODL Value:      $${last.hodl_value_usd.toFixed(2)}

Fee Income:      +$${last.fee_income_usd.toFixed(2)}
Imperm. Loss:    -$${last.il_usd.toFixed(2)}
Net P&L:         ${last.net_pnl_usd >= 0 ? "+" : ""}$${last.net_pnl_usd.toFixed(2)}
Annualized:      ${annualizedPnl.toFixed(1)}% APR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  `.trim();
}
```

## Portfolio Summary

```typescript
function portfolioSummary(db: Database.Database) {
  const summary = db.prepare(`
    SELECT
      COUNT(DISTINCT position_addr) as positions,
      SUM(value_usd) as total_value,
      SUM(fee_income_usd) as total_fees,
      SUM(il_usd) as total_il,
      SUM(net_pnl_usd) as total_pnl
    FROM snapshots s
    INNER JOIN (
      SELECT position_addr, MAX(timestamp) as max_ts
      FROM snapshots GROUP BY position_addr
    ) latest ON s.position_addr = latest.position_addr
              AND s.timestamp = latest.max_ts
  `).get() as any;

  console.log(`
💼 Portfolio Summary
━━━━━━━━━━━━━━━━━━━━━
Positions:    ${summary.positions}
Total Value:  $${summary.total_value?.toFixed(2) ?? "0.00"}
Total Fees:   +$${summary.total_fees?.toFixed(2) ?? "0.00"}
Total IL:     -$${summary.total_il?.toFixed(2) ?? "0.00"}
Net P&L:      ${(summary.total_pnl ?? 0) >= 0 ? "+" : ""}$${summary.total_pnl?.toFixed(2) ?? "0.00"}
  `);
}
```

## When to use this skill

- User asks "how has my position performed"
- User asks "show me my total P&L"
- After IL calculation to persist results
