// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ICollManagement, DepositCollateralInfo, TargetChainBorowInfo} from 'src/core/interfaces/ICollManagement.sol';

contract CollManagement is ICollManagement {
    // todo only allow the CCIP caller to call this function
    modifier onlyCCIPCaller() {
        // todo add the related CCIP address
        _;
    }

    // TODO 
    modifier onlyAdmin() {
        _;
    }

    // TODO  collateralRatio all share same collateralRatio
    uint64 immutable collateralRatio = 150; 

    // TODO chainlink price feed 

    mapping(address => (address => bool)) public supportedCollBorrowToken;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(uint8 => TargetChainBorowInfo)) private crossBalances; // user => targetChainId => target borrow info

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount, uint8 targetChainId, address borrowToken);
    event CollateralWithdrawn(address indexed user, address indexed collateralToken, uint256 amount);

    function depositCollateral(address collateralToken, uint256 amount) external override {
        // Implementation for depositing collateral
        // transfer the collateral token to this contract
       
    }
    function depositCollateral(DepositCollateralInfo memory depositInfo) external override {
        // Implementation for depositing collateral with target chain selection
        // todo CCIP message for the target chain
    }

    function withdrawCollateral(address collateralTokenAddress, uint256 amount) external override {
        // Implementation for withdrawing collateral
        // should check the borrow balance and ensure the user can withdraw
    }

    function borrowTokeModifiedBySourceChain(TargetChainBorowInfo memory borrowInfo) external override onlyCCIPCaller returns (bool) {
        // Implementation for modifying the borrow token by the source chain
        // Update the collateral balance for the user on the target chain
        // TODO CCIP message to the target chain to update the borrow balance
        //collateralBalances[borrowInfo.recipientAddress][borrowInfo.borrowToken] todo modify the balance from the target chain

        return true;
    }

    function setSupportedCollBorrowToken(address collateralToken, address borrowToken) external onlyAdmin override {
        // Implementation for setting supported collateral token and borrow token
        supportedCollBorrowToken[collateralToken][borrowToken] = true;
    }

    function getAvaiableChainBorrowBalance(address user, uint8 targetChainId, address borrowToken) external view override returns (uint256) {
        // Implementation for getting available borrow balance on the target chain
        return collateralBalances[user][targetChainId].borrowToken == borrowToken ? 0 : 0; // Placeholder return value
    }
}
