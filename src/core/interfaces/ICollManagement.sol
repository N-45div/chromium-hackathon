// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

struct DepositCollateralInfo {
    address collateralToken;
    uint256 amount;
    uint8 targetChainId;
    address borrowToken;
    address recipientAddress; // zero address means no specify
}
struct TargetChainBorowInfo {
    address borrowToken;
    address recipientAddress; // zero address means no specify
    uint64 collateralRatio; // should keep consistent between the source chain and the target chain
}

interface ICollManagement {
    // just depositCollateral without selecting the target chain and the borrow token
    function depositCollateral(address collateralToken, uint256 amount) external;

    // depositCollateral by selecting the target chain and the borrow token, and specifying the address who can borrow
    function depositCollateral(DepositCollateralInfo memory depositInfo) external;

    function withdrawCollateral(address collateralToken, uint256 amount) external;

    function setSupportedCollBorrowToken(address collateralToken, address borrowToken) external;

    // query the available borrow balance on the target chain for the specified borrow token
    function getAvaiableChainBorrowBalance(address user, uint8 targetChainId, address borrowToken) external view returns (uint256);
}
