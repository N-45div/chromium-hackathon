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
    SupportBorrowCollTokenInfo
} from "src/core/interfaces/IBorrowManagement.sol";

import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    address public immutable BORROW_USDC; // the only borrow token supported now
    address private immutable privacyPool;
    address private immutable linkToken; //now use link pay for the fees

    mapping(address => SupportBorrowCollTokenInfo) public supportBorrowCollTokenInfo; // TOOD chek supportBorrowCollTokenInfo is compatible with other components
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

    // TODO check the chinlink CCIP params, crossChainInfo params. work well with each other
    constructor(
        address _borrowToken,
        address _collateralToken,
        address _rounter,
        address _privacyPool,
        address _linkToken
    ) Ownable(msg.sender) CCIPReceiver(_rounter) {
        // TODO ajust below params
        BORROW_USDC = _borrowToken;
        SupportBorrowCollTokenInfo memory info = SupportBorrowCollTokenInfo({
            collateralToken: _collateralToken,
            sourceChainId: 0,
            sourceChainSelector: 0,
            sourceChainCollManager: address(0x0),
            isSupported: true
        });

        supportBorrowCollTokenInfo[_borrowToken] = info;

        privacyPool = _privacyPool;
        linkToken = _linkToken; // now use link pay for the fees
    }

    function borrowApply(uint256 amount) external {
        // front-end can check how much token can be borrowed

        // switch between the normal  and privacy mode

        if (availableBorrowTokenBalance[msg.sender].status == BorrowStatus.NONE) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        // Package current borrow state to send back to the *source* chain via CCIP
        availableBorrowTokenBalance[msg.sender].pendingAmount += amount;
        availableBorrowTokenBalance[msg.sender].status = BorrowStatus.BORROW_PENDING_TARGET;
        availableBorrowTokenBalance[msg.sender].updatedAt = uint64(block.timestamp);

        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: msg.sender, // the user who apply the borrow
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: block.chainid,
            targetChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            commitmentHash: bytes32(0),
            depositor: availableBorrowTokenBalance[msg.sender].initiator,
            nullifierHash: bytes32(0),
            zkProof: bytes("")
        });

        _sendMessage(BORROW_USDC, abi.encode(crossChainBorrowInfo));

        emit BorrowApply(msg.sender, availableBorrowTokenBalance[msg.sender].collateralToken, BORROW_USDC, amount);
    }

    function borrowApply(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external {
        if (privateBorrowTokenBalance[commitmentHash].status == BorrowStatus.NONE) {
            revert NOBorrowInfoWithcommitmentHash(commitmentHash);
        }

        // todo add related privacy logic
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

        privateBorrowTokenBalance[commitmentHash].pendingAmount += amount;
        privateBorrowTokenBalance[commitmentHash].status = BorrowStatus.BORROW_PENDING_TARGET;
        privateBorrowTokenBalance[commitmentHash].updatedAt = uint64(block.timestamp);
        privateBorrowTokenBalance[commitmentHash].proof = proof;

        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: address(0x0),
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: commitmentHash,
            depositor: address(0x0), // TODO
            nullifierHash: nullifierHash,
            zkProof: proof
        });

        // TODO
        // _sendMessage(BORROW_USDC, abi.encode(crossChainBorrowInfo));

        emit BorrowApplyWithCommitment(amount, commitmentHash);
    }

    function repayApply(uint256 amount) external {
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
        availableBorrowTokenBalance[msg.sender].status = BorrowStatus.REPAY_PENDING_TARGET;
        availableBorrowTokenBalance[msg.sender].updatedAt = uint64(block.timestamp);

        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: msg.sender,
            collateralToken: availableBorrowTokenBalance[msg.sender].collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.REPAY_PENDING_TARGET,
            sourceChainId: availableBorrowTokenBalance[msg.sender].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: bytes32(0),
            depositor: availableBorrowTokenBalance[msg.sender].initiator,
            nullifierHash: bytes32(0),
            zkProof: bytes("")
        });

        // TODO complete below logic
        // _sendMessage(BORROW_USDC, abi.encode(crossChainBorrowInfo));

        emit BorrowRepay(msg.sender, BORROW_USDC, amount);
    }

    function repayApply(uint256 amount, bytes32 commitmentHash, bytes calldata proof) external {
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
        privateBorrowTokenBalance[commitmentHash].status = BorrowStatus.REPAY_PENDING_TARGET;
        privateBorrowTokenBalance[commitmentHash].updatedAt = uint64(block.timestamp);
        privateBorrowTokenBalance[commitmentHash].proof = proof;

        // Send repay message (privacy mode) to the source chain via CCIP.
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: address(0x0),
            collateralToken: privateBorrowTokenBalance[commitmentHash].collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.REPAY_PENDING_TARGET,
            sourceChainId: privateBorrowTokenBalance[commitmentHash].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: commitmentHash,
            depositor: address(0x0), // TODO
            nullifierHash: nullifierHash,
            zkProof: proof
        });

        // TODO complete below logic
        // _sendMessage(BORROW_USDC, abi.encode(crossChainBorrowInfo));

        emit BorrowRepayWithCommitment(commitmentHash, amount);
    }

    // Prepare the params for CCIP
    function initSourceChainParamsForCCIP(
        address borrowToken,
        address sourceChainCollManager,
        uint64 sourceChainSelector
    ) external onlyOwner {
        supportBorrowCollTokenInfo[borrowToken].sourceChainSelector = sourceChainSelector;

        // targetChainSelector fixed value for chainlink ccip
        supportBorrowCollTokenInfo[borrowToken].sourceChainCollManager = sourceChainCollManager;
    }

    // Initial user's borrow info(normal and privacy mode)
    function borrowInitial(CrossChainBorrowInfo memory crossChainBorrowInfo, bool isPrivacyMode) internal {
        AvaiableBorrowBalance memory avaiableBorrowBalance = AvaiableBorrowBalance({
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: crossChainBorrowInfo.borrowToken,
            initiator: crossChainBorrowInfo.depositor,
            sourceChainId: crossChainBorrowInfo.sourceChainId,
            pendingAmount: 0,
            borrowedAmount: 0,
            status: BorrowStatus.INITIAL,
            proof: "",
            updatedAt: uint64(block.timestamp)
        });

        // TODO where place ?
        supportBorrowCollTokenInfo[crossChainBorrowInfo.borrowToken].sourceChainId = crossChainBorrowInfo.sourceChainId;

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

    // Source chain confirmed the borrow, and transfer the borrow token to the recipient address
    function borrowApprovedAndTransfer(address recipientAddress) internal {
        // TODO check data format
        // switch between the normal  and privacy mode

        // get the recipient address from the CCIP message or the automation service
        uint256 amount = availableBorrowTokenBalance[recipientAddress].pendingAmount;

        availableBorrowTokenBalance[recipientAddress].borrowedAmount += amount;
        availableBorrowTokenBalance[recipientAddress].pendingAmount = 0;
        availableBorrowTokenBalance[recipientAddress].status = BorrowStatus.BORROW_CONFIRMED_TARGET;
        availableBorrowTokenBalance[recipientAddress].updatedAt = uint64(block.timestamp);

        IERC20(BORROW_USDC).safeTransfer(recipientAddress, amount);

        emit BorrowApprovedAndTransfer(
            recipientAddress, availableBorrowTokenBalance[recipientAddress].collateralToken, BORROW_USDC, amount
        );
    }

    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        CrossChainBorrowInfo memory crossChainBorrowInfo = abi.decode(message.data, (CrossChainBorrowInfo));

        // TODO, should emit the related event?
        // require(
        //     supportBorrowCollTokenInfo[crossChainBorrowInfo.borrowToken].isSupported,
        //     "Unsupported collateral token for borrow"
        // );

        (bool isPrivacyMode, BorrowStatus status) = crossChainBorrowInfo.checkModeAndStatus();

        // TODO, CHECK BORROW INITIAL, BORROW APPROVED AND TRANSFER, REPAY CONFIRM, etc.
        // Quesiton: BorrowStatus's define can't deal some scenario, when user borrowApply, when not confirmed, but  reapy.
        if (status == BorrowStatus.NONE) {
            borrowInitial(crossChainBorrowInfo, isPrivacyMode);
        } else if (status == BorrowStatus.BORROW_CONFIRMED_SOURCE) {
            borrowApprovedAndTransfer(crossChainBorrowInfo.recipientAddress);
        }
    }

    // For now, we just support 1=>1 format, user deposit one collateralToken and can only borrow one borrowToken in target chain

    function _sendMessage(address borrowToken, bytes memory data) internal returns (bytes32 messageId) {
        address sourceChainCollManager = supportBorrowCollTokenInfo[borrowToken].sourceChainCollManager;
        uint64 sourceChainSelector = supportBorrowCollTokenInfo[borrowToken].sourceChainSelector;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sourceChainCollManager),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0), // only send message without token transfer
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and allowing out-of-order execution.
                // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/concepts/best-practices/evm#using-extraargs
                Client.GenericExtraArgsV2({
                    gasLimit: 9_000_000, // Gas limit for the callback on the destination chain
                    allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                })
            ),
            // extraArgs: "",
            feeToken: linkToken
        });

        // Initialize a router client instance to interact with cross-chain router
        // CHECKING ........................
        IRouterClient router = IRouterClient(getRouter());
        // CHECKING ........................
        uint256 fee = IRouterClient(router).getFee(sourceChainSelector, message);
        IERC20(linkToken).approve(address(router), fee);

        messageId = IRouterClient(router).ccipSend(sourceChainSelector, message);
        // TODO based on messageId. emit or integrate with front-end AI
    }
    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////

    // For link gas usage
    function transferLinkToken(address to, uint256 amount) external onlyOwner {
        // Allow the owner to withdraw LINK tokens from the contract
        IERC20(linkToken).transfer(to, amount);
    }
}
