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
        bytes32 commitment, // This is the new commitment for the borrowed funds, if the borrow itself is private
        bytes32 nullifierHash,
        address recipient, // Recipient on the target chain
        uint256 borrowAmount,
        address borrowToken, // Token to be borrowed on the target chain
        uint64 targetChainSelector, // CCIP Target Chain Selector
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

        // Build and send the CCIP message
        // The fee token can be LINK or native, depending on the chain and CCIP configuration
        // For simplicity, we'll assume fee payment is handled or not required for this example call.
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(recipient, borrowAmount, borrowToken, commitment);
        
        // Get the fee. For simplicity, we'll use 0, but in a real scenario, you'd query the router.
        uint256 fee = 0; // s_router.getFee(targetChainSelector, message);
        
        // Send the message. Ensure contract has enough fee token (e.g. LINK or native gas token)
        bytes32 messageId = s_router.ccipSend{value: fee}(targetChainSelector, message);

        emit CCIPMessageSent(messageId, targetChainSelector, message);
    }

    // --- Internal Functions ---

    /**
     * @dev Builds the CCIP message for authorizing a borrow on a target chain.
     * @param _recipient The address of the recipient on the target chain.
     * @param _borrowAmount The amount to be borrowed.
     * @param _borrowToken The token to be borrowed.
     * @param _newCommitment The new commitment for the borrowed funds (if borrow is private).
     * @return The CCIP message.
     */
    function _buildCCIPMessage(
        address _recipient,
        uint256 _borrowAmount,
        address _borrowToken,
        bytes32 _newCommitment
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Encode the data payload. This structure must be agreed upon with the target chain receiver contract.
        // Example: (address recipient, uint256 amount, address token, bytes32 newCommitmentHash)
        bytes memory data = abi.encode(_recipient, _borrowAmount, _borrowToken, _newCommitment);

        // For simplicity, allow any address to receive the message on the target chain.
        // In a real scenario, this would be the address of your receiver contract on the target chain.
        address receiver = address(0); // Placeholder, should be the actual receiver contract address

        return Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // Receiver address on the destination chain
            data: data, // Encoded payload
            tokenAmounts: new Client.EVMTokenAmount[](0), // No token transfers with this message itself
            feeToken: address(0), // Address of the fee token, address(0) for native gas token
            extraArgs: "0x" // Extra arguments, for future use or specific router needs
        });
    }

    function getRoot() public view returns (bytes32) {
        return s_commitmentsTree.root();
    }

    // --- Events ---
    event CCIPMessageSent(bytes32 indexed messageId, uint64 indexed targetChainSelector, Client.EVM2AnyMessage message);

}

