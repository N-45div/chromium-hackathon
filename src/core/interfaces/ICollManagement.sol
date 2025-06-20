// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Info for depositing collateral on the source chain
struct DepositInfo {
    address collateralToken;
    uint256 amount;
    address borrowToken;
    address recipientAddress;
    bytes32 commitmentHash;
    bytes32 merkleRoot;
}

// Stores information about a user's collateral on the source chain
struct UserCollateralInfo {
    uint256 totalDeposited;
    uint256 totalBorrowed;
}

// Stores information about a user's borrow balance on a specific target chain
struct TargetChainBorrowInfo {
    uint256 syncBorrowBalance;
    address borrowToken;
}

interface ICollManagement {
    /**
     * @notice Deposit collateral to be used for cross-chain borrowing.
     * @param _collateralToken The address of the collateral token.
     * @param _amount The amount to deposit.
     * @param _recipient The recipient address on the target chain.
     */
    function depositCollateral(address _collateralToken, uint256 _amount, address _recipient) external;

    /**
     * @notice Withdraw collateral.
     * @param collateralToken The address of the collateral token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdrawCollateral(address collateralToken, uint256 amount) external;
}
