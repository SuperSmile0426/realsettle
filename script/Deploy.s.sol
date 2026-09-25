// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RealSettleRegistry} from "../src/RealSettleRegistry.sol";
import {SettlementCoordinator} from "../src/SettlementCoordinator.sol";

contract DeployRealSettle is Script {
    function run() external returns (RealSettleRegistry registry, SettlementCoordinator coordinator) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envOr("REGISTRY_ADMIN", vm.addr(deployerKey));

        vm.startBroadcast(deployerKey);
        registry = new RealSettleRegistry(admin);
        coordinator = new SettlementCoordinator(registry);
        vm.stopBroadcast();
    }
}
