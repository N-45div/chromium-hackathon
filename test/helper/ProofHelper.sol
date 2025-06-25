// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPrivacyPool} from "src/core/interfaces/IPrivacyPool.sol";

contract ProofHelper {
    // Generates valid inputs for a private deposit.
    function generateDepositInputs() public pure returns (bytes32 commitment, bytes32 nullifier, bytes memory proof) {
        bytes32 secret = keccak256(abi.encodePacked("secret"));
        nullifier = keccak256(abi.encodePacked("nullifier"));
        commitment = keccak256(abi.encodePacked(secret, nullifier));

        // This is a mock proof. In a real scenario, this would be generated off-chain.
        proof = abi.encodePacked(
            uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7), uint256(8)
        );
    }

    // Generates a mock proof for a private borrow.
    function generateBorrowProof() public pure returns (bytes memory proof) {
        // This is a mock proof. In a real scenario, this would be generated off-chain.
        proof = abi.encodePacked(
            uint256(8), uint256(7), uint256(6), uint256(5), uint256(4), uint256(3), uint256(2), uint256(1)
        );
    }
}
