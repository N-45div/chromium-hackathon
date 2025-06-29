// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CollManagement} from "../src/core/coll/CollManagement.sol";

contract SetPriceFeed is Script {
    function run(
        address collManagement,
        address token,
        address priceFeed
    ) external {
        vm.startBroadcast();
        CollManagement(collManagement).setPriceFeed(token, priceFeed);
        vm.stopBroadcast();
    }
}
