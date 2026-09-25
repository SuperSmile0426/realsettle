# Proposed Pharos incubator milestones

Each milestone produces a demonstrable artifact and avoids depending on a full institutional deployment from day one.

## Milestone 1 — Control-plane MVP on Pharos

**Target:** 4 weeks

Deliverables:

- EIP-712 attestations with EOA and ERC-1271 signer support;
- asset registry and role-separated administration;
- bitmask risk derivation for freshness, supply integrity, redemption delay and explicit asset status;
- safe token-read behavior that cannot turn a broken token into a consumer read-path revert;
- reference settlement coordinator proving new-exposure gating and exit-path preservation;
- Foundry unit/fuzz test suite and CI;
- verified Pharos test deployment with reproducible demo transactions.

Success metric: a demo RWA moves from healthy to stale/supply-mismatched/restricted state and a downstream consumer automatically blocks a new subscription without blocking a redemption request.

## Milestone 2 — USDC settlement and administrator adapters

**Target:** 4–6 weeks

Deliverables:

- native-USDC subscription/redemption settlement schema;
- normalized administrator/custodian adapter service;
- evidence retention/anchoring profile;
- TypeScript SDK + event indexer;
- reference operator dashboard/API.

Success metric: end-to-end demo from an administrator settlement event to normalized on-chain control state consumed by an application.

## Milestone 3 — RealFi protocol integration

**Target:** 4–6 weeks

Deliverables:

- reference ERC-4626/vault policy hook;
- lending-market policy hook;
- configurable consumer masks for stale, restricted, delayed-redemption and default conditions;
- integration specification for a Pharos RWA partner;
- first partner pilot target.

Success metric: a real or representative Pharos RWA integration changes protocol permissions from RealSettle state without issuer-specific logic in the consumer.

## Milestone 4 — Pharos-native specialized execution

**Target:** 6–8 weeks

Deliverables:

- WASM reconciliation worker prototype;
- multi-attester / threshold policy design;
- SPN-compatible reconciliation architecture prototype;
- invariant/fuzz expansion and external security review plan.

Success metric: demonstrate how reconciliation workloads can move beyond a single EVM contract while preserving canonical EVM-readable state for DeFi consumers.

## Incubator support requested

The highest-value support is:

- Pharos engineering guidance for WASM/SPN integration;
- access to a RealFi Alliance issuer, administrator, custodian or vault partner;
- native USDC/CCTP integration guidance;
- RWA legal/compliance mentorship;
- introductions for an external smart-contract/security architecture review before production use.
