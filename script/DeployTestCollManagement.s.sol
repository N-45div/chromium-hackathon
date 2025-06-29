// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CollManagement} from "../src/core/coll/CollManagement.sol";

contract DeployTestCollManagement is Script {
    // Sepolia Testnet Addresses
    address constant SEPOLIA_ROUTER = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address constant SEPOLIA_LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

        function run() external returns (address) {
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        address privacyPoolAddress = vm.envAddress("PRIVACY_POOL_ADDRESS");
        vm.startBroadcast();
        CollManagement collManagement = new CollManagement(SEPOLIA_ROUTER, SEPOLIA_LINK, wethAddress);
        collManagement.setPrivacyPool(privacyPoolAddress);

        // Configure the target chain for Fuji
        address borrowManagementFuji = 0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389;
        uint64 fujiSelector = 14767482510784806043;
        collManagement.setTargetChainParams(wethAddress, fujiSelector, borrowManagementFuji);

        vm.stopBroadcast();
        return address(collManagement);
    }
}
