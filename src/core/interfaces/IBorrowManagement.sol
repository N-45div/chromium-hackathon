// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// todo how to guarantee the price consistancy between the source chain and the target chain?

struct AvaiableBorrowInfo {
    address recipientAddress; // zero address means no specify(privacy situation)
    address collateralToken;
    uint256 collateralAmount;
    uint8 targetChainId;
    uint64 collateralRatio; // get by the source chain
    // the available amount is the amount that can be borrowed on the target chain
    address borrowToken;
    uint256 availableAmount;
    uint64 updatedAt; // timestamp of the last update
}

interface ICollManagement {
    function borrowEnableBySourceChain(AvaiableBorrowInfo memory avaiableBorrowInfo) external returns (bool);

    function borrowSelectedToken(address borrowToken) external returns (bool);

    function repayBorrowedToken(address borrowToken, uint256 amount) external returns (bool);

    function setSupportedBorrowCollToken(address collateralToken, address borrowToken) external;
}
