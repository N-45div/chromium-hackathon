pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";

import {
    IBorrowManagement,
    AvaiableBorrowBalance,
    SupportBorrowCollTokenInfo
} from "src/core/interfaces/IBorrowManagement.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";
import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable(msg.sender) {
    using SafeERC20 for IERC20;

    address public immutable BORROW_USDC;
    address private immutable privacyPool;
    address private immutable linkToken;

    mapping(address => SupportBorrowCollTokenInfo) public supportBorrowCollTokenInfo;
    mapping(address => AvaiableBorrowBalance) public availableBorrowTokenBalance;
    mapping(bytes32 => AvaiableBorrowBalance) privateBorrowTokenBalance;

    event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);
    event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);
    event BorrowInitialWithCommitment(bytes32 commitmentHash, address indexed collateralToken, address borrowToken);
    event BorrowApply(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 pendingAmount
    );
    event BorrowApplyWithCommitment(
        bytes32 indexed commitmentHash, address indexed recipientAddress, address borrowToken, uint256 pendingAmount
    );
    event BorrowApprovedAndTransfer(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 amount
    );
    event BorrowApprovedAndTransferWithCommitment(
        bytes32 indexed commitmentHash, address indexed recipientAddress, address indexed borrowToken, uint256 amount
    );
    event RepayApply(address indexed repayer, address indexed borrowToken, uint256 amount);
    event RepayApplyPrivate(
        bytes32 indexed commitmentHash, address indexed repayer, address indexed borrowToken, uint256 amount
    );
    event RepayApprovedPublic(address indexed repayer, address indexed borrowToken, uint256 amount);
    event RepayApprovedPrivate(
        bytes32 indexed commitmentHash, address indexed repayer, address indexed borrowToken, uint256 amount
    );

    error NOBorrowInfo(address user, address borrowToken);
    error RepayMoreThanBorrowed(address user, address borrowToken, uint256 repayAmount, uint256 borrowedAmount);

    constructor(address _borrowToken, address _router, address _privacyPool, address _linkToken)
        CCIPReceiver(_router)
    {
        BORROW_USDC = _borrowToken;
        privacyPool = _privacyPool;
        linkToken = _linkToken;
    }

    function setSourceChainParams(
        address _collateralToken,
        uint256 _sourceChainId,
        uint64 _sourceChainSelector,
        address _sourceChainCollManager,
        uint64 _ownChainSelector
    ) external onlyOwner {
        SupportBorrowCollTokenInfo storage sbtci = supportBorrowCollTokenInfo[BORROW_USDC];
        sbtci.collateralToken = _collateralToken;
        sbtci.sourceChainId = _sourceChainId;
        sbtci.sourceChainSelector = _sourceChainSelector;
        sbtci.sourceChainCollManager = _sourceChainCollManager;
        sbtci.ownChainSelector = _ownChainSelector;
        sbtci.isSupported = true;
    }

    // Public borrow application
    function borrowApply(uint256 amount) external {
        AvaiableBorrowBalance storage userBalance = availableBorrowTokenBalance[msg.sender];
        if (userBalance.status != BorrowStatus.INITIAL) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC);
        }

        userBalance.pendingAmount = amount;
        userBalance.status = BorrowStatus.BORROW_PENDING_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);

        CrossChainBorrowInfo memory ccbi = CrossChainBorrowInfo({
            recipientAddress: msg.sender,
            collateralToken: userBalance.collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainId,
            targetChainId: block.chainid,
            targetChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainSelector, // Selector for source chain (CollManagement)
            commitmentHash: bytes32(0),
            depositor: userBalance.initiator,
            nullifierHash: bytes32(0),
            zkProof: bytes(""),
            merkleRoot: bytes32(0)
        });

        _sendMessage(BORROW_USDC, abi.encode(ccbi), 100_000);

        emit BorrowApply(msg.sender, userBalance.collateralToken, BORROW_USDC, amount);
    }

    // Private ZK borrow application
    function borrowApplyPrivate(uint256 amount, bytes32 commitmentHash, address recipientAddress) external {
        require(recipientAddress != address(0), "Recipient address cannot be zero");
        AvaiableBorrowBalance storage userBalance = privateBorrowTokenBalance[commitmentHash];

        // Ensure this commitment has been initialized (e.g., by a cross-chain message after ZK deposit on source)
        if (userBalance.status != BorrowStatus.INITIAL) {
            revert NOBorrowInfo(recipientAddress, BORROW_USDC); // Using recipientAddress for error context
        }
        require(userBalance.pendingAmount == 0, "Existing pending borrow operation");

        userBalance.pendingAmount = amount;
        userBalance.status = BorrowStatus.BORROW_PENDING_TARGET;
        userBalance.recipientForZK = recipientAddress; // Store the intended recipient
        userBalance.updatedAt = uint64(block.timestamp);

        CrossChainBorrowInfo memory ccbi = CrossChainBorrowInfo({
            recipientAddress: recipientAddress, // Pass through the recipient for confirmation on source & return
            collateralToken: userBalance.collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainId,
            targetChainId: block.chainid,
            targetChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].ownChainSelector, // Selector for this (target) chain
            commitmentHash: commitmentHash,
            depositor: userBalance.initiator, // This should be the address that can authorize on source (e.g. PrivacyPool or user via PrivacyPool)
            nullifierHash: bytes32(0), // Not used on target for borrow apply
            zkProof: bytes(""), // Not used on target for borrow apply
            merkleRoot: userBalance.merkleRoot // Pass the merkleRoot associated with this commitment if needed by source
        });

        _sendMessage(BORROW_USDC, abi.encode(ccbi), 100_000); // Adjust gas as needed

        emit BorrowApplyWithCommitment(commitmentHash, recipientAddress, BORROW_USDC, amount);
    }

    function repayApply(uint256 amount) external {
        // Public repay
        AvaiableBorrowBalance storage userBalance = availableBorrowTokenBalance[msg.sender];
        if (userBalance.borrowedAmount < amount) {
            revert RepayMoreThanBorrowed(msg.sender, BORROW_USDC, amount, userBalance.borrowedAmount);
        }

        IERC20(BORROW_USDC).safeTransferFrom(msg.sender, address(this), amount);

        userBalance.pendingAmount = amount;
        userBalance.status = BorrowStatus.REPAY_PENDING_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);

        CrossChainBorrowInfo memory ccbi = CrossChainBorrowInfo({
            recipientAddress: msg.sender,
            collateralToken: userBalance.collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.REPAY_PENDING_TARGET,
            sourceChainId: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainId,
            targetChainId: block.chainid,
            targetChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainSelector,
            commitmentHash: bytes32(0),
            depositor: userBalance.initiator,
            nullifierHash: bytes32(0),
            zkProof: bytes(""),
            merkleRoot: bytes32(0)
        });

        _sendMessage(BORROW_USDC, abi.encode(ccbi), 100_000);

        emit RepayApply(msg.sender, BORROW_USDC, amount);
    }

    // Private ZK repay application
    function repayApplyPrivate(bytes32 commitmentHash, uint256 amount) external {
        require(commitmentHash != bytes32(0), "Commitment hash cannot be zero");
        AvaiableBorrowBalance storage userBalance = privateBorrowTokenBalance[commitmentHash];

        if (userBalance.borrowedAmount == 0) {
            revert NOBorrowInfo(msg.sender, BORROW_USDC); // Or a more specific ZK error
        }
        if (userBalance.borrowedAmount < amount) {
            revert RepayMoreThanBorrowed(msg.sender, BORROW_USDC, amount, userBalance.borrowedAmount);
        }

        IERC20(BORROW_USDC).safeTransferFrom(msg.sender, address(this), amount);

        userBalance.pendingAmount = amount; // Using pendingAmount to track repay amount until confirmed
        userBalance.status = BorrowStatus.REPAY_PENDING_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);

        CrossChainBorrowInfo memory ccbi = CrossChainBorrowInfo({
            recipientAddress: userBalance.recipientForZK, // Or msg.sender if repay initiated by original recipient
            collateralToken: userBalance.collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.REPAY_PENDING_TARGET,
            sourceChainId: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainId,
            targetChainId: block.chainid,
            targetChainSelector: userBalance.ownChainSelector, // Use stored selector
            commitmentHash: commitmentHash, // Key for ZK repay
            depositor: userBalance.initiator, // Original initiator of the borrow
            nullifierHash: bytes32(0), // Not typically used in repay on target side
            zkProof: bytes(""), // Proof not typically used in repay on target side
            merkleRoot: userBalance.merkleRoot // Propagate if needed
        });

        _sendMessage(BORROW_USDC, abi.encode(ccbi), 100_000);

        emit RepayApplyPrivate(commitmentHash, msg.sender, BORROW_USDC, amount);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        CrossChainBorrowInfo memory crossChainBorrowInfo = abi.decode(message.data, (CrossChainBorrowInfo));

        if (crossChainBorrowInfo.status == BorrowStatus.INITIAL) {
            _borrowInitial(crossChainBorrowInfo);
        } else if (crossChainBorrowInfo.status == BorrowStatus.BORROW_PENDING_TARGET) {
            _executePrivateBorrow(crossChainBorrowInfo);
        } else if (crossChainBorrowInfo.status == BorrowStatus.BORROW_CONFIRMED_SOURCE) {
            (bool isPrivacyMode,) = crossChainBorrowInfo.checkModeAndStatus();
            if (isPrivacyMode) {
                _handlePrivateBorrowConfirmed(crossChainBorrowInfo);
            } else {
                _handlePublicBorrowConfirmed(crossChainBorrowInfo);
            }
        } else if (crossChainBorrowInfo.status == BorrowStatus.REPAY_CONFIRMED_SOURCE) {
            if (crossChainBorrowInfo.commitmentHash != bytes32(0)) {
                _handlePrivateRepayConfirmed(crossChainBorrowInfo);
            } else {
                _handlePublicRepayConfirmed(crossChainBorrowInfo);
            }
        }
    }

    function _borrowInitial(CrossChainBorrowInfo memory crossChainBorrowInfo) internal {
        (bool isPrivacyMode,) = crossChainBorrowInfo.checkModeAndStatus();

        if (isPrivacyMode) {
            bytes32 commitmentHash = crossChainBorrowInfo.commitmentHash;
            require(privateBorrowTokenBalance[commitmentHash].status == BorrowStatus.NONE, "Private borrow info exists");
            privateBorrowTokenBalance[commitmentHash] = AvaiableBorrowBalance({
                collateralToken: crossChainBorrowInfo.collateralToken,
                borrowToken: crossChainBorrowInfo.borrowToken,
                initiator: crossChainBorrowInfo.depositor,
                sourceChainId: crossChainBorrowInfo.sourceChainId,
                pendingAmount: 0,
                borrowedAmount: 0,
                status: BorrowStatus.INITIAL,
                proof: bytes(""), // Not used directly here
                originalDepositor: crossChainBorrowInfo.depositor,
                recipientForZK: address(0), // Will be set during borrowApplyPrivate
                ownChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].ownChainSelector,
                updatedAt: uint64(block.timestamp),
                merkleRoot: crossChainBorrowInfo.merkleRoot
            });
            emit BorrowInitialWithCommitment(
                commitmentHash, crossChainBorrowInfo.collateralToken, crossChainBorrowInfo.borrowToken
            );
        } else {
            address recipientAddress = crossChainBorrowInfo.recipientAddress;
            require(availableBorrowTokenBalance[recipientAddress].status == BorrowStatus.NONE, "Borrow info exists");

            availableBorrowTokenBalance[recipientAddress] = AvaiableBorrowBalance({
                collateralToken: crossChainBorrowInfo.collateralToken,
                borrowToken: crossChainBorrowInfo.borrowToken,
                initiator: crossChainBorrowInfo.depositor,
                sourceChainId: crossChainBorrowInfo.sourceChainId,
                pendingAmount: 0,
                borrowedAmount: 0,
                status: BorrowStatus.INITIAL,
                proof: bytes(""), // Not used directly here
                originalDepositor: crossChainBorrowInfo.depositor,
                recipientForZK: address(0), // Not applicable for public borrows
                ownChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].ownChainSelector,
                updatedAt: uint64(block.timestamp),
                merkleRoot: bytes32(0) // Public flow doesn't use commitment-specific merkle root here
            });
            emit BorrowInitial(recipientAddress, crossChainBorrowInfo.collateralToken, crossChainBorrowInfo.borrowToken);
        }
    }

    // Handles borrow confirmation for public borrows
    function _executePrivateBorrow(CrossChainBorrowInfo memory crossChainBorrowInfo) internal {
        bytes32 commitmentHash = crossChainBorrowInfo.commitmentHash;
        address recipientAddress = crossChainBorrowInfo.recipientAddress;
        uint256 amount = crossChainBorrowInfo.amount;

        require(commitmentHash != bytes32(0), "Commitment hash is zero");
        require(recipientAddress != address(0), "Recipient address is zero");
        require(privateBorrowTokenBalance[commitmentHash].status == BorrowStatus.NONE, "Borrow info exists");

        // Create the borrow record
        privateBorrowTokenBalance[commitmentHash] = AvaiableBorrowBalance({
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: crossChainBorrowInfo.borrowToken,
            initiator: crossChainBorrowInfo.depositor, // Set initiator from incoming message
            sourceChainId: crossChainBorrowInfo.sourceChainId,
            pendingAmount: 0,
            borrowedAmount: amount,
            status: BorrowStatus.BORROW_CONFIRMED_TARGET,
            proof: bytes(""), // Not used in this flow
            originalDepositor: crossChainBorrowInfo.depositor,
            recipientForZK: recipientAddress,
            ownChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].ownChainSelector,
            updatedAt: uint64(block.timestamp),
            merkleRoot: crossChainBorrowInfo.merkleRoot
        });

        // Transfer the funds to the recipient
        IERC20(BORROW_USDC).safeTransfer(recipientAddress, amount);

        // Send a confirmation message back to the source chain
        CrossChainBorrowInfo memory ccbi = CrossChainBorrowInfo({
            recipientAddress: recipientAddress,
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.BORROW_CONFIRMED_TARGET,
            sourceChainId: crossChainBorrowInfo.sourceChainId,
            targetChainId: block.chainid,
            targetChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainSelector, // Selector for source chain
            commitmentHash: commitmentHash,
            depositor: crossChainBorrowInfo.depositor,
            nullifierHash: bytes32(0),
            zkProof: bytes(""),
            merkleRoot: crossChainBorrowInfo.merkleRoot
        });

        _sendMessage(BORROW_USDC, abi.encode(ccbi), 100_000);

        emit BorrowApprovedAndTransferWithCommitment(commitmentHash, recipientAddress, BORROW_USDC, amount);
    }

    function _handlePublicBorrowConfirmed(CrossChainBorrowInfo memory crossChainBorrowInfo) internal {
        address recipientAddress = crossChainBorrowInfo.recipientAddress;
        AvaiableBorrowBalance storage userBalance = availableBorrowTokenBalance[recipientAddress];

        require(userBalance.status == BorrowStatus.BORROW_PENDING_TARGET, "Borrow not pending");
        require(userBalance.collateralToken == crossChainBorrowInfo.collateralToken, "Collateral mismatch");

        uint256 amountToTransfer = userBalance.pendingAmount;
        userBalance.borrowedAmount += amountToTransfer;
        userBalance.pendingAmount = 0;
        userBalance.status = BorrowStatus.BORROW_CONFIRMED_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);

        IERC20(BORROW_USDC).safeTransfer(recipientAddress, amountToTransfer);

        emit BorrowApprovedAndTransfer(recipientAddress, userBalance.collateralToken, BORROW_USDC, amountToTransfer);
        emit UserBorrowed(recipientAddress, BORROW_USDC, amountToTransfer, block.timestamp);
    }

    // Handles borrow confirmation for private ZK borrows
    function _handlePrivateBorrowConfirmed(CrossChainBorrowInfo memory ccbi) internal {
        require(ccbi.commitmentHash != bytes32(0), "Commitment hash is zero");
        require(ccbi.recipientAddress != address(0), "Recipient address is zero in CCBI");

        AvaiableBorrowBalance storage userBalance = privateBorrowTokenBalance[ccbi.commitmentHash];

        require(userBalance.status == BorrowStatus.BORROW_PENDING_TARGET, "Private borrow not pending");
        require(userBalance.collateralToken == ccbi.collateralToken, "Private borrow collateral mismatch");
        // Ensure the recipient in the CCBI matches the one stored during borrowApplyPrivate
        require(userBalance.recipientForZK == ccbi.recipientAddress, "Recipient address mismatch");

        uint256 amountToTransfer = userBalance.pendingAmount;
        require(amountToTransfer == ccbi.amount, "Amount mismatch in confirmation"); // Security check

        userBalance.borrowedAmount += amountToTransfer;
        userBalance.pendingAmount = 0;
        userBalance.status = BorrowStatus.BORROW_CONFIRMED_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);

        IERC20(BORROW_USDC).safeTransfer(ccbi.recipientAddress, amountToTransfer);

        emit BorrowApprovedAndTransferWithCommitment(
            ccbi.commitmentHash, ccbi.recipientAddress, BORROW_USDC, amountToTransfer
        );

        // Send a final confirmation back to the source chain to close the loop
        CrossChainBorrowInfo memory ackInfo = CrossChainBorrowInfo({
            recipientAddress: ccbi.recipientAddress,
            collateralToken: ccbi.collateralToken,
            borrowToken: BORROW_USDC,
            amount: amountToTransfer,
            status: BorrowStatus.BORROW_CONFIRMED_TARGET, // Final confirmation status
            sourceChainId: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainId,
            targetChainId: block.chainid,
            targetChainSelector: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainSelector,
            commitmentHash: ccbi.commitmentHash, // CRITICAL: Propagate the commitment hash
            depositor: ccbi.depositor,
            nullifierHash: ccbi.nullifierHash,
            zkProof: ccbi.zkProof,
            merkleRoot: ccbi.merkleRoot
        });

        _sendMessage(BORROW_USDC, abi.encode(ackInfo), 100_000);
        // Optionally, emit a generic UserBorrowed event as well if needed for off-chain tracking consistency
        // emit UserBorrowed(ccbi.recipientAddress, BORROW_USDC, amountToTransfer, block.timestamp);
    }

    function _handlePublicRepayConfirmed(CrossChainBorrowInfo memory crossChainBorrowInfo) internal {
        address recipientAddress = crossChainBorrowInfo.recipientAddress;
        AvaiableBorrowBalance storage userBalance = availableBorrowTokenBalance[recipientAddress];

        require(userBalance.status == BorrowStatus.REPAY_PENDING_TARGET, "Repay not pending");

        uint256 repayAmount = userBalance.pendingAmount;
        userBalance.borrowedAmount -= repayAmount;
        userBalance.pendingAmount = 0;
        userBalance.status = BorrowStatus.INITIAL; // Return to initial state after repay
        userBalance.updatedAt = uint64(block.timestamp);

        // The tokens were already transferred to this contract in repayApply
        // Now they can be considered settled.
        emit RepayApprovedPublic(recipientAddress, BORROW_USDC, repayAmount);
    }

    function _handlePrivateRepayConfirmed(CrossChainBorrowInfo memory ccbi) internal {
        require(ccbi.commitmentHash != bytes32(0), "Commitment hash is zero for private repay");
        AvaiableBorrowBalance storage userBalance = privateBorrowTokenBalance[ccbi.commitmentHash];

        require(userBalance.status == BorrowStatus.REPAY_PENDING_TARGET, "Private repay not pending");
        require(userBalance.pendingAmount == ccbi.amount, "Repay amount mismatch in confirmation");

        uint256 repayAmount = userBalance.pendingAmount;
        userBalance.borrowedAmount -= repayAmount;
        userBalance.pendingAmount = 0;
        userBalance.status = BorrowStatus.INITIAL; // Or a new 'REPAID' status if preferred
        userBalance.updatedAt = uint64(block.timestamp);

        // Tokens were transferred in repayApplyPrivate
        emit RepayApprovedPrivate(ccbi.commitmentHash, userBalance.recipientForZK, BORROW_USDC, repayAmount);
    }

    function _sendMessage(address borrowToken, bytes memory data, uint256 gasForDestCall)
        internal
        returns (bytes32 messageId)
    {
        SupportBorrowCollTokenInfo storage sbtci = supportBorrowCollTokenInfo[borrowToken];
        require(sbtci.sourceChainCollManager != address(0), "Source chain not configured");

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(sbtci.sourceChainCollManager),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: gasForDestCall, allowOutOfOrderExecution: true})
            ),
            feeToken: linkToken
        });

        IRouterClient router = IRouterClient(getRouter());
        uint256 fee = router.getFee(sbtci.sourceChainSelector, message);
        IERC20(linkToken).approve(address(router), fee);

        messageId = router.ccipSend(sbtci.sourceChainSelector, message);
    }

    function transferLinkToken(address to, uint256 amount) external onlyOwner {
        IERC20(linkToken).transfer(to, amount);
    }
}
