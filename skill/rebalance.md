# rebalance.md — Rebalance Suggestions

Analyze out-of-range or inefficient positions and suggest optimal rebalancing strategies.

## Rebalance Decision Engine

```typescript
import DLMM, { StrategyType } from "@meteora-ag/dlmm";
import { BN } from "@coral-xyz/anchor";
import {
  Connection,
  PublicKey,
  VersionedTransaction,
  TransactionMessage,
} from "@solana/web3.js";

type RebalanceStrategy = "SPOT" | "CURVE" | "BID_ASK";

interface RebalancePlan {
  action: "CLOSE_AND_REOPEN" | "WIDEN_RANGE" | "SHIFT_RANGE" | "HOLD";
  reason: string;
  currentRange: { lower: number; upper: number };
  suggestedRange: { lower: number; upper: number };
  strategy: RebalanceStrategy;
  estimatedFeeAPR?: number;
  steps: string[];
}

function suggestRebalance(
  currentBinId: number,
  lowerBinId: number,
  upperBinId: number,
  volatility: "LOW" | "MEDIUM" | "HIGH",
  currentPrice: number,
  binStep: number // basis points
): RebalancePlan {
  const totalBins = upperBinId - lowerBinId;
  const isOutOfRange =
    currentBinId < lowerBinId || currentBinId > upperBinId;
  const binsFromCenter = Math.abs(
    currentBinId - Math.floor((lowerBinId + upperBinId) / 2)
  );
  const centeredness = 1 - binsFromCenter / (totalBins / 2);

  // Volatility-based range widths (in bins)
  const targetBins = {
    LOW: 20,
    MEDIUM: 40,
    HIGH: 80,
  }[volatility];

  const halfRange = Math.floor(targetBins / 2);
  const suggestedLower = currentBinId - halfRange;
  const suggestedUpper = currentBinId + halfRange;

  if (isOutOfRange) {
    return {
      action: "CLOSE_AND_REOPEN",
      reason: "Position is out of range — earning zero fees",
      currentRange: { lower: lowerBinId, upper: upperBinId },
      suggestedRange: { lower: suggestedLower, upper: suggestedUpper },
      strategy: volatility === "HIGH" ? "SPOT" : "CURVE",
      steps: [
        "1. Remove all liquidity from current position",
        "2. Claim accumulated fees",
        `3. Reopen position centered at bin ${currentBinId} with ±${halfRange} bins range`,
        `4. Use ${volatility === "HIGH" ? "SPOT" : "CURVE"} strategy for ${volatility} volatility`,
      ],
    };
  }

  if (centeredness < 0.3) {
    return {
      action: "SHIFT_RANGE",
      reason: `Price drifted to ${(centeredness * 100).toFixed(0)}% of center — consider shifting range`,
      currentRange: { lower: lowerBinId, upper: upperBinId },
      suggestedRange: { lower: suggestedLower, upper: suggestedUpper },
      strategy: "SPOT",
      steps: [
        "1. Remove liquidity",
        "2. Claim fees",
        `3. Reopen centered at current price bin ${currentBinId}`,
      ],
    };
  }

  return {
    action: "HOLD",
    reason: `Position is ${(centeredness * 100).toFixed(0)}% centered, earning fees`,
    currentRange: { lower: lowerBinId, upper: upperBinId },
    suggestedRange: { lower: lowerBinId, upper: upperBinId },
    strategy: "SPOT",
    steps: ["No action needed"],
  };
}
```

## Execute Rebalance (Meteora DLMM)

```typescript
async function rebalanceDLMMPosition(
  connection: Connection,
  wallet: PublicKey,
  positionAddress: PublicKey,
  plan: RebalancePlan,
  dlmmPool: DLMM,
  userKeypair: Keypair
) {
  const txs: VersionedTransaction[] = [];

  // Step 1: Remove all liquidity
  const { userPositions } = await dlmmPool.getPositionsByUserAndLbPair(wallet);
  const position = userPositions.find(
    (p) => p.publicKey.toBase58() === positionAddress.toBase58()
  );
  if (!position) throw new Error("Position not found");

  const binIdsToRemove = position.positionData.positionBinData.map(
    (b) => b.binId
  );
  const removeLiqTx = await dlmmPool.removeLiquidity({
    position: positionAddress,
    user: wallet,
    binIds: binIdsToRemove,
    liquiditiesBpsToRemove: binIdsToRemove.map(() => new BN(10000)), // 100%
    shouldClaimAndClose: true,
  });

  for (const tx of Array.isArray(removeLiqTx) ? removeLiqTx : [removeLiqTx]) {
    const { blockhash } = await connection.getLatestBlockhash();
    tx.recentBlockhash = blockhash;
    tx.feePayer = wallet;
    tx.sign(userKeypair);
    txs.push(
      new VersionedTransaction(
        new TransactionMessage({
          payerKey: wallet,
          recentBlockhash: blockhash,
          instructions: tx.instructions,
        }).compileToV0Message()
      )
    );
  }

  // Step 2: Reopen with suggested range
  const totalXAmount = new BN(/* available X */ 0);
  const totalYAmount = new BN(/* available Y */ 0);

  const addLiqTx = await dlmmPool.initializePositionAndAddLiquidityByStrategy({
    positionPubKey: positionAddress,
    user: wallet,
    totalXAmount,
    totalYAmount,
    strategy: {
      maxBinId: plan.suggestedRange.upper,
      minBinId: plan.suggestedRange.lower,
      strategyType: StrategyType.SpotBalanced,
    },
  });

  console.log(
    `Rebalance plan: ${plan.action} | ${plan.reason}
` +
      plan.steps.join("
")
  );

  return txs;
}
```

## Strategy Guide

| Market Condition | Strategy | Range Width |
|-----------------|----------|-------------|
| Stable pairs (USDC/USDT) | CURVE | Narrow (±5 bins) |
| Moderate volatility | SPOT | Medium (±20 bins) |
| High volatility | BID_ASK | Wide (±50 bins) |
| Trending market | BID_ASK | Asymmetric |

## When to use this skill

- User asks "should I rebalance my position"
- Position is out of range (load after range-alerts.md)
- User asks "what's the best strategy for this pool"
