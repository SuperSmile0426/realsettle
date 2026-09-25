# Settlement and asset lifecycle model

The first prototype used one lifecycle enum for conditions such as `COUPON_DUE`, `REDEMPTION_PENDING`, and `DEFAULTED`. That model was intentionally replaced because real financial conditions overlap: an active asset can have both a coupon due and pending redemptions at the same time.

RealSettle v0.2 therefore separates **asset status** from **operational risk flags**.

## Asset status

| Status | Meaning |
|---|---|
| `ACTIVE` | Asset is operating normally |
| `RESTRICTED` | Operational or compliance restriction is in force |
| `DEFAULTED` | Default/impairment has been declared |
| `RECOVERY` | Asset is in workout/remediation |
| `MATURED` | Asset reached final maturity |

Status is explicit and administratively attributable.

## Independent risk flags

Risk flags derive from live/signed state and can coexist:

- no accepted attestation;
- stale attestation;
- token supply unreadable;
- live/report supply mismatch;
- redemption queue delayed beyond policy;
- restricted/default/recovery/maturity status.

This is more expressive than a mutually exclusive lifecycle enum and lets downstream protocols compose policies safely.

## Settlement operations

`SettlementCoordinator` models individual operations separately from asset status:

`REQUESTED -> ACKNOWLEDGED -> SETTLED`

or

`REQUESTED/ACKNOWLEDGED -> FAILED`

and a requester may cancel a still-unacknowledged request.

Subscription operations are treated as **new exposure** and require healthy control-plane state. Redemption operations are still requestable under stressed conditions to avoid conflating risk controls with an exit lock.
