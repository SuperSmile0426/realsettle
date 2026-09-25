// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRealSettleRegistry} from "./interfaces/IRealSettleRegistry.sol";
import {RiskFlags} from "./RiskFlags.sol";

/// @title SettlementCoordinator
/// @notice Reference consumer proving that normalized RealSettle risk state can change protocol behavior.
/// @dev This contract records settlement workflow references; it does not replace a transfer agent or custodian.
contract SettlementCoordinator {
    error ZeroAddress();
    error InvalidAmount();
    error UnknownOperation();
    error Unauthorized();
    error InvalidTransition();
    error NewExposureBlocked(uint256 riskFlags);

    enum OperationKind {
        SUBSCRIPTION,
        REDEMPTION,
        COUPON
    }

    enum OperationStatus {
        NONE,
        REQUESTED,
        ACKNOWLEDGED,
        SETTLED,
        FAILED,
        CANCELLED
    }

    struct Operation {
        bytes32 assetId;
        OperationKind kind;
        OperationStatus status;
        address requester;
        uint256 amount;
        uint64 requestedAt;
        bytes32 externalRef;
        bytes32 evidenceHash;
    }

    IRealSettleRegistry public immutable registry;
    uint256 public nextOperationId = 1;
    mapping(uint256 operationId => Operation) private _operations;

    event OperationRequested(
        uint256 indexed operationId,
        bytes32 indexed assetId,
        OperationKind indexed kind,
        address requester,
        uint256 amount,
        bytes32 externalRef
    );
    event OperationStatusChanged(uint256 indexed operationId, OperationStatus status, bytes32 evidenceHash);

    constructor(IRealSettleRegistry registry_) {
        if (address(registry_) == address(0)) revert ZeroAddress();
        registry = registry_;
    }

    function requestOperation(bytes32 assetId, OperationKind kind, uint256 amount, bytes32 externalRef)
        external
        returns (uint256 operationId)
    {
        if (amount == 0) revert InvalidAmount();

        // New subscriptions increase protocol exposure and are blocked by any default risk flag.
        // Redemptions remain requestable during stressed states so consumers do not lock the exit path.
        if (kind == OperationKind.SUBSCRIPTION) {
            uint256 flags = registry.getRiskFlags(assetId);
            if ((flags & RiskFlags.DEFAULT_BLOCKING_MASK) != 0) revert NewExposureBlocked(flags);
        } else {
            // Reverts for an unregistered asset and also provides the issuer used by later transitions.
            registry.getAsset(assetId);
        }

        operationId = nextOperationId++;
        _operations[operationId] = Operation({
            assetId: assetId,
            kind: kind,
            status: OperationStatus.REQUESTED,
            requester: msg.sender,
            amount: amount,
            requestedAt: uint64(block.timestamp),
            externalRef: externalRef,
            evidenceHash: bytes32(0)
        });

        emit OperationRequested(operationId, assetId, kind, msg.sender, amount, externalRef);
    }

    function acknowledge(uint256 operationId, bytes32 evidenceHash) external {
        Operation storage op = _operation(operationId);
        _requireIssuer(op.assetId);
        if (op.status != OperationStatus.REQUESTED) revert InvalidTransition();
        op.status = OperationStatus.ACKNOWLEDGED;
        op.evidenceHash = evidenceHash;
        emit OperationStatusChanged(operationId, op.status, evidenceHash);
    }

    function settle(uint256 operationId, bytes32 evidenceHash) external {
        Operation storage op = _operation(operationId);
        _requireIssuer(op.assetId);
        if (op.status != OperationStatus.REQUESTED && op.status != OperationStatus.ACKNOWLEDGED) {
            revert InvalidTransition();
        }
        op.status = OperationStatus.SETTLED;
        op.evidenceHash = evidenceHash;
        emit OperationStatusChanged(operationId, op.status, evidenceHash);
    }

    function fail(uint256 operationId, bytes32 evidenceHash) external {
        Operation storage op = _operation(operationId);
        _requireIssuer(op.assetId);
        if (op.status == OperationStatus.SETTLED || op.status == OperationStatus.CANCELLED) revert InvalidTransition();
        op.status = OperationStatus.FAILED;
        op.evidenceHash = evidenceHash;
        emit OperationStatusChanged(operationId, op.status, evidenceHash);
    }

    function cancel(uint256 operationId) external {
        Operation storage op = _operation(operationId);
        if (msg.sender != op.requester) revert Unauthorized();
        if (op.status != OperationStatus.REQUESTED) revert InvalidTransition();
        op.status = OperationStatus.CANCELLED;
        emit OperationStatusChanged(operationId, op.status, bytes32(0));
    }

    function getOperation(uint256 operationId) external view returns (Operation memory) {
        Operation memory op = _operations[operationId];
        if (op.status == OperationStatus.NONE) revert UnknownOperation();
        return op;
    }

    function canIncreaseExposure(bytes32 assetId) external view returns (bool allowed, uint256 riskFlags) {
        riskFlags = registry.getRiskFlags(assetId);
        allowed = (riskFlags & RiskFlags.DEFAULT_BLOCKING_MASK) == 0;
    }

    function _operation(uint256 operationId) private view returns (Operation storage op) {
        op = _operations[operationId];
        if (op.status == OperationStatus.NONE) revert UnknownOperation();
    }

    function _requireIssuer(bytes32 assetId) private view {
        IRealSettleRegistry.AssetConfig memory config = registry.getAsset(assetId);
        if (msg.sender != config.issuer) revert Unauthorized();
    }
}
