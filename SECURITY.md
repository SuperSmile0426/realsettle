# Security Policy

RealSettle is an incubator-stage reference implementation and has **not been independently audited**.

Do not deploy the current contracts with production funds or use them as the sole control for real financial assets.

## Security properties currently targeted

- EIP-712 domain-separated attestations;
- EOA and ERC-1271 signer verification through OpenZeppelin `SignatureChecker`;
- strictly monotonic per-asset nonces;
- non-regressing observation timestamps;
- stale-data derivation without keeper/admin dependence;
- non-reverting token supply reads;
- independent risk flags rather than one ambiguous lifecycle state;
- role-separated registry/risk authorities;
- preserving redemption-request paths when new exposure is blocked.

## Reporting

Please report potential vulnerabilities privately to the project maintainer rather than opening a public exploit issue. A dedicated security contact will be published before any public production deployment.

A useful report should include affected component, technical description, reproduction steps or proof of concept, impact, and suggested mitigation if known.

See `docs/threat-model.md` for design assumptions and unresolved production risks.
