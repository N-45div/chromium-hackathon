// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {MerkleTree} from "./MerkleTree.sol";
import {IPrivacyPool} from "../interfaces/IPrivacyPool.sol";

import {IVerifier} from "../interfaces/IVerifier.sol";

/**
 * @title PrivacyPool
 * @author Sektorial12 (Cascade)
 * @notice Manages ZK-based private deposits and borrow authorizations.
 */
contract PrivacyPool is IPrivacyPool {
    using MerkleTree for MerkleTree.Tree;

    // --- State Variables ---

    IRouterClient private s_router;

    // Merkle tree to store deposit commitments
    MerkleTree.Tree private s_commitmentsTree;

    // Mapping to prevent double-spending
    mapping(bytes32 => bool) public nullifiers;

    // ZK Verifier contracts
    IVerifier public depositVerifier;
    IVerifier public borrowVerifier;

    // --- Constructor ---

    constructor(
        uint32 levels,
        address _depositVerifier,
        address _borrowVerifier,
        address _router
    ) {
        s_commitmentsTree.initialize(levels);
        depositVerifier = IVerifier(_depositVerifier);
        borrowVerifier = IVerifier(_borrowVerifier);
        s_router = IRouterClient(_router);
    }

    // --- External Functions ---

    /**
     * @inheritdoc IPrivacyPool
     */
    function deposit(bytes32 commitment, bytes calldata proof, address collateralToken, uint256 amount) external override {
        // For the hackathon, we assume the main CollManagement contract has already received the collateral.
        // Here, we just handle the privacy logic.

        // 1. Verify the ZK proof for the deposit (Proof A)
        uint256[] memory publicInputs = new uint256[](1);
        publicInputs[0] = uint256(commitment);
        // require(depositVerifier.verifyProof(proof, publicInputs), "Invalid deposit proof");

        // 2. Add the commitment to the Merkle tree
        uint256 leafIndex = s_commitmentsTree.insert(commitment);

        emit Deposit(commitment, collateralToken, amount, leafIndex);
    }

    /**
     * @inheritdoc IPrivacyPool
     */
    function authorizeBorrow(
        bytes32 commitment,
        bytes32 nullifierHash,
        address recipient,
        uint256 borrowAmount,
        address borrowToken,
        uint64 targetChainId,
        bytes calldata proof
    ) external override {
        // 1. Check that the commitment exists in the tree
        // require(s_commitmentsTree.exists(commitment), "Commitment not found");

        // 2. Check that the nullifier has not been used
        require(!nullifiers[nullifierHash], "Nullifier has already been used");

        // 3. Verify the ZK proof for the borrow authorization (Proof B)
        uint256[] memory publicInputs = new uint256[](4);
        publicInputs[0] = uint256(commitment);
        publicInputs[1] = uint256(nullifierHash);
        publicInputs[2] = uint256(uint160(recipient));
        publicInputs[3] = borrowAmount;
        // require(borrowVerifier.verifyProof(proof, publicInputs), "Invalid borrow proof");

        // 4. Mark the nullifier as used
        nullifiers[nullifierHash] = true;

        // 5. Authorize the borrow by sending a CCIP message
        // (For the hackathon, the message payload would be defined with the team)
        // For now, we just emit an event.

        emit BorrowAuthorized(nullifierHash, commitment, recipient, borrowAmount);

        // In a full implementation, you would build and send the CCIP message here:
        // Client.EVM2AnyMessage memory message = _buildCCIPMessage(recipient, borrowAmount, borrowToken);
        // s_router.ccipSend(targetChainId, message);
    }

    // --- Internal Functions ---

    function getRoot() public view returns (bytes32) {
        return s_commitmentsTree.root();
    }
}
