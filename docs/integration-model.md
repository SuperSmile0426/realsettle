# Integration model

RealSettle is middleware. Consumers decide policy; the registry supplies normalized state.

## Lending market

A lending market can block new collateral or borrowing when any configured blocking bit is present, while continuing to permit repayment and collateral exit.

```solidity
uint256 flags = registry.getRiskFlags(assetId);
if ((flags & BLOCKING_MASK) != 0) revert AssetNotEligibleForNewExposure(flags);
```

## RWA vault

Example policy:

- no flags -> deposits and strategy allocation enabled;
- stale or supply mismatch -> pause new deposits/allocations;
- redemption delayed -> reduce or stop new exposure, keep redemption processing active;
- restricted/default/recovery -> route into defensive policy;
- matured -> disable new exposure and run final settlement workflow.

## Settlement workflow

The reference `SettlementCoordinator` demonstrates this directly. A healthy subscription request succeeds. If the attestation later becomes stale, a new subscription reverts, but a redemption request can still be created.

## Administrator adapter

A fund administrator can produce signed structured observations from its normal operating records. Private/raw evidence can remain off-chain; the attestation commits to the exact source material with `evidenceHash`.

Logical payload:

```json
{
  "assetId": "0x...",
  "navE18": "1043200000000000000",
  "reportedSupply": "1000000000000000000000000",
  "outstandingRedemptions": "300000000000",
  "cumulativeSettledRedemptions": "1800000000000",
  "oldestPendingRedemptionAt": 1780000000,
  "observedAt": 1780003600,
  "nonce": 42,
  "evidenceHash": "0x..."
}
```

## Production integration goals

- native USDC settlement adapters;
- CCTP-aware settlement metadata where cross-chain cash movement is relevant;
- Chainlink-compatible market/reserve inputs;
- multi-attester / institutional signing policies;
- TypeScript SDK and event indexer;
- Pharos WASM/SPN reconciliation worker;
- first pilot with a real Pharos RWA issuer/vault.
