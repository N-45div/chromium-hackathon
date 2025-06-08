// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct BorrowInfo {
    address user;
    address token;
    uint256 amount;
    uint64 sourceChainSelector;
    uint64 targetChainSelector;
}
