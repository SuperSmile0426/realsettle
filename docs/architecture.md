# Architecture

## Thesis

RealSettle is the **RealFi control plane** between real-world financial operations and Pharos protocols that need deterministic state before they take risk.

The data plane already exists across issuers, administrators, custodians, oracles, token contracts, settlement assets, and Pharos applications. The missing architectural primitive is a normalized state layer answering: **is this asset operationally safe enough for this action right now?**

## Separation of responsibilities

1. **External financial parties establish facts.** Issuers, custodians, fund administrators, transfer agents and paying agents remain responsible for the real-world financial system.
2. **Attesters authenticate observations.** RealSettle verifies EIP-712 signatures from EOAs or ERC-1271 smart accounts, freshness, sequencing and evidence commitments.
3. **Reconciliation derives deterministic risk flags.** The registry compares signed claims with observable chain state and time-based policy.
4. **Consumers enforce policy.** Lending markets, vaults and settlement applications choose which flags block which actions.
5. **Exit paths remain distinct from new exposure.** The reference coordinator blocks unhealthy subscriptions but preserves redemption requests.

## Components

### RealSettleRegistry

Per asset it stores:

- issuer;
- token contract;
- settlement asset;
- attester;
- freshness window;
- redemption-delay window;
- metadata commitment;
- canonical asset status;
- latest signed operational snapshot.

The snapshot includes NAV, reported supply, outstanding redemptions, cumulative settled redemptions, the oldest pending redemption timestamp, observation time, nonce and evidence hash.

### Risk derivation

`getRiskFlags(assetId)` returns a bitmask. A failing/non-standard token `totalSupply()` call becomes `TOKEN_UNREADABLE` rather than reverting the consumer's read path.

Risk signals are independent and composable. An asset can be both stale and restricted, or both supply-mismatched and redemption-delayed.

### SettlementCoordinator

The coordinator proves the control plane has execution consequences. New subscription requests are rejected whenever the default blocking mask is non-zero, while redemptions are still requestable during stress.

It also records request/acknowledgement/settlement/failure evidence without claiming to replace regulated off-chain settlement infrastructure.

## Pharos deployment path

### Phase A — EVM-native control plane

Deploy the registry and reference consumers directly on Pharos so Solidity protocols can integrate immediately.

### Phase B — USDC and administrator adapters

Normalize native-USDC settlement references, administrator/custodian events and evidence into the registry schema.

### Phase C — WASM computation

Move higher-cost reconciliation, document normalization and specialized risk computation into WASM-compatible workers/modules while keeping the canonical output EVM-readable.

### Phase D — specialized processing / SPN

For high-frequency institutional workflows, run reconciliation in a Pharos specialized execution environment and anchor the canonical control state back to mainnet. RealSettle starts without core-protocol modification, then takes advantage of Pharos modularity as workload and partner requirements justify it.

## Trust model

RealSettle proves authentication and consistency, not objective off-chain truth. It can prove:

- which authorized attester signed a statement;
- whether that signer is an EOA or approved smart-account/multisig;
- that observations are sequenced and non-replayed;
- whether an observation is still fresh;
- whether live token supply reconciles with the signed report;
- whether a redemption queue has exceeded the configured operational window;
- which evidence commitment was bound to the state.

It cannot independently prove issuer solvency, legal enforceability, custody quality, valuation correctness or asset existence.
