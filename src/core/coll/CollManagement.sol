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

    mapping(address => mapping(address => bool)) public supportedCollBorrowToken;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(uint8 => TargetChainBorowInfo)) private crossBalances; // user => targetChainId => target borrow info

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount, uint8 targetChainId, address borrowToken);
    event CollateralWithdrawn(address indexed user, address indexed collateralToken, uint256 amount);

    function depositCollateral(address collateralToken, uint256 amount) external {
        // Implementation for depositing collateral
        // transfer the collateral token to this contract
    }
    function depositCollateral(DepositCollateralInfo memory depositInfo) external {
        // Implementation for depositing collateral with target chain selection
        // todo CCIP message for the target chain
    }

    function withdrawCollateral(address collateralTokenAddress, uint256 amount) external {
        // Implementation for withdrawing collateral
        // should check the borrow balance and ensure the user can withdraw
    }

    function setSupportedCollBorrowToken(address collateralToken, address borrowToken) external onlyAdmin {
        // Implementation for setting supported collateral token and borrow token
        supportedCollBorrowToken[collateralToken][borrowToken] = true;
    }

    function getAvaiableChainBorrowBalance(address user, uint8 targetChainId, address borrowToken) external view override returns (uint256) {
        // Implementation for getting available borrow balance on the target chain
        return collateralBalances[user][borrowToken];
    }
}
