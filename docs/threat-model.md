# Initial threat model

This is an incubator-stage threat model, not an audit.

## 1. Compromised attester

**Risk:** a valid signer publishes fabricated NAV, supply or settlement data.

**Current controls:** explicit attester identity, evidence hash, issuer rotation, replay prevention, independent on-chain consistency checks.

**Production direction:** multi-attester/threshold policy, hardware-backed keys, timelocked signer changes, regulated source accountability.

## 2. Replay or observation rollback

**Risk:** an old favorable statement is resubmitted.

**Controls:** strictly monotonic per-asset nonce and non-regressing `observedAt`.

## 3. Stale data

**Risk:** DeFi continues to increase exposure after reporting stops.

**Controls:** `maxAttestationAge` automatically sets a stale risk bit; no administrative transaction is needed for the flag to appear.

## 4. On-chain/off-chain supply divergence

**Risk:** administrator-reported supply differs from live token supply.

**Controls:** live `totalSupply()` comparison at read time. Mismatch is an independent risk bit.

## 5. Malicious/non-standard token read

**Risk:** token `totalSupply()` reverts, returns malformed data or attempts to make consumer health queries unusable.

**Controls:** low-level `staticcall`; failure becomes `TOKEN_UNREADABLE` rather than bubbling a revert to downstream protocols.

## 6. Redemption settlement delay

**Risk:** outstanding redemption requests remain unresolved beyond an agreed operating window.

**Controls:** attestation carries outstanding amount and oldest pending timestamp; the registry derives `REDEMPTION_DELAYED` after the configured SLA.

## 7. Administrative misuse

**Risk:** issuer or risk manager changes status improperly.

**Controls:** role separation and explicit events make authority and changes attributable. Consumers can additionally require independent attestation policies.

**Production direction:** timelocks, multisigs, threshold policies, dispute/evidence mechanisms.

## 8. Smart-account signature compatibility

Institutional operations frequently use multisigs/smart accounts. Signature verification uses OpenZeppelin `SignatureChecker`, supporting EOA ECDSA and ERC-1271 contract signatures.

## 9. Evidence availability

**Risk:** an evidence hash is preserved while the referenced source document disappears.

**Production direction:** content-addressed redundant storage, retention policies and permissioned/public evidence gateways.

## 10. Truth boundary

A cryptographically valid statement can still be economically false. RealSettle authenticates and reconciles reported state; it does not replace auditors, custodians, legal claims, valuation agents or regulators.
