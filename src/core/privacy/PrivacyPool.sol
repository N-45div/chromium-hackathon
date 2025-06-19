// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleTree} from "./MerkleTree.sol";
import {IPrivacyPool} from "../interfaces/IPrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "../CrossChainBorrowLib.sol";
import {Groth16Verifier as DepositVerifier} from "../../../contracts/DepositVerifier.sol";
import {Groth16Verifier as BorrowVerifier} from "../../../contracts/BorrowVerifier.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";

/**
 * @title PrivacyPool
 * @author Sektorial12
 * @notice Manages ZK-based private deposits and borrow authorizations.
 */
contract PrivacyPool is IPrivacyPool, Ownable {
    using MerkleTree for MerkleTree.Tree;

    // --- State Variables ---

    MerkleTree.Tree private s_commitmentsTree;
    mapping(bytes32 => bool) public nullifiers;
    DepositVerifier public depositVerifier;
    BorrowVerifier public borrowVerifier;
    address public s_link;
    mapping(uint64 => address) public targetReceivers;
    bool public immutable ENABLE_ZK_BORROW_CHECK;

    // --- Constructor ---

    constructor(
        uint32 levels,
        address _depositVerifier,
        address _borrowVerifier,
        address _linkToken,
        bool _enableZKBorrowCheck // Feature flag for ZK borrow verification
    ) Ownable(msg.sender) {
        s_commitmentsTree.initialize(levels);
        depositVerifier = DepositVerifier(_depositVerifier);
        borrowVerifier = BorrowVerifier(_borrowVerifier);
        s_link = _linkToken;
        ENABLE_ZK_BORROW_CHECK = _enableZKBorrowCheck;
    }

    // --- External Functions ---

    /**
     * @inheritdoc IPrivacyPool
     */
    function deposit(bytes32 commitment, bytes calldata proof, address collateralToken, uint256 amount)
        external
        override
    {
        uint256[1] memory publicInputs = [uint256(commitment)];
        (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = _unpackProof(proof);
        require(depositVerifier.verifyProof(a, b, c, publicInputs), "Invalid deposit proof");

        uint256 leafIndex = s_commitmentsTree.insert(commitment);

        emit Deposit(commitment, collateralToken, amount, leafIndex);
    }

    /**
     * @inheritdoc IPrivacyPool
     */
    function authorizeBorrow(
        bytes32 commitment, // Renamed
        bytes32 nullifierHash,
        address recipient, // Renamed
        uint256 borrowAmount,
        address borrowToken,
        uint64 targetChainSelector, // Added
        bytes calldata proof // Renamed
    ) external override returns (bool success) {
        require(!nullifiers[nullifierHash], "Nullifier has already been used");

        // Note: targetChainSelector is not directly used in the ZK proof public inputs for borrow.circom
        // It's used later for building the CCIP message.
        uint256[4] memory publicInputs = [
            uint256(s_commitmentsTree.root()),
            uint256(nullifierHash),
            uint256(uint160(recipient)), // <<< Use new 'recipient'
            borrowAmount
        ];
        if (!_verifyBorrow(publicInputs, proof)) { // <<< Use new 'proof'
            return false;
        }

        nullifiers[nullifierHash] = true;

        emit BorrowAuthorized(nullifierHash, commitment, recipient, borrowAmount); // <<< Use new 'commitment' and 'recipient'

        return true;
    }

    // --- Internal Functions ---

    /**
     * @dev Builds the CCIP message for authorizing a borrow on a target chain.
     * @param _recipientOnTarget The address of the recipient on the target chain.
     * @param _borrowAmount The amount to be borrowed.
     * @param _borrowToken The token to be borrowed.
     * @param _depositCommitment The user's original deposit commitment.
     * @param _nullifierHash The nullifier to prevent double-spending.
     * @param _zkProofData The ZK proof data.
     * @param _targetChainSelector The selector for the target chain.
     * @param _depositor The EOA who called authorizeBorrow.
     * @return The CCIP message.
     */
    function _buildCCIPMessage(
        address _recipientOnTarget,
        uint256 _borrowAmount,
        address _borrowToken,
        bytes32 _depositCommitment,
        bytes32 _nullifierHash,
        bytes calldata _zkProofData,
        uint64 _targetChainSelector,
        address _depositor
    ) internal view returns (Client.EVM2AnyMessage memory) {
        CrossChainBorrowInfo memory borrowInfo = CrossChainBorrowInfo({
            recipientAddress: address(0x0),
            collateralToken: address(0x0),
            borrowToken: _borrowToken,
            amount: _borrowAmount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: block.chainid,
            targetChainId: uint256(_targetChainSelector),
            commitmentHash: _depositCommitment,
            depositor: _depositor,
            nullifierHash: _nullifierHash,
            zkProof: _zkProofData,
            validationId: 0
        });

        bytes memory encodedData = abi.encode(borrowInfo);

        address targetReceiverContract = targetReceivers[_targetChainSelector];
        require(targetReceiverContract != address(0), "Target receiver not configured");

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(targetReceiverContract),
                data: encodedData,
                tokenAmounts: new Client.EVMTokenAmount[](0),
                feeToken: address(s_link),
                extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true}))
            });
    }

    function _unpackProof(
        bytes calldata _proof
    ) internal pure returns (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) {
        require(_proof.length == 8 * 32, "Invalid proof length");
        assembly {
            let ptr := _proof.offset // Get start of _proof in calldata

            // Load a
            mstore(a, calldataload(ptr)) // a[0]
            mstore(add(a, 0x20), calldataload(add(ptr, 0x20))) // a[1]

            // Load b
            // b is a uint256[2][2]. In memory, b[0] is at b, b[1] is at add(b, 0x40)
            // b[0][0] is at b, b[0][1] is at add(b, 0x20)
            // b[1][0] is at add(b, 0x40), b[1][1] is at add(b, 0x60)
            mstore(b, calldataload(add(ptr, 0x40))) // b[0][0]
            mstore(add(b, 0x20), calldataload(add(ptr, 0x60))) // b[0][1]
            mstore(add(b, 0x40), calldataload(add(ptr, 0x80))) // b[1][0]
            mstore(add(b, 0x60), calldataload(add(ptr, 0xa0))) // b[1][1]

            // Load c
            mstore(c, calldataload(add(ptr, 0xc0))) // c[0]
            mstore(add(c, 0x20), calldataload(add(ptr, 0xe0))) // c[1]
        }
    }

    function _verifyBorrow(
        uint256[4] memory _publicInputs,
        bytes calldata _proof
    ) internal view returns (bool) {
        if (!ENABLE_ZK_BORROW_CHECK) {
            return true; // Bypass ZK proof verification if flag is disabled
        }
        (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = _unpackProof(_proof);
        return borrowVerifier.verifyProof(a, b, c, _publicInputs);
    }

    function setTargetReceiver(uint64 _chainSelector, address _receiverAddress) external onlyOwner {
        targetReceivers[_chainSelector] = _receiverAddress;
    }

    function getRoot() public view returns (bytes32) {
        return s_commitmentsTree.root();
    }

    // --- Events ---
    event CCIPMessageSent(bytes32 indexed messageId, uint64 indexed targetChainSelector, Client.EVM2AnyMessage message);
}
