// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

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

struct SupportBorrowCollTokenInfo {
    address collateralToken;
    uint256 sourceChainId;
    uint64 sourceChainSelector; //  chainlink ChainSelector
    address sourceChainCollManager;
    bool isSupported;
}

interface IBorrowManagement {
    function borrowApply(uint256 amount) external;
    function borrowApply(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external;

    function repayApply(uint256 amount) external;
    function repayApply(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external;
}
