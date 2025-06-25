// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";

contract MockCCIPRouter {
    function getFee(uint64, Client.EVM2AnyMessage memory) external pure returns (uint256 fee) {
        return 1e18; // Return a dummy fee
    }

    function ccipSend(uint64, Client.EVM2AnyMessage memory) external returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(block.timestamp)));
    }
}
