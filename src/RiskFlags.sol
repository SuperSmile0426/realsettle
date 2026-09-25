// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Stable bit positions that downstream protocols can compose into their own policy masks.
library RiskFlags {
    uint256 internal constant UNKNOWN_ASSET = 1 << 0;
    uint256 internal constant NO_ATTESTATION = 1 << 1;
    uint256 internal constant STALE_ATTESTATION = 1 << 2;
    uint256 internal constant TOKEN_UNREADABLE = 1 << 3;
    uint256 internal constant SUPPLY_MISMATCH = 1 << 4;
    uint256 internal constant RESTRICTED = 1 << 5;
    uint256 internal constant DEFAULTED = 1 << 6;
    uint256 internal constant MATURED = 1 << 7;
    uint256 internal constant REDEMPTION_DELAYED = 1 << 8;
    uint256 internal constant RECOVERY = 1 << 9;

    uint256 internal constant DEFAULT_BLOCKING_MASK = UNKNOWN_ASSET | NO_ATTESTATION | STALE_ATTESTATION
        | TOKEN_UNREADABLE | SUPPLY_MISMATCH | RESTRICTED | DEFAULTED | MATURED | REDEMPTION_DELAYED | RECOVERY;
}
