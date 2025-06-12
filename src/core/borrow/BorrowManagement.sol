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
    BorrowStatus,
    BorrowTokenInfoFromTargetChain
} from "src/core/interfaces/IBorrowManagement.sol";

// below as the cross-chain borrow info
import {DepositCollateralInfo} from "src/core/interfaces/ICollManagement.sol";

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    address public immutable BORROW_USDC; // the only borrow token supported now

    mapping(address => mapping(address => bool)) public supportBorrowCollToken;
    mapping(address => AvaiableBorrowBalance) public availableBorrowTokenBalances; // for borrow token, current only support USDC

    event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);
    // TODO check below params
    //INIITIAL
    event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);
    event BorrowConfirmed(
        address indexed initiator, address indexed collateralToken, address borrowToken, uint256 confirmedAmount
    );

    // todo add errors

    error NOBorrowInfo(address user, address borrowToken);
    error BorrowAmountNOMathch(address user, address borrowToken, uint256 amount);
    error BorrowInfoNOConfirmed(address user, address borrowToken);

    constructor(address _borrowToken, address _collateralToken, address routerAddress)
        Ownable(msg.sender)
        CCIPReceiver(routerAddress)
    {
        BORROW_USDC = _borrowToken;
        supportBorrowCollToken[_borrowToken][_collateralToken] = true; // default support USDC and the collateral token
    }

    // TODO make it work with CCIP
    function borrowPending(uint256 amount) external {
        // front-end can check how much token can be borrowed

        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalances[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        // TODO package availableBorrowTokenBalances[msg.sender] to souce chain
        availableBorrowTokenBalances[msg.sender].pendingAmount + amount; // update the pending amount
        availableBorrowTokenBalances[msg.sender].status = BorrowStatus.PENDING; // update the status to PENDING
        availableBorrowTokenBalances[msg.sender].updatedAt = uint64(block.timestamp); // update the timestamp
            // Send the message through the router and store the returned message ID
            // messageId = routerAddress.ccipSend(destinationChainSelector, message);
    }

    function borrowByConfirmed(uint256 amount) external {
        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalances[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        if (availableBorrowTokenBalances[msg.sender].pendingAmount != amount) {
            revert BorrowAmountNOMathch(msg.sender, BORROW_USDC, amount);
        }

        if (availableBorrowTokenBalances[msg.sender].status != BorrowStatus.CONFIRMED) {
            revert BorrowInfoNOConfirmed(msg.sender, BORROW_USDC);
        }

        availableBorrowTokenBalances[msg.sender].borrowedAmount += amount; // update the borrowed amount
        availableBorrowTokenBalances[msg.sender].pendingAmount = 0; // reset the pending amount
        availableBorrowTokenBalances[msg.sender].status = BorrowStatus.BORROWED; // update the status to BORROWED
        availableBorrowTokenBalances[msg.sender].updatedAt = uint64(block.timestamp); // update the timestamp

        IERC20(BORROW_USDC).safeTransfer(msg.sender, amount); // transfer the borrowed amount to the user

        emit UserBorrowed(msg.sender, BORROW_USDC, amount, block.timestamp);
    }

    // TODO add other necessary checks
    function repay(uint256 amount) external {
        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalances[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        IERC20(BORROW_USDC).safeTransferFrom(msg.sender, address(this), amount); // transfer the repay amount from the user to the contract
        availableBorrowTokenBalances[msg.sender].borrowedAmount -= amount; // update the borrowed amount
    }

    // BorrowStatus.INIITIAL should be called by CCIP
    function borrowInitial(Client.Any2EVMMessage memory message) external {
        // TODO, unify the data for cross-chain Status.INIITIAL
        AvaiableBorrowBalance memory avaiableBorrowBalance = abi.decode(message.data, (AvaiableBorrowBalance));

        //  check recipientAddress, enter privacy mode

        avaiableBorrowBalance.updatedAt = uint64(block.timestamp);
        avaiableBorrowBalance.status = BorrowStatus.INIITIAL; // initial status

        //TODO, should unify the data
        address recipientAddress = address(0x001);
        availableBorrowTokenBalances[recipientAddress].borrowedAmount = 0;

        emit BorrowInitial(avaiableBorrowBalance.initiator, avaiableBorrowBalance.collateralToken, BORROW_USDC);
    }

    // BorrowStatus.CONFIRMED should be called by CCIP
    function borrowPendingConfirmed(Client.Any2EVMMessage memory message) external {
        // switch between the normal  and privacy mode

        // TODO, unify the data for cross-chain Status.PENDING
        AvaiableBorrowBalance memory avaiableBorrowBalance = abi.decode(message.data, (AvaiableBorrowBalance));

        avaiableBorrowBalance.updatedAt = uint64(block.timestamp);
        avaiableBorrowBalance.status = BorrowStatus.CONFIRMED;

        //TODO, should unify the data
        address recipientAddress = address(0x001);
        availableBorrowTokenBalances[recipientAddress] = avaiableBorrowBalance;

        emit BorrowConfirmed(
            avaiableBorrowBalance.initiator,
            avaiableBorrowBalance.collateralToken,
            BORROW_USDC,
            avaiableBorrowBalance.pendingAmount
        );
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {}
}
