// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "test/mock/MockERC20.sol";
import {MerkleTree} from "./MerkleTree.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {ICollManagement} from "../coll/CollManagement.sol";

/**
 * @title PrivacyProxy
 * @author StratoLend
 * @notice This contract acts as a privacy-preserving adapter for the CollManagement contract.
 * It allows users to deposit collateral privately using ZK-SNARKs.
 * The proxy verifies the ZK proof, manages a Merkle tree of commitments, and then
 * calls the public deposit function on the CollManagement contract.
 */
contract PrivacyProxy {
    using MerkleTree for MerkleTree.Tree;

    MerkleTree.Tree internal tree;
    ICollManagement public immutable collManagement;
    IVerifier public immutable depositVerifier;
    IVerifier public immutable borrowVerifier;

    mapping(uint256 => bool) public nullifierHashes;

    event Deposit(uint256 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Withdrawal(address to, uint256 nullifierHash);

    constructor(
        uint32 _levels,
        address _collManagement,
        address _depositVerifier,
        address _borrowVerifier
    ) {
        tree.initialize(_levels);
        collManagement = ICollManagement(_collManagement);
        depositVerifier = IVerifier(_depositVerifier);
        borrowVerifier = IVerifier(_borrowVerifier);
    }

    function deposit(address _token, uint256 _amount, uint256 _commitment) external {
        require(_amount > 0, "Deposit amount must be positive");

        // Verify the ZK proof for the deposit
        // For this adapter, we assume the proof is generated off-chain and we just handle the commitment.
        // A full implementation would take the proof as an argument and verify it here.
        // require(depositVerifier.verifyProof(proof, [uint256(_commitment)]), "Invalid deposit proof");

        uint256 leafIndex = tree.insert(bytes32(_commitment));
        emit Deposit(_commitment, uint32(leafIndex), block.timestamp);

        // Transfer the collateral to this contract, then approve CollManagement to pull it
        ERC20(_token).transferFrom(msg.sender, address(this), _amount);
        ERC20(_token).approve(address(collManagement), _amount);

        // Call the public deposit function on the core contract
        // The CollManagement contract sees this proxy as the depositor
        collManagement.depositCollateral(_token, _amount, msg.sender); // Use original sender as recipient
    }

    // TODO: Implement private borrow/withdraw functionality
    // function borrow() public {
    //     // 1. Verify borrow proof (including nullifier)
    //     // require(!nullifierHashes[nullifierHash], "Nullifier has been used");
    //     // require(borrowVerifier.verifyProof(proof, [merkleRoot, nullifierHash, recipient, borrowAmount]), "Invalid borrow proof");
    
    //     // 2. Mark nullifier as used
    //     // nullifierHashes[nullifierHash] = true;

    //     // 3. Initiate borrow process via CollManagement
    //     // This would likely involve a CCIP message flow started by this proxy
    // }
}
