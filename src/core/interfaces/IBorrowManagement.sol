// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {CrossChainBorrowInfo} from "src/core/interfaces/ICollManagement.sol";

enum BorrowStatus {
    NONE,
    INITIAL,
    BORROW_PENDING_SOURCE_CONFIRMATION,
    BORROW_APPROVED_BY_SOURCE,
    REPAY_PENDING_SOURCE_CONFIRMATION,
    REPAY_CONFIRMED_BY_SOURCE
}

// collateralToken,borrowToken,initiator tell source chain calculate whose collateralRatio
//  pendingAmount, if received the confirm from source chain, then pendingAmount==0, borrowedAmount+=pendingAmount
//  BorrowStatus record the different operation types in target chain
struct AvaiableBorrowBalance {
    address collateralToken;
    address borrowToken; // fixed to USDC for now
    address initiator; // the user who enable borrow
    uint256 sourceChainId;
    uint256 pendingAmount; // the amount that is pending to be borrowed, each time borrow must ensure pendingAmount == 0.
    uint256 borrowedAmount;
    BorrowStatus status;
    bytes proof;
    uint64 updatedAt; // timestamp of the last update
}

struct BorrowTokenInfoFromTargetChain {
    uint256 targetChainId; // the target chain id
    address recipientAddress; // zero address means no specify
    address borrowToken;
    uint256 borrowedAmount;
    uint64 borrowedTimeStamp; // timestamp of the last update
    uint64 collateralRatio; // should keep consistent between the source chain and the target chain
}

interface IBorrowManagement {
    function borrowApply(uint256 amount) external;
    function borrowApply(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external;

    function repay(uint256 amount) external;
    function repay(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external;

    // Called by source-chain CollManagement via CCIP (or directly in tests) to initialise borrow parameters on target chain.
    function borrowInitial(CrossChainBorrowInfo memory crossChainBorrowInfo) external;
}
