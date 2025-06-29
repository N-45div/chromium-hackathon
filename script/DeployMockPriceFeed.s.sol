// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/core/coll/MockPriceFeed.sol";

contract DeployMockPriceFeed is Script {
    function run(int256 _initialPrice) external returns (address) {
        vm.startBroadcast();
        MockPriceFeed mockPriceFeed = new MockPriceFeed(_initialPrice);
        vm.stopBroadcast();
        console.log("MockPriceFeed deployed to:", address(mockPriceFeed));
        return address(mockPriceFeed);
    }
}
