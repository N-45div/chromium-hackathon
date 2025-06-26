// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CheckOwner is Script {
    function run(address target) external view {
        address owner = Ownable(target).owner();
        console.log("Owner of", target, "is", owner);
    }
}
