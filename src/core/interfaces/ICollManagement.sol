// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

struct DepositCollateralInfo {
    address collateralToken;
    uint256 amount;
    uint256 targetChainId;
    address borrowToken;
    address recipientAddress; // zero address means no specify
    bytes proofA;
    bytes32 commitmentHash;
}

// TODO, below how to integrate with privacy mode
struct TargetChainBorowInfo {
    address borrowToken;
    address recipientAddress; // zero address means no specify
    uint256 syncBorrowBalance;
}

struct SupportCollInfo {
    address collateralToken;
    uint256 collateralRatio;
    uint256 targetChainId;
    uint64 targetChainSelector; //  chainlink ChainSelector
    address targetChainBorrowManager;
    address borrowToken;
    bool isSupported;
}

interface ICollManagement {
    // just depositCollateral without selecting the target chain and the borrow token
    function depositCollateral(address collateralToken, uint256 amount) external;

    // depositCollateral by selecting the target chain and the borrow token, and specifying the address who can borrow
    function depositCollateral(DepositCollateralInfo memory depositInfo) external;

    function withdrawCollateral(address collateralToken, uint256 amount) external;

    function liquidateCollateral(address collateralToken, address user) external;
}
