// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink-ccip/chains/evm/contracts/applications/CCIPReceiver.sol";

import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";

import {
    IBorrowManagement,
    AvaiableBorrowBalance,
    BorrowStatus,
    BorrowTokenInfoFromTargetChain
} from "src/core/interfaces/IBorrowManagement.sol";

// below as the cross-chain borrow info
import {CrossChainBorrowInfo} from "src/core/interfaces/ICollManagement.sol";

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    address public immutable BORROW_USDC; // the only borrow token supported now

    mapping(address => mapping(address => bool)) public supportBorrowCollToken;
    mapping(address => AvaiableBorrowBalance) public availableBorrowTokenBalance; // for borrow token, current only support USDC

    event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);
    event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);
    event BorrowApply(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 pendingAmount
    );
    event BorrowApprovedAndTransfer(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 amount
    );
    event BorrowRepay(address indexed user, address indexed borrowToken, uint256 repayAmount);

    error NOSupportCollBorrowTokenWhenInitial(address borrowToken, address collateralToken);
    error NOBorrowInfo(address user, address borrowToken);
    error BorrowAmountNOMathch(address user, address borrowToken, uint256 amount);
    error BorrowInfoNOConfirmed(address user, address borrowToken);
    error RepayMoreThanBorrowed(address user, address borrowToken, uint256 repayAmount, uint256 borrowedAmount);

    constructor(address _borrowToken, address _collateralToken, address routerAddress)
        Ownable(msg.sender)
        CCIPReceiver(routerAddress)
    {
        BORROW_USDC = _borrowToken;
        supportBorrowCollToken[_borrowToken][_collateralToken] = true; // default support USDC and the collateral token
    }

    // TODO make it work with CCIP
    function borrowApply(uint256 amount) external {
        // front-end can check how much token can be borrowed

        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalance[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        // TODO package availableBorrowTokenBalance[msg.sender] to souce chain
        availableBorrowTokenBalance[msg.sender].pendingAmount += amount;
        availableBorrowTokenBalance[msg.sender].status = BorrowStatus.BORROW_PENDING_SOURCE_CONFIRMATION;
        availableBorrowTokenBalance[msg.sender].updatedAt = uint64(block.timestamp);

        // TODO, send the message to the source chain
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: msg.sender, // the user who apply the borrow
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            sourceChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            targetChainId: block.chainid
        });

        emit BorrowApply(msg.sender, availableBorrowTokenBalance[msg.sender].collateralToken, BORROW_USDC, amount);
    }

    // Only Called by CCIP or the automation service
    // When approved, automatically transfer the borrow token to the user
    function borrowApprovedAndTransfer(address recipientAddress) external {
        // switch between the normal  and privacy mode

        // get the recipient address from the CCIP message or the automation service
        uint256 amount = availableBorrowTokenBalance[recipientAddress].pendingAmount;

        availableBorrowTokenBalance[recipientAddress].borrowedAmount += amount;
        availableBorrowTokenBalance[recipientAddress].pendingAmount = 0;
        availableBorrowTokenBalance[recipientAddress].status = BorrowStatus.BORROW_APPROVED_BY_SOURCE;
        availableBorrowTokenBalance[recipientAddress].updatedAt = uint64(block.timestamp);

        IERC20(BORROW_USDC).safeTransfer(recipientAddress, amount);

        emit BorrowApprovedAndTransfer(
            recipientAddress, availableBorrowTokenBalance[recipientAddress].collateralToken, BORROW_USDC, amount
        );
    }

    // TODO add other necessary checks
    function repay(uint256 amount) external {
        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalance[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }
        if (availableBorrowTokenBalance[msg.sender].borrowedAmount < amount) {
            revert RepayMoreThanBorrowed(
                msg.sender, BORROW_USDC, amount, availableBorrowTokenBalance[msg.sender].borrowedAmount
            );
        }

        IERC20(BORROW_USDC).safeTransferFrom(msg.sender, address(this), amount); // transfer the repay amount from the user to the contract
        availableBorrowTokenBalance[msg.sender].borrowedAmount -= amount; // update the borrowed amount
        availableBorrowTokenBalance[msg.sender].status = BorrowStatus.REPAY_PENDING_SOURCE_CONFIRMATION;
        availableBorrowTokenBalance[msg.sender].updatedAt = uint64(block.timestamp);
        // TOOD CCIP send the message to the source chain (how to guarantee the consistancy for repay between the source chain and the target chain?)
        emit BorrowRepay(msg.sender, BORROW_USDC, amount);
    }

    // BorrowStatus.INIITIAL should be called by CCIP
    // Temp as external, this funciton should as internal, be called by _ccipReceive
    function borrowInitial(CrossChainBorrowInfo memory crossChainBorrowInfo) external {
        // TODO, unify the data for cross-chain Status.INIITIAL
        // CrossChainBorrowInfo memory crossChainBorrowInfo = abi.decode(message.data, (CrossChainBorrowInfo));

        if (!supportBorrowCollToken[crossChainBorrowInfo.borrowToken][crossChainBorrowInfo.collateralToken]) {
            revert NOSupportCollBorrowTokenWhenInitial(
                crossChainBorrowInfo.borrowToken, crossChainBorrowInfo.collateralToken
            );
        }

        AvaiableBorrowBalance memory avaiableBorrowBalance = AvaiableBorrowBalance({
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: crossChainBorrowInfo.borrowToken,
            initiator: crossChainBorrowInfo.recipientAddress,
            sourceChainId: crossChainBorrowInfo.sourceChainId,
            pendingAmount: 0,
            borrowedAmount: 0,
            status: BorrowStatus.INITIAL,
            proof: "",
            commit: "",
            updatedAt: uint64(block.timestamp)
        });

        availableBorrowTokenBalance[crossChainBorrowInfo.recipientAddress] = avaiableBorrowBalance;

        emit BorrowInitial(avaiableBorrowBalance.initiator, avaiableBorrowBalance.collateralToken, BORROW_USDC);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // borrowInitial(message);
    }

    // below funciton aim for mock test, should delete when deploy to mainnet
    function setAvailableBorrowTokenBalance(address user, BorrowStatus status) public {
        availableBorrowTokenBalance[user].status = status;
    }
}
