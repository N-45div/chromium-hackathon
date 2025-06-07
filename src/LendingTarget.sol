// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract LendingTarget {
    IERC20 public loanToken;
    address public sourceChainSender;
    uint64 public sourceChainSelector;

    event BorrowEnabled(address indexed user, uint256 amount);

    constructor(address _loanToken, address _sourceChainSender, uint64 _sourceChainSelector) {
        loanToken = IERC20(_loanToken);
        sourceChainSender = _sourceChainSender;
        sourceChainSelector = _sourceChainSelector;
    }


    function ccipReceive(bytes calldata message) external {
        (address user, uint256 collateralAmount) = abi.decode(message, (address, uint256));
        emit BorrowEnabled(user, collateralAmount);

    }


    function borrowEnableBySourceChain(address user, uint256 amount) external {
        loanToken.transfer(user, amount);

    }
}
