// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";

library CCIPHelper {
    /// @dev Safe wrapper around IRouterClient.ccipSend to avoid revert when router contract is missing.
    function safeSend(uint64 destChain, Client.EVM2AnyMessage memory msgData, address router)
        internal
        returns (bytes32)
    {
        if (router.code.length == 0) return bytes32(0);
        try IRouterClient(router).ccipSend(destChain, msgData) returns (bytes32 id) {
            return id;
        } catch {
            return bytes32(0);
        }
    }
}
