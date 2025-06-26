// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "test/mock/MockERC20.sol";

contract MintUSDC is Script {
    function run(address to, uint256 amount) external {
        address mockUSDCAddress = 0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MockERC20(mockUSDCAddress).mint(to, amount);

        console.log("Minted", amount / 1e6, "USDC to", to);

        vm.stopBroadcast();
    }
}
