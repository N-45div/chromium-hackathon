// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "test/mock/MockERC20.sol";

contract MintWETH is Script {
    function run(address to, uint256 amount) external {
        address mockWETHAddress = 0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MockERC20(mockWETHAddress).mint(to, amount);

        console.log("Minted", amount / 1e18, "WETH to", to);

        vm.stopBroadcast();
    }
}
