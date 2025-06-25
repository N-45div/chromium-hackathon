// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockRouter is IRouterClient {
    Client.EVM2AnyMessage public lastMessageSent;
    uint64 public lastDestinationChainSelector;

    function isChainSupported(uint64 /*chainSelector*/ ) external pure override returns (bool supported) {
        return true;
    }

    function getFee(uint64, /*destinationChainSelector*/ Client.EVM2AnyMessage memory /*message*/ )
        public
        pure
        override
        returns (uint256 fee)
    {
        return 1e17;
    }

    function ccipSend(uint64 destinationChainSelector, Client.EVM2AnyMessage calldata message)
        external
        payable
        override
        returns (bytes32)
    {
        lastMessageSent = message;
        lastDestinationChainSelector = destinationChainSelector;
        uint256 fee = getFee(destinationChainSelector, message);
        if (fee > 0 && address(message.feeToken) != address(0)) {
            IERC20(message.feeToken).transferFrom(msg.sender, address(this), fee);
        }
        return bytes32(keccak256(abi.encodePacked("mockMessageId")));
    }
}
