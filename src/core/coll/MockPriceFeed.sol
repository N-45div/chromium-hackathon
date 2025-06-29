// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockPriceFeed is AggregatorV3Interface {
    address public owner;
    int256 public price;
    uint8 public constant DECIMALS = 8; // Standard for ETH/USD feeds

    constructor(int256 _initialPrice) {
        owner = msg.sender;
        price = _initialPrice;
    }

    function setPrice(int256 _newPrice) public {
        require(msg.sender == owner, "Only owner can set price");
        price = _newPrice;
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    function description() external pure override returns (string memory) {
        return "Mock ETH/USD Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, price, block.timestamp, block.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        // A simple mock implementation
        return (uint80(1), price, block.timestamp, block.timestamp, uint80(1));
    }
}
