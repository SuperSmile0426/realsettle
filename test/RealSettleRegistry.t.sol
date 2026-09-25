// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {RealSettleRegistry} from "../src/RealSettleRegistry.sol";
import {SettlementCoordinator} from "../src/SettlementCoordinator.sol";
import {IRealSettleRegistry} from "../src/interfaces/IRealSettleRegistry.sol";
import {RiskFlags} from "../src/RiskFlags.sol";

contract MockSupplyToken {
    uint256 public totalSupply;

    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
    }

    function setTotalSupply(uint256 newSupply) external {
        totalSupply = newSupply;
    }
}

contract RevertingSupplyToken {
    function totalSupply() external pure returns (uint256) {
        revert("unreadable");
    }
}

contract Mock1271Attester is IERC1271 {
    address public immutable signer;

    constructor(address signer_) {
        signer = signer_;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        return ECDSA.recover(hash, signature) == signer ? IERC1271.isValidSignature.selector : bytes4(0xffffffff);
    }
}

contract RealSettleRegistryTest is Test {
    RealSettleRegistry internal registry;
    SettlementCoordinator internal coordinator;
    MockSupplyToken internal token;

    uint256 internal attesterPk = 0xA11CE;
    address internal attester;
    address internal issuer = address(0xBEEF);
    address internal settlementAsset = address(0xCAFE);
    address internal user = address(0xABCD);
    bytes32 internal assetId = keccak256("demo-us-credit-fund");

    function setUp() public {
        attester = vm.addr(attesterPk);
        token = new MockSupplyToken(1_000_000e18);
        registry = new RealSettleRegistry(address(this));
        coordinator = new SettlementCoordinator(registry);

        registry.registerAsset(
            assetId,
            IRealSettleRegistry.AssetConfig({
                issuer: issuer,
                token: address(token),
                settlementAsset: settlementAsset,
                attester: attester,
                maxAttestationAge: 1 days,
                maxRedemptionDelay: 3 days,
                metadataHash: keccak256("ipfs://demo-metadata")
            })
        );
    }

    function testHealthyRiskFlagsAfterFreshReconciledAttestation() public {
        _submit(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        assertEq(registry.getRiskFlags(assetId), 0);
    }

    function testSupplyMismatchAddsFlagWithoutReverting() public {
        _submit(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        token.setTotalSupply(1_000_001e18);

        uint256 flags = registry.getRiskFlags(assetId);
        assertTrue((flags & RiskFlags.SUPPLY_MISMATCH) != 0);
    }

    function testStaleAttestationAddsFlag() public {
        _submit(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        vm.warp(block.timestamp + 1 days + 1);

        uint256 flags = registry.getRiskFlags(assetId);
        assertTrue((flags & RiskFlags.STALE_ATTESTATION) != 0);
    }

    function testDelayedRedemptionAddsIndependentFlag() public {
        uint64 oldestPending = uint64(block.timestamp - 1 days);
        _submit(1, 1_000_000e18, 5_000e6, oldestPending, uint64(block.timestamp));
        vm.warp(block.timestamp + 3 days + 1);

        uint256 flags = registry.getRiskFlags(assetId);
        assertTrue((flags & RiskFlags.REDEMPTION_DELAYED) != 0);
    }

    function testReplayNonceRejected() public {
        _submit(1, 1_000_000e18, 0, 0, uint64(block.timestamp));

        IRealSettleRegistry.Attestation memory a = _attestation(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        vm.expectRevert(abi.encodeWithSelector(RealSettleRegistry.InvalidNonce.selector, 2, 1));
        registry.submitAttestation(a, _sign(a));
    }

    function testRiskManagerCanRestrictAsset() public {
        registry.setAssetStatus(assetId, IRealSettleRegistry.AssetStatus.RESTRICTED, keccak256("emergency hold"));
        assertTrue((registry.getRiskFlags(assetId) & RiskFlags.RESTRICTED) != 0);
    }

    function testWrongSignerRejected() public {
        IRealSettleRegistry.Attestation memory a = _attestation(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        bytes32 digest = registry.attestationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, digest);

        vm.expectRevert(RealSettleRegistry.InvalidSignature.selector);
        registry.submitAttestation(a, abi.encodePacked(r, s, v));
    }

    function testERC1271AttesterSupported() public {
        Mock1271Attester wallet = new Mock1271Attester(attester);
        vm.prank(issuer);
        registry.setAttester(assetId, address(wallet));

        IRealSettleRegistry.Attestation memory a = _attestation(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        registry.submitAttestation(a, _sign(a));
        assertEq(registry.getRiskFlags(assetId), 0);
    }

    function testUnreadableTokenBecomesRiskFlagNotViewDoS() public {
        bytes32 secondAsset = keccak256("unreadable-token");
        RevertingSupplyToken badToken = new RevertingSupplyToken();
        registry.registerAsset(
            secondAsset,
            IRealSettleRegistry.AssetConfig({
                issuer: issuer,
                token: address(badToken),
                settlementAsset: settlementAsset,
                attester: attester,
                maxAttestationAge: 1 days,
                maxRedemptionDelay: 3 days,
                metadataHash: bytes32(0)
            })
        );

        IRealSettleRegistry.Attestation memory a = IRealSettleRegistry.Attestation({
            assetId: secondAsset,
            navE18: 1e18,
            reportedSupply: 100e18,
            outstandingRedemptions: 0,
            cumulativeSettledRedemptions: 0,
            oldestPendingRedemptionAt: 0,
            observedAt: uint64(block.timestamp),
            nonce: 1,
            evidenceHash: keccak256("evidence")
        });
        registry.submitAttestation(a, _signWithDigest(registry.attestationDigest(a)));

        assertTrue((registry.getRiskFlags(secondAsset) & RiskFlags.TOKEN_UNREADABLE) != 0);
    }

    function testCoordinatorBlocksNewExposureWhenStaleButAllowsRedemption() public {
        _submit(1, 1_000_000e18, 0, 0, uint64(block.timestamp));

        vm.prank(user);
        uint256 subscriptionId = coordinator.requestOperation(
            assetId, SettlementCoordinator.OperationKind.SUBSCRIPTION, 10_000e6, keccak256("sub-001")
        );
        assertEq(subscriptionId, 1);

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(user);
        vm.expectRevert(SettlementCoordinator.NewExposureBlocked.selector);
        coordinator.requestOperation(
            assetId, SettlementCoordinator.OperationKind.SUBSCRIPTION, 10_000e6, keccak256("sub-002")
        );

        vm.prank(user);
        uint256 redemptionId = coordinator.requestOperation(
            assetId, SettlementCoordinator.OperationKind.REDEMPTION, 100e18, keccak256("red-001")
        );
        assertEq(redemptionId, 2);
    }

    function testIssuerCanSettleCoordinatorOperation() public {
        _submit(1, 1_000_000e18, 0, 0, uint64(block.timestamp));
        vm.prank(user);
        uint256 operationId = coordinator.requestOperation(
            assetId, SettlementCoordinator.OperationKind.SUBSCRIPTION, 10_000e6, keccak256("sub-001")
        );

        vm.prank(issuer);
        coordinator.settle(operationId, keccak256("wire-confirmation"));

        SettlementCoordinator.Operation memory op = coordinator.getOperation(operationId);
        assertEq(uint256(op.status), uint256(SettlementCoordinator.OperationStatus.SETTLED));
    }

    function _submit(
        uint256 nonce,
        uint256 reportedSupply,
        uint256 outstandingRedemptions,
        uint64 oldestPendingRedemptionAt,
        uint64 observedAt
    ) internal {
        IRealSettleRegistry.Attestation memory a =
            _attestation(nonce, reportedSupply, outstandingRedemptions, oldestPendingRedemptionAt, observedAt);
        registry.submitAttestation(a, _sign(a));
    }

    function _attestation(
        uint256 nonce,
        uint256 reportedSupply,
        uint256 outstandingRedemptions,
        uint64 oldestPendingRedemptionAt,
        uint64 observedAt
    ) internal view returns (IRealSettleRegistry.Attestation memory) {
        return IRealSettleRegistry.Attestation({
            assetId: assetId,
            navE18: 1.0432e18,
            reportedSupply: reportedSupply,
            outstandingRedemptions: outstandingRedemptions,
            cumulativeSettledRedemptions: 1_800_000e6,
            oldestPendingRedemptionAt: oldestPendingRedemptionAt,
            observedAt: observedAt,
            nonce: nonce,
            evidenceHash: keccak256(abi.encode("administrator-statement", nonce))
        });
    }

    function _sign(IRealSettleRegistry.Attestation memory a) internal returns (bytes memory) {
        return _signWithDigest(registry.attestationDigest(a));
    }

    function _signWithDigest(bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attesterPk, digest);
        return abi.encodePacked(r, s, v);
    }
}
