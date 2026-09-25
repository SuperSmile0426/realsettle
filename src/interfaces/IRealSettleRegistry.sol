// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRealSettleRegistry {
    enum AssetStatus {
        UNREGISTERED,
        ACTIVE,
        RESTRICTED,
        DEFAULTED,
        RECOVERY,
        MATURED
    }

    struct AssetConfig {
        address issuer;
        address token;
        address settlementAsset;
        address attester;
        uint64 maxAttestationAge;
        uint64 maxRedemptionDelay;
        bytes32 metadataHash;
    }

    struct Attestation {
        bytes32 assetId;
        uint256 navE18;
        uint256 reportedSupply;
        uint256 outstandingRedemptions;
        uint256 cumulativeSettledRedemptions;
        uint64 oldestPendingRedemptionAt;
        uint64 observedAt;
        uint256 nonce;
        bytes32 evidenceHash;
    }

    struct Snapshot {
        uint256 navE18;
        uint256 reportedSupply;
        uint256 onchainSupplyAtSubmission;
        uint256 outstandingRedemptions;
        uint256 cumulativeSettledRedemptions;
        uint64 oldestPendingRedemptionAt;
        uint64 observedAt;
        uint256 nonce;
        bytes32 evidenceHash;
        bool tokenSupplyReadable;
    }

    event AssetRegistered(bytes32 indexed assetId, address indexed issuer, address indexed token, address attester);
    event AttesterUpdated(bytes32 indexed assetId, address indexed oldAttester, address indexed newAttester);
    event PolicyUpdated(bytes32 indexed assetId, uint64 maxAttestationAge, uint64 maxRedemptionDelay);
    event AssetStatusUpdated(bytes32 indexed assetId, AssetStatus oldStatus, AssetStatus newStatus, bytes32 reasonHash);
    event AttestationAccepted(
        bytes32 indexed assetId, uint256 indexed nonce, uint64 observedAt, bytes32 evidenceHash, uint256 riskFlags
    );

    function registerAsset(bytes32 assetId, AssetConfig calldata config) external;
    function setAttester(bytes32 assetId, address newAttester) external;
    function setPolicy(bytes32 assetId, uint64 maxAttestationAge, uint64 maxRedemptionDelay) external;
    function setAssetStatus(bytes32 assetId, AssetStatus newStatus, bytes32 reasonHash) external;
    function submitAttestation(Attestation calldata attestation, bytes calldata signature) external;

    function getAsset(bytes32 assetId) external view returns (AssetConfig memory);
    function getSnapshot(bytes32 assetId) external view returns (Snapshot memory);
    function getAssetStatus(bytes32 assetId) external view returns (AssetStatus);
    function getRiskFlags(bytes32 assetId) external view returns (uint256);
    function attestationDigest(Attestation calldata attestation) external view returns (bytes32);
}
