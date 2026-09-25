# RealSettle

**The RealFi control plane for Pharos.**

RealSettle converts asynchronous real-world asset operations—NAV publication, supply reconciliation, subscriptions, redemptions, maturity, restrictions, and settlement evidence—into canonical, machine-readable risk state that Pharos applications can enforce directly.

> **Status:** grant-stage MVP / reference implementation. Not audited and not intended for production funds.

## Why this exists

Tokenization is only the asset representation layer. Institutional RWAs continue to depend on fund administrators, custodians, transfer agents, settlement windows, redemption queues, valuation schedules, and off-chain cash movement while DeFi remains live 24/7.

That creates an operational state gap:

- an RWA can remain usable while its latest administrator data is stale;
- signed supply records can diverge from live token supply;
- redemption queues can exceed their expected settlement window;
- a restriction/default can occur before downstream DeFi reacts;
- every lending market or vault otherwise needs bespoke issuer-specific integrations.

RealSettle standardizes that gap into a shared control plane.

## Architectural role

```text
 Fund Administrator ─┐
 Custodian ───────────┼──► signed observations / evidence
 Issuer ──────────────┘
                             │
                             ▼
                  ┌────────────────────┐
                  │  RealSettle        │
                  │  Registry          │
                  │                    │
                  │  freshness         │
                  │  supply integrity  │
                  │  redemption SLA    │
                  │  status / default  │
                  │  evidence anchors  │
                  └─────────┬──────────┘
                            │ risk bitmask
                            ▼
                  ┌────────────────────┐
                  │ Settlement         │
                  │ Coordinator        │
                  └─────────┬──────────┘
                            │
                 ┌──────────┼──────────┐
                 ▼          ▼          ▼
              Lending     Vaults    RWA markets
                            │
                     Pharos EVM today
                  SPN/WASM scale path later
```

RealSettle does **not** change Pharos consensus. It adds a reusable application-infrastructure layer that can be consumed by many RealFi protocols and later move heavier reconciliation workloads into Pharos-native specialized execution.

## What is implemented now

### `RealSettleRegistry`

- EIP-712 structured administrator attestations.
- EOA **and ERC-1271 smart-account / multisig signer support**.
- Nonce replay protection and monotonic observation time.
- Configurable attestation-freshness policy.
- Safe live `totalSupply()` reconciliation using bounded failure handling instead of propagating token reverts to consumers.
- Independent redemption-delay detection.
- Role-separated registry/risk administration with issuer-controlled attester/policy updates.
- Stable bitmask risk output rather than strings or UI-specific judgments.
- Evidence hashes anchoring the exact source records behind each observation.

### `SettlementCoordinator`

A reference downstream consumer demonstrating architectural impact:

- healthy assets can accept new subscription operations;
- stale, mismatched, restricted, defaulted, delayed-redemption, or otherwise blocked assets automatically reject **new exposure**;
- redemption requests remain available during stressed states so the control plane does not accidentally lock the exit path;
- issuer-side settlement acknowledgements and evidence are recorded as an auditable workflow.

The coordinator is deliberately non-custodial in the MVP. It demonstrates how control-plane state changes protocol behavior without pretending to replace a regulated transfer agent, custodian, or paying agent.

## Risk flags

Downstream protocols consume a composable bitmask:

```text
UNKNOWN_ASSET
NO_ATTESTATION
STALE_ATTESTATION
TOKEN_UNREADABLE
SUPPLY_MISMATCH
RESTRICTED
DEFAULTED
MATURED
REDEMPTION_DELAYED
RECOVERY
```

This allows each protocol to define its own policy while depending on one normalized state source.

Example:

```solidity
uint256 flags = registry.getRiskFlags(assetId);
(bool allowed,) = coordinator.canIncreaseExposure(assetId);
```

A lending protocol can block new borrowing while still allowing repayment and collateral exit. A vault can pause new deposits without disabling redemptions.

## Why Pharos

RealSettle is designed for Pharos's RealFi architecture rather than as a generic dashboard:

1. **EVM composability now** — existing Solidity protocols can consume the registry immediately.
2. **USDC settlement path** — asset configuration explicitly names the settlement asset, with native USDC-oriented subscription/redemption adapters planned next.
3. **WASM computation path** — heavier reconciliation and institutional rules can move out of consumer contracts.
4. **SPN path** — high-frequency or privacy-sensitive reconciliation can eventually execute in a specialized Pharos environment while publishing canonical EVM-readable state.
5. **Compliance-aware workflows** — RealSettle complements identity/compliance infrastructure by standardizing the financial-operation state that happens after an asset is issued.

## Repository layout

```text
src/
  RealSettleRegistry.sol
  RiskFlags.sol
  SettlementCoordinator.sol
  interfaces/
    IRealSettleRegistry.sol
script/
  Deploy.s.sol
test/
  RealSettleRegistry.t.sol
docs/
  architecture.md
  settlement-lifecycle.md
  integration-model.md
  grant-milestones.md
  threat-model.md
```

## Build and test

Requires Foundry. CI installs OpenZeppelin Contracts and `forge-std` automatically.

```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0
forge build
forge test -vvv
```

The tests cover signature/replay controls, ERC-1271 attesters, stale data, supply mismatch, unreadable token contracts, redemption delays, operational restrictions, and the reference consumer's new-exposure/exit behavior.

## Incubator milestones

1. **Grant MVP + Pharos deployment** — registry, risk flags, settlement coordinator, verified test deployment.
2. **USDC settlement adapters** — subscription/redemption references, normalized administrator events, evidence trail.
3. **Protocol integration** — reference vault/lending hooks, SDK/indexer, first RealFi partner pilot.
4. **Pharos-native scale path** — WASM reconciliation worker, multi-attester policies, SPN-compatible execution prototype and external security review preparation.

See [`docs/grant-milestones.md`](docs/grant-milestones.md).

## Trust boundary

RealSettle does **not** claim that a signed off-chain statement is objective truth. It verifies who signed it, sequencing, freshness, consistency with observable on-chain state, operational delay conditions, and the evidence commitment associated with it.

Issuer solvency, legal enforceability, regulated custody, valuation methodology, and the real-world correctness of source data remain external responsibilities.

## Security

Pre-audit prototype. Do not use with production funds. See [`SECURITY.md`](SECURITY.md) and [`docs/threat-model.md`](docs/threat-model.md).

## License

MIT
