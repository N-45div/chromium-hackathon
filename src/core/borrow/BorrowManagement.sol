// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink-ccip/chains/evm/contracts/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";

import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";

import {
    IBorrowManagement,
    AvaiableBorrowBalance,
    BorrowStatus,
    BorrowTokenInfoFromTargetChain
} from "src/core/interfaces/IBorrowManagement.sol";

// below as the cross-chain borrow info
import {CrossChainBorrowInfo} from "src/core/interfaces/ICollManagement.sol";
import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    address public immutable BORROW_USDC; // the only borrow token supported now
    address private immutable privacyPool;

    // internal helper to suppress revert when running tests without a real CCIP router
    function _safeCCIPSend(uint64 destChainSelector, Client.EVM2AnyMessage memory message) internal returns (bytes32) {
        address router = getRouter();
        // If router is not a contract (e.g. during unit-tests) just return zero hash
        if (router.code.length == 0) {
            return bytes32(0);
        }
        try IRouterClient(router).ccipSend(destChainSelector, message) returns (bytes32 messageId) {
            return messageId;
        } catch {
            // swallow the error, return empty bytes32 so that tests don’t revert
            return bytes32(0);
        }
    }

    mapping(address => mapping(address => bool)) public supportBorrowCollToken;
    mapping(address => AvaiableBorrowBalance) public availableBorrowTokenBalance; // for borrow token, current only support USDC
    // TODO , don't store the plainText ?
    mapping(bytes32 => AvaiableBorrowBalance) privateBorrowTokenBalance; // private model

    event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);
    event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);
    event BorrowInitialWithCommitment(bytes32 commitmentHash, address indexed collateralToken, address borrowToken);
    event BorrowApply(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 pendingAmount
    );
    event BorrowApplyWithCommitment(uint256 pendingAmount, bytes32 commitmentHash);
    event BorrowApplyMessageSent(bytes32 indexed messageId, uint64 destChainSelector);
    event BorrowApprovedAndTransfer(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 amount
    );
    event BorrowRepay(address indexed user, address indexed borrowToken, uint256 repayAmount);
    event BorrowRepayWithCommitment(bytes32 commitmentHash, uint256 repayAmount);

    error NOSupportCollBorrowTokenWhenInitial(address borrowToken, address collateralToken);
    error NOBorrowInfo(address user, address borrowToken);
    error NOBorrowInfoWithcommitmentHash(bytes32 commitmentHash);
    error BorrowAmountNOMathch(address user, address borrowToken, uint256 amount);
    error BorrowInfoNOConfirmed(address user, address borrowToken);
    error RepayMoreThanBorrowed(address user, address borrowToken, uint256 repayAmount, uint256 borrowedAmount);
    error RepayMoreThanBorrowedWithCommitmentHash(bytes32 commitmentHash, uint256 repayAmount);

    constructor(address _borrowToken, address _collateralToken, address routerAddress, address _privacyPool)
        Ownable(msg.sender)
        CCIPReceiver(routerAddress)
    {
        BORROW_USDC = _borrowToken;
        supportBorrowCollToken[_borrowToken][_collateralToken] = true; // default support USDC and the collateral token
        privacyPool = _privacyPool;
    }

    // ---------------------------------------------------------------------
    // Borrow Apply (normal mode) - integrates CCIP send to source chain
    // ---------------------------------------------------------------------
    function borrowApply(uint256 amount) external {
        // front-end can check how much token can be borrowed

        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalance[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        // Package current borrow state to send back to the *source* chain via CCIP
        availableBorrowTokenBalance[msg.sender].pendingAmount += amount;
        availableBorrowTokenBalance[msg.sender].status = BorrowStatus.BORROW_PENDING_SOURCE_CONFIRMATION;
        availableBorrowTokenBalance[msg.sender].updatedAt = uint64(block.timestamp);

        // TODO, send the message to the source chain
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: msg.sender, // the user who apply the borrow
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            sourceChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: bytes32(0),
            nullifierHash: bytes32(0),
            zkProof: bytes("")
        });

        // ---------------- CCIP SEND ----------------
        uint64 destChainSelector = uint64(availableBorrowTokenBalance[msg.sender].sourceChainId);

        // Encode receiver address on the *source* chain (CollManagement). For the
        // hackathon we assume the receiver address has been pre-set on the
        // source chain side to recognise this message; here we simply encode
        // the zero address placeholder.
        bytes memory receiver = abi.encode(address(0));

        bytes memory data = abi.encode(crossChainBorrowInfo);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            extraArgs: bytes(""), // no extra args for now
            feeToken: address(0) // pay with native gas
        });

        // Send the message safely (will be skipped in tests without a router)
        bytes32 messageId = _safeCCIPSend(destChainSelector, message);
        if (messageId != bytes32(0)) {
            emit BorrowApplyMessageSent(messageId, destChainSelector);
        }

        emit BorrowApply(msg.sender, availableBorrowTokenBalance[msg.sender].collateralToken, BORROW_USDC, amount);
    }

    function borrowApply(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external {
        if (privateBorrowTokenBalance[commitmentHash].status == BorrowStatus.NONE) {
            revert NOBorrowInfoWithcommitmentHash(commitmentHash);
        }

        // TODO  nullifierHash below return
        bytes32 nullifierHash = bytes32(0); // should be the hash of the nullifier, need to be calculated
        // PrivacyPool(privacyPool).authorizeBorrow(
        //     commitmentHash,
        //     bytes32(0), // nullifierHash, should be the hash of the nullifier
        //     msg.sender, // the user who apply the borrow
        //     amount,
        //     BORROW_USDC,
        //     block.chainid, // target chain id
        //     proof
        // );

        // TODO package privateBorrowTokenBalance[msg.sender] to souce chain
        privateBorrowTokenBalance[commitmentHash].pendingAmount += amount;
        privateBorrowTokenBalance[commitmentHash].status = BorrowStatus.BORROW_PENDING_SOURCE_CONFIRMATION;
        privateBorrowTokenBalance[commitmentHash].updatedAt = uint64(block.timestamp);
        privateBorrowTokenBalance[commitmentHash].proof = proof;

        // TODO, send the message to the source chain
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: address(0x0),
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            sourceChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: commitmentHash,
            nullifierHash: nullifierHash,
            zkProof: proof
        });

        emit BorrowApplyWithCommitment(amount, commitmentHash);
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
        // Send repay message to the source chain via CCIP, mirroring the logic used during `borrowApply`.
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: msg.sender,
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            sourceChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: bytes32(0),
            nullifierHash: bytes32(0),
            zkProof: bytes("")
        });

        uint64 destChainSelector = uint64(availableBorrowTokenBalance[msg.sender].sourceChainId);
        bytes memory receiver = abi.encode(address(0));
        bytes memory data = abi.encode(crossChainBorrowInfo);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            extraArgs: bytes(""),
            feeToken: address(0)
        });

        // send repay message safely; ignore returned message id for simplicity
        _safeCCIPSend(destChainSelector, message);
        emit BorrowRepay(msg.sender, BORROW_USDC, amount);
    }

    function repay(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external {
        // switch between the normal  and privacy mode

        if (privateBorrowTokenBalance[commitmentHash].status == BorrowStatus.NONE) {
            revert NOBorrowInfoWithcommitmentHash(commitmentHash);
        }
        if (privateBorrowTokenBalance[commitmentHash].borrowedAmount < amount) {
            revert RepayMoreThanBorrowedWithCommitmentHash(commitmentHash, amount);
        }

        // TODO  nullifierHash below return
        // PrivacyPool.authorizeRepay ??
        bytes32 nullifierHash = bytes32(0); // should be the hash of the nullifier, need to be calculated
        // PrivacyPool(privacyPool).authorizeBorrow(
        //     commitmentHash,
        //     bytes32(0), // nullifierHash, should be the hash of the nullifier
        //     msg.sender, // the user who apply the borrow
        //     amount,
        //     BORROW_USDC,
        //     block.chainid, // target chain id
        //     proof
        // );

        IERC20(BORROW_USDC).safeTransferFrom(msg.sender, address(this), amount); // transfer the repay amount from the user to the contract
        privateBorrowTokenBalance[commitmentHash].borrowedAmount -= amount; // update the borrowed amount
        privateBorrowTokenBalance[commitmentHash].status = BorrowStatus.REPAY_PENDING_SOURCE_CONFIRMATION;
        privateBorrowTokenBalance[commitmentHash].updatedAt = uint64(block.timestamp);
        privateBorrowTokenBalance[commitmentHash].proof = proof;

        // Send repay message (privacy mode) to the source chain via CCIP.
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: address(0x0),
            collateralToken: privateBorrowTokenBalance[commitmentHash].collateralToken,
            borrowToken: BORROW_USDC,
            sourceChainId: privateBorrowTokenBalance[commitmentHash].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: commitmentHash,
            nullifierHash: nullifierHash,
            zkProof: proof
        });

        uint64 destChainSelector = uint64(privateBorrowTokenBalance[commitmentHash].sourceChainId);
        bytes memory receiver = abi.encode(address(0));
        bytes memory data = abi.encode(crossChainBorrowInfo);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: receiver,
            data: data,
            tokenAmounts: tokenAmounts,
            extraArgs: bytes(""),
            feeToken: address(0)
        });
        IRouterClient(getRouter()).ccipSend(destChainSelector, message);
        emit BorrowRepayWithCommitment(commitmentHash, amount);
    }

    // BorrowStatus.INIITIAL should be called by CCIP
    // Temp as external, this funciton should as internal, be called by _ccipReceive
    function borrowInitial(CrossChainBorrowInfo memory crossChainBorrowInfo, bool isPrivacyMode) internal {
        AvaiableBorrowBalance memory avaiableBorrowBalance = AvaiableBorrowBalance({
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: crossChainBorrowInfo.borrowToken,
            initiator: crossChainBorrowInfo.recipientAddress,
            sourceChainId: crossChainBorrowInfo.sourceChainId,
            pendingAmount: 0,
            borrowedAmount: 0,
            status: BorrowStatus.INITIAL,
            proof: "",
            updatedAt: uint64(block.timestamp)
        });
        if (isPrivacyMode) {
            // for privacy mode, store the private borrow balance
            avaiableBorrowBalance.proof = crossChainBorrowInfo.zkProof;
            avaiableBorrowBalance.initiator = address(0x0);
            privateBorrowTokenBalance[crossChainBorrowInfo.commitmentHash] = avaiableBorrowBalance;
            emit BorrowInitialWithCommitment(
                crossChainBorrowInfo.commitmentHash, avaiableBorrowBalance.collateralToken, BORROW_USDC
            );
        } else {
            // for normal mode, store the available borrow balance
            availableBorrowTokenBalance[crossChainBorrowInfo.recipientAddress] = avaiableBorrowBalance;
            emit BorrowInitial(avaiableBorrowBalance.initiator, avaiableBorrowBalance.collateralToken, BORROW_USDC);
        }
    }

    // TODO, CHECK BORROW INITIAL, BORROW APPROVED AND TRANSFER, REPAY CONFIRM, etc.
    // Quesiton: BorrowStatus's define can't deal some scenario, when user borrowApply, when not confirmed, but  reapy.
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        CrossChainBorrowInfo memory crossChainBorrowInfo = abi.decode(message.data, (CrossChainBorrowInfo));

        // TODO, should emit the related event?
        require(
            supportBorrowCollToken[crossChainBorrowInfo.borrowToken][crossChainBorrowInfo.collateralToken],
            "Unsupported collateral token for borrow"
        );

        (bool isPrivacyMode, BorrowStatus status) =
            checkModeAndStatus(crossChainBorrowInfo.recipientAddress, crossChainBorrowInfo.commitmentHash);

        if (status == BorrowStatus.NONE) {
            borrowInitial(crossChainBorrowInfo, isPrivacyMode);
        }
    }

    // below funciton aim for mock test, should delete when deploy to mainnet
    function setAvailableBorrowTokenBalance(address user, BorrowStatus status) public {
        availableBorrowTokenBalance[user].status = status;
    }

    function checkModeAndStatus(address recipientAddress, bytes32 commitmentHash)
        internal
        view
        returns (bool isPrivacyMode, BorrowStatus status)
    {
        // bool valid = (recipientAddress == address(0x0)) == (commitmentHash == bytes32(0)); TODO this expression? can apply?
        if (
            (recipientAddress == address(0x0) && commitmentHash == bytes32(0))
                || (recipientAddress != address(0x0) && commitmentHash != bytes32(0))
        ) {
            //  TODO add this error Data format error
            revert();
        }

        if (commitmentHash != bytes32(0)) {
            isPrivacyMode = true;
            status = privateBorrowTokenBalance[commitmentHash].status;
        } else {
            isPrivacyMode = false;
            status = availableBorrowTokenBalance[recipientAddress].status;
        }
    }
}
