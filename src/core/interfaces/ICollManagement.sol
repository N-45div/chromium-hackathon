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
    function depositCollateral(address _collateralToken, uint256 _amount, address _recipient) external payable;

    function getHealthFactor(address user) external view returns (uint256);

    /**
     * @notice Deposit collateral for a private (ZK) borrow.
     * @param _collateralToken The address of the collateral token.
     * @param _amount The amount to deposit.
     * @param _commitment The commitment hash for the private deposit.
     */
    function depositPrivateCollateral(
        address _collateralToken,
        uint256 _amount,
        bytes32 _commitment,
        bytes calldata _proof
    ) external;

    /**
     * @notice Initiates a private (ZK) borrow by authorizing it with the PrivacyPool and sending a CCIP message.
     * @param _commitment The commitment hash for the private deposit.
     * @param _nullifierHash The nullifier hash to prevent double-spending.
     * @param _recipient The recipient address on the target chain.
     * @param _borrowAmount The amount to borrow.
     * @param _borrowToken The token to borrow.
     * @param _targetChainSelector The chain selector for the target chain.
     * @param _proof The ZK proof data.
     */
    function initiatePrivateBorrow(
        bytes32 _commitment,
        bytes32 _nullifierHash,
        address _recipient,
        uint256 _borrowAmount,
        address _borrowToken,
        uint64 _targetChainSelector,
        bytes calldata _proof
    ) external;

    /**
     * @notice Withdraw collateral.
     * @param collateralToken The address of the collateral token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdrawCollateral(address collateralToken, uint256 amount) external;

    /**
     * @notice Sets the target chain parameters for a given collateral token.
     * @dev This is an admin function.
     * @param _collateralToken The collateral token address.
     * @param _chainSelector The CCIP chain selector for the target chain.
     * @param _borrowManagementContract The address of the BorrowManagement contract on the target chain.
     */
    function setTargetChainParams(address _collateralToken, uint64 _chainSelector, address _borrowManagementContract)
        external;
}
