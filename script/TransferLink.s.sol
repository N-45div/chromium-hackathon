// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TransferLink is Script {
    function run(address linkTokenAddress, address to, uint256 amount) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IERC20(linkTokenAddress).transfer(to, amount);
        vm.stopBroadcast();
    }
}
