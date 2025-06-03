// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IBorrowManagement, AvaiableBorrowInfo} from 'src/core/interfaces/IBorrowManagement.sol';

struct AvaiableBorrowBalance {
    uint256 maxAvailableAmount;
    uint64 updatedAt; // timestamp of the last update
}

contract BorrowManagement is IBorrowManagement {
    using SafeERC20 for IERC20;

    mapping(address => (address => bool)) public supportedBorrowCollToken;
    mapping(address => mapping(address => AvaiableBorrowInfo)) public availableBorrowTokenBalances;

    event BorrowEnabled(address indexed user, address indexed collateralToken, uint256 collateralTokenAmount, address indexed borrowToken, uint256 maxAvailableAmount);
    event BorrowModified(address indexed user, address indexed borrowToken, uint256 maxAvailableAmount);
    // todo only allow the CCIP caller to call this function
    modifier onlyCCIPCaller() {
        // todo add the related CCIP address
        _;
    }

    function borrowEnableBySourceChain(AvaiableBorrowInfo memory avaiableBorrowInfo) external override onlyCCIPCaller returns (bool) {
        // Implementation for enabling borrowing by the source chain

        // Calcuate the max available amount based on collateral ratio and collateral amount
        uint64 collateralRatio = avaiableBorrowInfo.collateralRatio;
        uint256 maxAvailableAmount = (avaiableBorrowInfo.collateralAmount * collateralRatio) / 100; // Assuming collateralRatio is in percentage
        AvaiableBorrowBalance availableBalance = new AvaiableBorrowBalance({maxAvailableAmount: avaiableBorrowInfo.availableAmount, updatedAt: uint64(block.timestamp)});
        // todo when recipientAddress as zero address, how to deal with the privacy issue?
        availableBorrowTokenBalances[avaiableBorrowInfo.recipientAddress][avaiableBorrowInfo.borrowToken] = availableBalance;
        emit BorrowEnabled(avaiableBorrowInfo.recipientAddress, avaiableBorrowInfo.collateralToken, avaiableBorrowInfo.collateralAmount, avaiableBorrowInfo.borrowToken, maxAvailableAmount);
        return true;
    }

    function borrowSelectedToken(address borrowToken, uint256 amount) external override returns (bool) {
        // Implementation for borrowing the selected token
        // This function should check if the borrowToken is available and if the user has enough collateral

        require(availableBorrowBalances[msg.sender][borrowToken].maxAvailableAmount > 0, 'Borrow token not available or insufficient collateral');
        require(availableBorrowBalances[msg.sender][borrowToken].maxAvailableAmount >= amount, 'Insufficient available borrow amount');

        // withdraw the amount from the available borrow balance
        availableBorrowBalances[msg.sender][borrowToken].maxAvailableAmount -= amount;
        // Transfer the borrowed amount to the user
        IERC20(borrowToken).safeTransfer(msg.sender, amount);
        emit BorrowModified(msg.sender, borrowToken, availableBorrowBalances[msg.sender][borrowToken].maxAvailableAmount);
        // CCIP message to the target chain to update the borrow balance

        return true;
    }

    function repayBorrowedToken(address borrowToken, uint256 amount) external override returns (bool) {

        return true;
    }

    // TODO below config can be set by the CCIP message
    function setSupportedBorrowCollToken(address collateralToken, address borrowToken) internal override {
        // Implementation for setting supported borrow collateral token
        // This function can be used to add new supported collateral and borrow token pairs
        // For simplicity, we assume all pairs are supported
        // In a real implementation, you might want to maintain a list of supported pairs
    }
}
