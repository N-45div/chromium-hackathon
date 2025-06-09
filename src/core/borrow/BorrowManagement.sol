// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// todo add chainlink price feed
// todo add CCIP
import {CCIPReceiver} from "@chainlink-ccip/chains/evm/contracts/applications/CCIPReceiver.sol";
// TODO import issue for CCIP
import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";

import {
    IBorrowManagement,
    AvaiableBorrowBalance,
    BorrowTokenInfoFromTargetChain
} from "src/core/interfaces/IBorrowManagement.sol";

// below as the cross-chain borrow info
import {DepositCollateralInfo} from "src/core/interfaces/ICollManagement.sol";

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => bool)) public supportedBorrowCollToken;
    mapping(address => AvaiableBorrowBalance) public availableBorrowTokenBalances; // for borrow token, current only support USDC
    //This is a complement to the BorrowApproved and userBorrowed declaration
    mapping(address => uint256) public userBorrowed;

    event BorrowApproved(address indexed user, uint256 amount);
    event BorrowEnabled(
        address indexed user,
        address indexed collateralToken,
        uint256 collateralTokenAmount,
        address indexed borrowToken,
        uint256 maxAvailableAmount
    );
    event BorrowModified(address indexed user, address indexed borrowToken, uint256 maxAvailableAmount);

    // todo add errors

    constructor(address routerAddress) Ownable(msg.sender) CCIPReceiver(routerAddress) {}

    //  only support USDC for now
    function borrow(address borrowToken, uint256 amount) external returns (bool) {
        // todo check AvaiableBorrowBalance, then update
        return true;
    }

    function repay(address borrowToken, uint256 amount) external returns (bool) {
        // todo check AvaiableBorrowBalance, then update
        return true;
    }

    function setSupportBorrowCollToken(address borrowToken, address collateralToken) external onlyOwner {
        supportedBorrowCollToken[borrowToken][collateralToken] = true;
    }

    // ===================== The main process of core cross-chain message processing =====================
    /**
     * @notice Receive the loan message sent by the source chain and complete the operation such as lending to the target chain
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        AvaiableBorrowBalance memory avaiableBorrowBalance = abi.decode(message, (AvaiableBorrowBalance));
        // check supportedBorrowCollToken
        borrowEnableBySourceChain(avaiableBorrowBalance);
    }

    function borrowEnableBySourceChain(DepositCollateralInfo memory depositCollateralInfo) internal {
        // Implementation for enabling borrowing by the source chain

        // Calcuate the max available amount based on collateral ratio and collateral amount
        uint64 collateralRatio = depositCollateralInfo.collateralRatio;
        // Calcuate the max available amount based on collateral ratio and collateral amount
        // TODO update the AvaiableBorrowInfo for user
        // struct AvaiableBorrowBalance {
        //     address recipientAddress; // zero address means no specify(privacy situation)
        //     address collateralToken;
        //     uint256 collateralAmount;
        //     uint256 sourceChainId;
        //     uint64 collateralRatio; // get by the source chain
        //     // the available amount is the amount that can be borrowed on the target chain
        //     address borrowToken;
        //     uint256 availableAmount;
        //     uint64 updatedAt; // timestamp of the last update
        // }

        // emit BorrowEnabled(
        //     avaiableBorrowBalance.recipientAddress,
        //     avaiableBorrowBalance.collateralToken,
        //     avaiableBorrowBalance.collateralAmount,
        //     avaiableBorrowBalance.borrowToken,
        //     maxAvailableAmount
        // );
    }
}
