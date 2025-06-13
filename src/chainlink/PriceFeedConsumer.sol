// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title The PriceConsumerV3 contract
 * @notice Acontract that returns latest price from Chainlink Price Feeds
 */
contract PriceFeedConsumer {
    mapping(address => AggregatorV3Interface) internal priceFeeds; // support token -> price feed mapping

    /**
     * @notice Returns the latest price
     *
     * @return latest price
     */
    /**
     * @notice Returns the latest price
     *
     * @return latest price
     */
    function getLatestPrice(address supportToken) public view returns (int256) {
        (
            ,
            /* uint80 roundID */
            int256 price,
            ,
            ,
        ) = /* uint256 startedAt */
        /* uint256 timeStamp */
        /* uint80 answeredInRound */
         AggregatorV3Interface(priceFeeds[supportToken]).latestRoundData();
        return price;
    }

    /**
     * @notice Returns the Price Feed address
     *
     * @return Price Feed address
     */
    function getPriceFeed(address supportToken) public view returns (AggregatorV3Interface) {
        return priceFeeds[supportToken];
    }
}
