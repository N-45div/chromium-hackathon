// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

enum BorrowStatus {
    NONE,
    INIITIAL,
    PENDING,
    CONFIRMED,
    BORROWED,
    REPAY
}

// collateralToken,borrowToken,initiator tell source chain calculate whose collateralRatio
//  pendingAmount, if received the confirm from source chain, then pendingAmount==0, borrowedAmount+=pendingAmount
//  BorrowStatus record the different operation types in target chain
struct AvaiableBorrowBalance {
    address collateralToken;
    uint256 borrowToken; // fixed to USDC for now
    address initiator; // the user who enable borrow
    uint256 sourceChainId;
    uint256 pendingAmount; // the amount that is pending to be borrowed, each time borrow must ensure pendingAmount == 0.
    uint256 borrowedAmount;
    BorrowStatus status;
    bytes proof;
    bytes commit;
    uint64 updatedAt; // timestamp of the last update
}

struct BorrowTokenInfoFromTargetChain {
    uint8 targetChainId; // the target chain id
    address recipientAddress; // zero address means no specify
    address borrowToken;
    uint256 borrowedAmount;
    uint64 borrowedTimeStamp; // timestamp of the last update
    uint64 collateralRatio; // should keep consistent between the source chain and the target chain
}

interface IBorrowManagement {
    function borrowPending(uint256 amount) external;

    function borrowByConfirmed(uint256 amount) external;

    function repay(uint256 amount) external;
}
