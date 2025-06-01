// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Minimal mock lending contract for frontend integration
contract MockLending {
    mapping(address => uint256) public deposits;

    /// @notice User deposits native token (ETH/BNB/AVAX …)
    function deposit() external payable {
        deposits[msg.sender] += msg.value;
    }

    /// @notice User borrows `amount` (mock, no real token transfer)
    function borrow(uint256 amount) external {
        emit Borrow(msg.sender, amount);
    }

    event Borrow(address indexed user, uint256 amount);
}
