// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {MerkleTree} from "./MerkleTree.sol";
import {IPrivacyPool} from "../interfaces/IPrivacyPool.sol";

// Import the generated verifier contracts
import {Groth16Verifier as DepositVerifier} from "../../../contracts/DepositVerifier.sol";
import {Groth16Verifier as BorrowVerifier} from "../../../contracts/BorrowVerifier.sol";

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
    DepositVerifier public depositVerifier;
    BorrowVerifier public borrowVerifier;

    // --- Constructor ---

    constructor(
        uint32 levels,
        address _router
    ) {
        s_commitmentsTree.initialize(levels);
        // Instantiate the concrete verifier contracts
        depositVerifier = new DepositVerifier();
        borrowVerifier = new BorrowVerifier();
        s_router = IRouterClient(_router);
    }

    // --- External Functions ---

    /**
     * @inheritdoc IPrivacyPool
     */
    function deposit(bytes32 commitment, bytes calldata proof, address collateralToken, uint256 amount)
        external
        override
    {
        // For the hackathon, we assume the main CollManagement contract has already received the collateral.
        // Here, we just handle the privacy logic.

        // 1. Verify the ZK proof for the deposit (Proof A)
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint256[1] memory publicInputs = [uint256(commitment)];
        require(depositVerifier.verifyProof(a, b, c, publicInputs), "Invalid deposit proof");

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
        uint256 targetChainId,
        bytes calldata proof
    ) external override {
        // 1. Check that the commitment exists in the tree
        // require(s_commitmentsTree.exists(commitment), "Commitment not found");

        // 2. Check that the nullifier has not been used
        require(!nullifiers[nullifierHash], "Nullifier has already been used");

        // 3. Verify the ZK proof for the borrow authorization (Proof B)
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint256[4] memory publicInputs = [
            uint256(s_commitmentsTree.root()), // Proof is against the current Merkle root
            uint256(nullifierHash),
            uint256(uint160(recipient)),
            borrowAmount
        ];
        require(borrowVerifier.verifyProof(a, b, c, publicInputs), "Invalid borrow proof");

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
