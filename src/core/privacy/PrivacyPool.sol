// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {MerkleTree} from "./MerkleTree.sol";
import {IPrivacyPool} from "../interfaces/IPrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "../CrossChainBorrowLib.sol"; // Added import

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
    LinkTokenInterface private s_link; // Added LINK token interface
    mapping(uint64 => address) public targetReceivers; // Added mapping for target chain receivers

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
        address _router,
        address _linkToken // Added LINK token address to constructor
    ) {
        s_commitmentsTree.initialize(levels);
        // Instantiate the concrete verifier contracts
        depositVerifier = new DepositVerifier();
        borrowVerifier = new BorrowVerifier();
        s_router = IRouterClient(_router);
        s_link = LinkTokenInterface(_linkToken); // Initialize LINK token
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
        bytes32 depositCommitment, // Renamed to clarify this is the user's original deposit commitment
        bytes32 nullifierHash,
        address recipientOnTarget, // Renamed for clarity (recipient from ZK proof)
        uint256 borrowAmount,
        address borrowToken, // Token to be borrowed on the target chain
        uint64 targetChainSelector, // CCIP Target Chain Selector
        bytes calldata zkProofData // Renamed for clarity
    ) external override {
        // 1. Check that the deposit commitment exists in the tree (optional, ZK proof implies this)
        // require(s_commitmentsTree.exists(depositCommitment), "Deposit commitment not found");

        // 2. Check that the nullifier has not been used
        require(!nullifiers[nullifierHash], "Nullifier has already been used");

        // 3. Verify the ZK proof for the borrow authorization (Proof B)
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c) = abi.decode(zkProofData, (uint[2], uint[2][2], uint[2]));
        uint256[4] memory publicInputs = [
            uint256(s_commitmentsTree.root()), // Proof is against the current Merkle root
            uint256(nullifierHash),
            uint256(uint160(recipientOnTarget)),
            borrowAmount
        ];
        require(borrowVerifier.verifyProof(a, b, c, publicInputs), "Invalid borrow proof");

        // 4. Mark the nullifier as used
        nullifiers[nullifierHash] = true;

        // 5. Authorize the borrow by sending a CCIP message
        emit BorrowAuthorized(nullifierHash, depositCommitment, recipientOnTarget, borrowAmount);

        // Build and send the CCIP message
        // The fee token can be LINK or native, depending on the chain and CCIP configuration
        // For simplicity, we'll assume fee payment is handled or not required for this example call.
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(
            recipientOnTarget, // Actual recipient from ZK proof
            borrowAmount,
            borrowToken,
            depositCommitment, // User's original deposit commitment
            nullifierHash,
            zkProofData,
            targetChainSelector,
            msg.sender // The EOA interacting with PrivacyPool
        );
        
        uint256 fee = s_router.getFee(targetChainSelector, message); // Calculate actual fee
        require(s_link.balanceOf(address(this)) >= fee, "Not enough LINK for CCIP fee");
        // Potentially approve the router to spend LINK if not done globally
        // s_link.approve(address(s_router), fee); // This might be needed depending on router version
        
        bytes32 messageId = s_router.ccipSend{value: 0}(targetChainSelector, message); // Value is 0 if feeToken is LINK and paid by contract

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
        address _recipientOnTarget, // Actual recipient from ZK proof
        uint256 _borrowAmount,
        address _borrowToken,
        bytes32 _depositCommitment, // User's original deposit commitment
        bytes32 _nullifierHash,
        bytes calldata _zkProofData,
        uint64 _targetChainSelector, // Needed for targetChainId if not directly available
        address _depositor // The EOA calling authorizeBorrow
    ) internal view returns (Client.EVM2AnyMessage memory) { // Changed to view due to s_link and targetReceivers access
        CrossChainBorrowInfo memory borrowInfo = CrossChainBorrowInfo({
            recipientAddress: address(0x0), // For privacy mode, direct recipient is 0; actual recipient in ZK proof
            collateralToken: address(0x0), // PrivacyPool doesn't manage collateral token directly
            borrowToken: _borrowToken,
            amount: _borrowAmount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: block.chainid, // Assumes this contract is on the source chain
            targetChainId: uint256(_targetChainSelector), // Assuming selector can be cast or mapped to chain ID
            commitmentHash: _depositCommitment, // User's original deposit commitment
            depositor: _depositor, // The EOA who called authorizeBorrow
            nullifierHash: _nullifierHash,
            zkProof: _zkProofData
        });

        bytes memory encodedData = abi.encode(borrowInfo);

        address targetReceiverContract = targetReceivers[_targetChainSelector];
        require(targetReceiverContract != address(0), "Target receiver not configured");

        return Client.EVM2AnyMessage({
            receiver: abi.encode(targetReceiverContract),
            data: encodedData,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(s_link),
            extraArgs: Client._makeExtraArgs(false, false, 0) // Default extraArgs, gasLimit might be needed
        });
    }

    // Function to configure target receiver addresses by the owner
    function setTargetReceiver(uint64 _chainSelector, address _receiverAddress) external onlyOwner {
        targetReceivers[_chainSelector] = _receiverAddress;
    }

    function getRoot() public view returns (bytes32) {
        return s_commitmentsTree.root();
    }

    // --- Events ---
    event CCIPMessageSent(bytes32 indexed messageId, uint64 indexed targetChainSelector, Client.EVM2AnyMessage message);

}

