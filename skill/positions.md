# positions.md — Track Open CLMM Positions

Fetch and display all open concentrated liquidity positions for a wallet across
Meteora DLMM, Orca Whirlpools, and Raydium CLMM.

## Meteora DLMM

```typescript
import DLMM from "@meteora-ag/dlmm";
import { Connection, PublicKey } from "@solana/web3.js";

const connection = new Connection(process.env.RPC_URL!);

async function getMeteoraDLMMPositions(walletPubkey: PublicKey) {
  // Get all DLMM positions for wallet
  const positions = await DLMM.getPositionsByUser(connection, walletPubkey);

  const result = [];
  for (const { publicKey, positionData, version } of positions) {
    const dlmmPool = await DLMM.create(connection, positionData.lbPair);
    const { tokenX, tokenY } = dlmmPool;

    // Get active bin (current price)
    const activeBin = await dlmmPool.getActiveBin();
    const currentPrice = dlmmPool.fromPricePerLamport(
      Number(activeBin.price)
    );

    // Get position bins
    const binData = positionData.positionBinData;
    const lowerBinId = positionData.lowerBinId;
    const upperBinId = positionData.upperBinId;

    const isInRange =
      activeBin.binId >= lowerBinId && activeBin.binId <= upperBinId;

    // Get amounts in position
    const { userPositions } = await dlmmPool.getPositionsByUserAndLbPair(
      walletPubkey
    );
    const pos = userPositions.find(
      (p) => p.publicKey.toBase58() === publicKey.toBase58()
    );

    result.push({
      protocol: "Meteora DLMM",
      address: publicKey.toBase58(),
      pool: positionData.lbPair.toBase58(),
      tokenX: tokenX.publicKey.toBase58(),
      tokenY: tokenY.publicKey.toBase58(),
      lowerBinId,
      upperBinId,
      activeBinId: activeBin.binId,
      currentPrice,
      isInRange,
      totalXAmount: pos?.positionData.totalXAmount.toString() ?? "0",
      totalYAmount: pos?.positionData.totalYAmount.toString() ?? "0",
      feeX: pos?.positionData.feeX.toString() ?? "0",
      feeY: pos?.positionData.feeY.toString() ?? "0",
    });
  }
  return result;
}
```

## Orca Whirlpools

```typescript
import {
  WhirlpoolContext,
  buildWhirlpoolClient,
  ORCA_WHIRLPOOL_PROGRAM_ID,
  PDAUtil,
  PoolUtil,
  TickUtil,
} from "@orca-so/whirlpools-sdk";
import { AnchorProvider } from "@coral-xyz/anchor";

async function getOrcaPositions(walletPubkey: PublicKey, connection: Connection) {
  const provider = AnchorProvider.env();
  const ctx = WhirlpoolContext.from(
    connection,
    provider.wallet,
    ORCA_WHIRLPOOL_PROGRAM_ID
  );
  const client = buildWhirlpoolClient(ctx);

  // Fetch all position token accounts
  const tokenAccounts = await connection.getParsedTokenAccountsByOwner(
    walletPubkey,
    { programId: new PublicKey("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA") }
  );

  const positions = [];
  for (const { account } of tokenAccounts.value) {
    const parsed = account.data.parsed.info;
    if (parsed.tokenAmount.amount !== "1") continue; // NFT check

    const positionPDA = PDAUtil.getPosition(
      ORCA_WHIRLPOOL_PROGRAM_ID,
      new PublicKey(parsed.mint)
    );

    try {
      const position = await client.getPosition(positionPDA.publicKey);
      const pool = await client.getPool(position.getData().whirlpool);
      const poolData = pool.getData();

      const isInRange =
        poolData.tickCurrentIndex >= position.getData().tickLowerIndex &&
        poolData.tickCurrentIndex <= position.getData().tickUpperIndex;

      positions.push({
        protocol: "Orca Whirlpool",
        address: positionPDA.publicKey.toBase58(),
        pool: position.getData().whirlpool.toBase58(),
        tickLower: position.getData().tickLowerIndex,
        tickUpper: position.getData().tickUpperIndex,
        tickCurrent: poolData.tickCurrentIndex,
        liquidity: position.getData().liquidity.toString(),
        isInRange,
        feeOwedA: position.getData().feeOwedA.toString(),
        feeOwedB: position.getData().feeOwedB.toString(),
      });
    } catch {
      // Not a whirlpool position
    }
  }
  return positions;
}
```

## Display All Positions

```typescript
async function getAllPositions(walletAddress: string) {
  const wallet = new PublicKey(walletAddress);
  const [meteora, orca] = await Promise.all([
    getMeteoraDLMMPositions(wallet),
    getOrcaPositions(wallet, connection),
  ]);

  const all = [...meteora, ...orca];

  console.log(`
📊 Open Positions (${all.length} total)
`);
  for (const pos of all) {
    const status = pos.isInRange ? "✅ IN RANGE" : "⚠️  OUT OF RANGE";
    console.log(`${status} | ${pos.protocol} | ${pos.address.slice(0, 8)}...`);
    if (pos.currentPrice) console.log(`  Price: ${pos.currentPrice}`);
  }

  return all;
}
```

## When to use this skill

- User asks "show my positions" or "what liquidity do I have"
- Before calculating IL or rebalancing
- For portfolio overview
