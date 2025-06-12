// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IVerifier
 * @author Sektorial12 (Cascade)
 * @notice Interface for a ZK-SNARK verifier contract.
 */
interface IVerifier {
    /**
     * @notice Verifies a ZK proof.
     * @param proof The ZK-SNARK proof.
     * @param publicInputs The public inputs used to generate the proof.
     * @return True if the proof is valid, false otherwise.
     */
    function verifyProof(bytes calldata proof, uint256[] calldata publicInputs) external view returns (bool);
}
