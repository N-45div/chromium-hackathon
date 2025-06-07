// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract LendingSource {
    IERC20 public collateralToken;
    mapping(address => uint256) public collaterals;


    address public targetChainReceiver;
    uint64 public targetChainSelector;

    event CollateralDeposited(address indexed user, uint256 amount);

    constructor(address _collateralToken, address _targetChainReceiver, uint64 _targetChainSelector) {
        collateralToken = IERC20(_collateralToken);
        targetChainReceiver = _targetChainReceiver;
        targetChainSelector = _targetChainSelector;
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "Zero amount");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        collaterals[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);

        //------
    }


    function ccipReceive(bytes calldata message) external {
        (address user, uint256 borrowedAmount) = abi.decode(message, (address, uint256));

    }
}
