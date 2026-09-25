// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {IRealSettleRegistry} from "./interfaces/IRealSettleRegistry.sol";
import {RiskFlags} from "./RiskFlags.sol";

/// @title RealSettleRegistry
/// @notice Canonical RealFi control-plane state for tokenized real-world assets on Pharos.
/// @dev Grant-stage reference implementation. Not audited for production use.
contract RealSettleRegistry is IRealSettleRegistry, AccessControl, EIP712 {
    error Unauthorized();
    error ZeroAddress();
    error AssetAlreadyExists();
    error UnknownAsset();
    error InvalidAssetId();
    error InvalidPolicy();
    error InvalidStatus();
    error InvalidNonce(uint256 expected, uint256 actual);
    error InvalidTimestamp();
    error FutureAttestation();
    error InvalidAttestation();
    error InvalidSignature();

    bytes32 public constant ASSET_REGISTRAR_ROLE = keccak256("ASSET_REGISTRAR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");

    bytes32 private constant _ATTESTATION_TYPEHASH = keccak256(
        "Attestation(bytes32 assetId,uint256 navE18,uint256 reportedSupply,uint256 outstandingRedemptions,uint256 cumulativeSettledRedemptions,uint64 oldestPendingRedemptionAt,uint64 observedAt,uint256 nonce,bytes32 evidenceHash)"
    );
    bytes4 private constant _TOTAL_SUPPLY_SELECTOR = bytes4(keccak256("totalSupply()"));

    mapping(bytes32 assetId => AssetConfig) private _assets;
    mapping(bytes32 assetId => Snapshot) private _snapshots;
    mapping(bytes32 assetId => AssetStatus) private _status;
    mapping(bytes32 assetId => bool) private _exists;

    constructor(address admin) EIP712("RealSettle", "2") {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ASSET_REGISTRAR_ROLE, admin);
        _grantRole(RISK_MANAGER_ROLE, admin);
    }

    function registerAsset(bytes32 assetId, AssetConfig calldata config) external onlyRole(ASSET_REGISTRAR_ROLE) {
        if (assetId == bytes32(0)) revert InvalidAssetId();
        if (_exists[assetId]) revert AssetAlreadyExists();
        if (
            config.issuer == address(0) || config.token == address(0) || config.settlementAsset == address(0)
                || config.attester == address(0)
        ) revert ZeroAddress();
        if (config.maxAttestationAge == 0) revert InvalidPolicy();

        _exists[assetId] = true;
        _assets[assetId] = config;
        _status[assetId] = AssetStatus.ACTIVE;

        emit AssetRegistered(assetId, config.issuer, config.token, config.attester);
        emit AssetStatusUpdated(assetId, AssetStatus.UNREGISTERED, AssetStatus.ACTIVE, bytes32(0));
    }

    function setAttester(bytes32 assetId, address newAttester) external {
        _requireIssuer(assetId);
        if (newAttester == address(0)) revert ZeroAddress();

        address oldAttester = _assets[assetId].attester;
        _assets[assetId].attester = newAttester;
        emit AttesterUpdated(assetId, oldAttester, newAttester);
    }

    function setPolicy(bytes32 assetId, uint64 maxAttestationAge, uint64 maxRedemptionDelay) external {
        _requireIssuer(assetId);
        if (maxAttestationAge == 0) revert InvalidPolicy();

        AssetConfig storage config = _assets[assetId];
        config.maxAttestationAge = maxAttestationAge;
        config.maxRedemptionDelay = maxRedemptionDelay;
        emit PolicyUpdated(assetId, maxAttestationAge, maxRedemptionDelay);
    }

    function setAssetStatus(bytes32 assetId, AssetStatus newStatus, bytes32 reasonHash) external {
        if (!_exists[assetId]) revert UnknownAsset();
        if (newStatus == AssetStatus.UNREGISTERED) revert InvalidStatus();
        if (msg.sender != _assets[assetId].issuer && !hasRole(RISK_MANAGER_ROLE, msg.sender)) revert Unauthorized();

        AssetStatus oldStatus = _status[assetId];
        _status[assetId] = newStatus;
        emit AssetStatusUpdated(assetId, oldStatus, newStatus, reasonHash);
    }

    function submitAttestation(Attestation calldata a, bytes calldata signature) external {
        if (!_exists[a.assetId]) revert UnknownAsset();
        _validateAttestation(a);

        Snapshot storage previous = _snapshots[a.assetId];
        uint256 expectedNonce = previous.nonce + 1;
        if (a.nonce != expectedNonce) revert InvalidNonce(expectedNonce, a.nonce);
        if (previous.observedAt != 0 && a.observedAt < previous.observedAt) revert InvalidTimestamp();

        bytes32 digest = _hashTypedDataV4(_structHash(a));
        if (!SignatureChecker.isValidSignatureNow(_assets[a.assetId].attester, digest, signature)) {
            revert InvalidSignature();
        }

        (bool supplyReadable, uint256 currentSupply) = _tryTotalSupply(_assets[a.assetId].token);
        _snapshots[a.assetId] = Snapshot({
            navE18: a.navE18,
            reportedSupply: a.reportedSupply,
            onchainSupplyAtSubmission: currentSupply,
            outstandingRedemptions: a.outstandingRedemptions,
            cumulativeSettledRedemptions: a.cumulativeSettledRedemptions,
            oldestPendingRedemptionAt: a.oldestPendingRedemptionAt,
            observedAt: a.observedAt,
            nonce: a.nonce,
            evidenceHash: a.evidenceHash,
            tokenSupplyReadable: supplyReadable
        });

        emit AttestationAccepted(a.assetId, a.nonce, a.observedAt, a.evidenceHash, _computeRiskFlags(a.assetId));
    }

    function getAsset(bytes32 assetId) external view returns (AssetConfig memory) {
        if (!_exists[assetId]) revert UnknownAsset();
        return _assets[assetId];
    }

    function getSnapshot(bytes32 assetId) external view returns (Snapshot memory) {
        if (!_exists[assetId]) revert UnknownAsset();
        return _snapshots[assetId];
    }

    function getAssetStatus(bytes32 assetId) external view returns (AssetStatus) {
        if (!_exists[assetId]) return AssetStatus.UNREGISTERED;
        return _status[assetId];
    }

    function getRiskFlags(bytes32 assetId) external view returns (uint256) {
        return _computeRiskFlags(assetId);
    }

    function attestationDigest(Attestation calldata a) external view returns (bytes32) {
        return _hashTypedDataV4(_structHash(a));
    }

    function _validateAttestation(Attestation calldata a) private view {
        if (a.navE18 == 0 || a.observedAt == 0 || a.nonce == 0) revert InvalidAttestation();
        if (a.observedAt > block.timestamp) revert FutureAttestation();

        if (a.outstandingRedemptions == 0) {
            if (a.oldestPendingRedemptionAt != 0) revert InvalidAttestation();
        } else {
            if (a.oldestPendingRedemptionAt == 0 || a.oldestPendingRedemptionAt > a.observedAt) {
                revert InvalidAttestation();
            }
        }
    }

    function _structHash(Attestation calldata a) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _ATTESTATION_TYPEHASH,
                a.assetId,
                a.navE18,
                a.reportedSupply,
                a.outstandingRedemptions,
                a.cumulativeSettledRedemptions,
                a.oldestPendingRedemptionAt,
                a.observedAt,
                a.nonce,
                a.evidenceHash
            )
        );
    }

    function _computeRiskFlags(bytes32 assetId) private view returns (uint256 flags) {
        if (!_exists[assetId]) return RiskFlags.UNKNOWN_ASSET;

        AssetStatus status = _status[assetId];
        if (status == AssetStatus.RESTRICTED) flags |= RiskFlags.RESTRICTED;
        if (status == AssetStatus.DEFAULTED) flags |= RiskFlags.DEFAULTED;
        if (status == AssetStatus.MATURED) flags |= RiskFlags.MATURED;
        if (status == AssetStatus.RECOVERY) flags |= RiskFlags.RECOVERY;

        Snapshot memory snap = _snapshots[assetId];
        if (snap.observedAt == 0) return flags | RiskFlags.NO_ATTESTATION;

        AssetConfig memory config = _assets[assetId];
        if (block.timestamp > uint256(snap.observedAt) + uint256(config.maxAttestationAge)) {
            flags |= RiskFlags.STALE_ATTESTATION;
        }

        (bool supplyReadable, uint256 liveSupply) = _tryTotalSupply(config.token);
        if (!supplyReadable) {
            flags |= RiskFlags.TOKEN_UNREADABLE;
        } else if (liveSupply != snap.reportedSupply) {
            flags |= RiskFlags.SUPPLY_MISMATCH;
        }

        if (
            snap.outstandingRedemptions > 0 && config.maxRedemptionDelay > 0
                && block.timestamp > uint256(snap.oldestPendingRedemptionAt) + uint256(config.maxRedemptionDelay)
        ) {
            flags |= RiskFlags.REDEMPTION_DELAYED;
        }
    }

    function _tryTotalSupply(address token) private view returns (bool readable, uint256 supply) {
        (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSelector(_TOTAL_SUPPLY_SELECTOR));
        if (!ok || data.length < 32) return (false, 0);
        return (true, abi.decode(data, (uint256)));
    }

    function _requireIssuer(bytes32 assetId) private view {
        if (!_exists[assetId]) revert UnknownAsset();
        if (msg.sender != _assets[assetId].issuer) revert Unauthorized();
    }
}
