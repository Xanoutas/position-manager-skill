# impermanent-loss.md — Impermanent Loss Calculation

Calculate real impermanent loss for CLMM positions, accounting for concentrated
liquidity math (IL in CLMMs differs significantly from xy=k pools).

## Concept

In concentrated liquidity, IL depends on:
1. Whether the current price is within the position range
2. The ratio of assets at entry vs now
3. Fee income accumulated (which offsets IL)

**Net P&L = Fee Income − Impermanent Loss**

## DLMM IL Calculation

```typescript
import DLMM, { LbPosition } from "@meteora-ag/dlmm";
import { BN } from "@coral-xyz/anchor";

interface PositionSnapshot {
  timestamp: number;
  tokenXAmount: number;   // in decimals
  tokenYAmount: number;
  priceXinY: number;      // price of X denominated in Y
  valueUSD: number;
}

interface ILResult {
  ilPercent: number;       // IL as % of initial value
  ilUSD: number;           // IL in USD
  feeIncomeUSD: number;    // Fees collected
  netPnlUSD: number;       // feeIncomeUSD - ilUSD
  hodlValueUSD: number;    // Value if just held tokens
  currentValueUSD: number; // Actual position value now
}

async function calculateDLMMImpermanentLoss(
  connection: Connection,
  positionAddress: PublicKey,
  entrySnapshot: PositionSnapshot,
  tokenPrices: { x: number; y: number } // current prices in USD
): Promise<ILResult> {
  // Fetch current position state
  const dlmmPositions = await DLMM.getPositionsByUser(
    connection,
    positionAddress
  );

  // Find position
  const posEntry = dlmmPositions.find(
    (p) => p.publicKey.toBase58() === positionAddress.toBase58()
  );
  if (!posEntry) throw new Error("Position not found");

  const { positionData } = posEntry;
  const currentXAmount =
    Number(positionData.totalXAmount) / 10 ** 6; // adjust for decimals
  const currentYAmount =
    Number(positionData.totalYAmount) / 10 ** 6;

  const feeX = Number(positionData.feeX) / 10 ** 6;
  const feeY = Number(positionData.feeY) / 10 ** 6;

  // Current position value
  const currentValueUSD =
    currentXAmount * tokenPrices.x + currentYAmount * tokenPrices.y;

  // Fee income in USD
  const feeIncomeUSD =
    feeX * tokenPrices.x + feeY * tokenPrices.y;

  // HODL value: if we had just held the initial amounts
  const hodlValueUSD =
    entrySnapshot.tokenXAmount * tokenPrices.x +
    entrySnapshot.tokenYAmount * tokenPrices.y;

  // IL = HODL value - current position value (before fees)
  const ilUSD = hodlValueUSD - (currentValueUSD - feeIncomeUSD);
  const ilPercent = (ilUSD / entrySnapshot.valueUSD) * 100;

  return {
    ilPercent,
    ilUSD,
    feeIncomeUSD,
    netPnlUSD: feeIncomeUSD - ilUSD,
    hodlValueUSD,
    currentValueUSD,
  };
}
```

## Price Impact Formula (concentrated liquidity)

For a position with price range [Pa, Pb] and current price P:

```
If P < Pa (below range): position is 100% tokenX
If P > Pb (above range): position is 100% tokenY  
If Pa <= P <= Pb: mixed, amounts determined by sqrt(P) math

IL = 2*sqrt(P/P0) / (1 + P/P0) - 1
```

Where P0 is the entry price. This is the standard xy=k IL formula —
in CLMM the effective IL is amplified by the concentration factor.

```typescript
function concentratedIL(
  entryPrice: number,
  currentPrice: number,
  lowerPrice: number,
  upperPrice: number
): number {
  const priceRatio = currentPrice / entryPrice;

  if (currentPrice <= lowerPrice) {
    // All in tokenX — IL = (sqrt(lowerPrice/entryPrice) - 1)
    return Math.sqrt(lowerPrice / entryPrice) - 1;
  }
  if (currentPrice >= upperPrice) {
    // All in tokenY — IL = (entryPrice/upperPrice - 1)  
    return entryPrice / upperPrice - 1;
  }

  // In range — standard IL formula amplified by concentration
  const sqrtRatio = Math.sqrt(priceRatio);
  return (2 * sqrtRatio) / (1 + priceRatio) - 1;
}
```

## Display IL Report

```typescript
function displayILReport(result: ILResult, positionId: string) {
  const sign = result.netPnlUSD >= 0 ? "+" : "";
  console.log(`
📉 Impermanent Loss Report
Position: ${positionId.slice(0, 8)}...

  HODL Value:       $${result.hodlValueUSD.toFixed(2)}
  Position Value:   $${result.currentValueUSD.toFixed(2)}
  Fee Income:       +$${result.feeIncomeUSD.toFixed(2)}
  IL:               -$${result.ilUSD.toFixed(2)} (${result.ilPercent.toFixed(2)}%)
  ─────────────────────────────
  Net P&L:          ${sign}$${result.netPnlUSD.toFixed(2)}
  `);
}
```

## When to use this skill

- User asks "how much IL do I have"
- User asks "is my position profitable"
- Before deciding to close or rebalance a position
