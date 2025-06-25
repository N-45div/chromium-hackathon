// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockVerifier {
    function verifyProof(
        uint256[2] memory, // a
        uint256[2][2] memory, // b
        uint256[2] memory, // c
        uint256[1] memory // publicInputs
    ) public pure returns (bool) {
        return true;
    }

    function verifyProof(
        uint256[2] memory, // a
        uint256[2][2] memory, // b
        uint256[2] memory, // c
        uint256[4] memory // publicInputs
    ) public pure returns (bool) {
        return true;
    }
}
