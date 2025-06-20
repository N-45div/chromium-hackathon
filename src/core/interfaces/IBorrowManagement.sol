// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

// collateralToken,borrowToken,initiator tell source chain calculate whose collateralRatio
//  pendingAmount, if received the confirm from source chain, then pendingAmount==0, borrowedAmount+=pendingAmount
//  BorrowStatus record the different operation types in target chain

struct AvaiableBorrowBalance {
    address collateralToken;
    address borrowToken; // fixed to USDC for now
    address initiator; // the user who enable borrow (for public) or identifier from source (for ZK)
    uint256 sourceChainId;
    uint256 pendingAmount; // the amount that is pending to be borrowed, each time borrow must ensure pendingAmount == 0.
    uint256 borrowedAmount;
    BorrowStatus status;
    bytes proof; // Potentially for ZK repay, or can be removed if repay ZK is source-side
    address originalDepositor; // For public mode, tracks original source chain depositor
    address recipientForZK; // For ZK borrows, the intended recipient address on target chain
    uint64 ownChainSelector; // Selector for this chain, stored at initialization
    uint64 updatedAt; // timestamp of the last update
    bytes32 merkleRoot; // (Privacy Mode) Merkle root associated with the commitment
}

struct SupportBorrowCollTokenInfo {
    address collateralToken;
    uint256 sourceChainId; // Chain ID of the source chain (CollManagement)
    uint64 sourceChainSelector; // Chainlink ChainSelector for the source chain (CollManagement)
    address sourceChainCollManager; // Address of CollManagement on source chain
    uint64 ownChainSelector; // Chainlink ChainSelector for this target chain (BorrowManagement's chain)
    bool isSupported;
}

interface IBorrowManagement {
    function borrowApply(uint256 amount) external; // For public borrows
    function borrowApplyPrivate(uint256 amount, bytes32 commitmentHash, address recipientAddress) external; // For private ZK borrows

    function repayApply(uint256 amount) external; // For public repays
    function repayApplyPrivate(bytes32 commitmentHash, uint256 amount) external; // For private ZK repays
}
