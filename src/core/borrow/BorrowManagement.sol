// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

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

contract BorrowManagement is IBorrowManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    address public immutable BORROW_USDC; // the only borrow token supported now
    address private immutable privacyPool;
    address private immutable linkToken; //now use link pay for the fees

    mapping(address => SupportBorrowCollTokenInfo) public supportBorrowCollTokenInfo; // TOOD chek supportBorrowCollTokenInfo is compatible with other components
    mapping(address => AvaiableBorrowBalance) public availableBorrowTokenBalance; // for borrow token, current only support USDC
    // TODO , don't store the plainText ?
    mapping(bytes32 => AvaiableBorrowBalance) privateBorrowTokenBalance; // private model

    struct PendingValidationInfo {
        address recipientAddress; // User on this (target) chain to receive funds
        address collateralTokenOnSource; // Collateral token on source chain
        address depositorOnSource; // User's address on source chain (owner of collateral)
        uint256 amount; // Amount of BORROW_USDC requested
        uint64 requestTimestamp;
        bytes32 commitmentHash; // For ZK mode, if applicable to validation request
        bool isPrivacyMode; // Was this validation requested for a private borrow?
        bool isActive; // Is this validation request currently active?
    }
    uint256 public nextValidationId;
    mapping(uint256 => PendingValidationInfo) public pendingCrossChainValidations;

    event BorrowValidationRequested(uint256 indexed validationId, address indexed recipientAddress, address indexed depositorOnSource, address collateralTokenOnSource, uint256 amount, bool isPrivacyMode);
    event BorrowValidationApproved(uint256 indexed validationId, address indexed recipientAddress, uint256 amount);
    event BorrowValidationRejected(uint256 indexed validationId, address indexed depositorOnSource);

    event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);
    event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);
    event BorrowInitialWithCommitment(bytes32 commitmentHash, address indexed collateralToken, address borrowToken);
    event CCIPReceive_Start(bytes messageData);
    event CCIPReceive_AfterDecode(address recipient, bytes32 commitment, BorrowStatus status);
    event CCIPReceive_AfterCheckMode(bool isPrivacy, BorrowStatus statusFromCheck);
    event CCIPReceive_BeforeBorrowInitial(BorrowStatus status);
    event DebugBorrowInitialCalled(
        address recipientAddress,
        address depositor,
        address collateralTokenInInfo,
        address initiatorInBalance,
        address collateralTokenInBalance,
        BorrowStatus statusInInfo,
        address originalDepositor
    );
    event BorrowApply(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 pendingAmount
    );
    event BorrowApplyWithCommitment(uint256 pendingAmount, bytes32 commitmentHash);
    event BorrowApplyMessageSent(bytes32 indexed messageId, uint64 destChainSelector);
    event BorrowApprovedAndTransfer(
        address indexed user, address indexed collateralToken, address borrowToken, uint256 amount
    );
    event BorrowApprovedAndTransferWithCommitment(bytes32 indexed commitmentHash, address indexed recipientAddress, address indexed borrowToken, uint256 amount);
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
    //--------------------------------------------------------------------------
    // View functions
    //--------------------------------------------------------------------------

    function getSupportBorrowCollTokenInfo(address borrowToken) public view returns (bool, address, uint64) {
        SupportBorrowCollTokenInfo storage sbtci = supportBorrowCollTokenInfo[borrowToken];
        return (sbtci.isSupported, sbtci.sourceChainCollManager, sbtci.sourceChainSelector);
    }

    constructor(
        address _borrowToken,
        address _collateralToken,
        address _router,
        address _privacyPool,
        address _linkToken
    ) Ownable(msg.sender) CCIPReceiver(_router) {
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

    function updateSupportBorrowCollTokenInfo(
        address _borrowToken,
        address _collateralToken,
        uint256 _sourceChainId,
        uint64 _sourceChainSelector,
        address _sourceChainCollManager,
        bool _isSupported
    ) external onlyOwner {
        SupportBorrowCollTokenInfo storage sbtci = supportBorrowCollTokenInfo[_borrowToken];
        sbtci.collateralToken = _collateralToken;
        sbtci.sourceChainId = _sourceChainId;
        sbtci.sourceChainSelector = _sourceChainSelector;
        sbtci.sourceChainCollManager = _sourceChainCollManager;
        sbtci.isSupported = _isSupported;
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

        requestCrossChainBorrowValidation(
            availableBorrowTokenBalance[msg.sender].collateralToken, // _collateralTokenOnSource
            amount,                                                // _amount
            msg.sender,                                            // _recipientOnTarget
            availableBorrowTokenBalance[msg.sender].originalDepositor, // _depositorOnSource
            false,                                                 // _isPrivacyMode
            bytes32(0)                                             // _commitmentHash
        );

        emit BorrowApply(msg.sender, availableBorrowTokenBalance[msg.sender].collateralToken, BORROW_USDC, amount);
    }

    function borrowApply(uint256 amount, bytes32 commitmentHash, bytes32 nullifierHash, bytes calldata proof) external {
        // 1. Check if the borrow info for this commitment exists and is in a ready state.
        if (privateBorrowTokenBalance[commitmentHash].status == BorrowStatus.BORROW_PENDING_TARGET) {
            revert("Borrow already pending for this commitment");
        }

        // 2. Call PrivacyPool to verify the ZK proof.
        uint64 sourceSelector = supportBorrowCollTokenInfo[BORROW_USDC].sourceChainSelector;
        require(sourceSelector != 0, "SRC_CHAIN_SEL_NOT_CONFIG"); // Source chain selector not configured

        // The recipient is msg.sender, as they are initiating the borrow on this target chain.
        // The targetChainSelector for PrivacyPool's CCIP message is our sourceChainSelector (to CollManagement).
        bool success = PrivacyPool(privacyPool).authorizeBorrow(
            commitmentHash,          // param 1: commitment
            nullifierHash,           // param 2: nullifierHash
            msg.sender,              // param 3: recipient
            amount,                  // param 4: borrowAmount
            BORROW_USDC,             // param 5: borrowToken
            sourceSelector,          // param 6: targetChainSelector (for PrivacyPool's message)
            proof                    // param 7: proof
        );
        require(success, "ZK proof verification failed in PrivacyPool");

        // 3. Update local state after successful verification.
        privateBorrowTokenBalance[commitmentHash].pendingAmount = amount;
        privateBorrowTokenBalance[commitmentHash].status = BorrowStatus.BORROW_PENDING_TARGET;
        privateBorrowTokenBalance[commitmentHash].updatedAt = uint64(block.timestamp);
        privateBorrowTokenBalance[commitmentHash].proof = proof; // Store proof for potential future reference

        // 4. Construct CCIP message to send to the source chain for collateral validation.
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: msg.sender, // The user's address on this (target) chain.
            collateralToken: privateBorrowTokenBalance[commitmentHash].collateralToken,
            borrowToken: BORROW_USDC,
            amount: amount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: supportBorrowCollTokenInfo[BORROW_USDC].sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: commitmentHash,
            depositor: privateBorrowTokenBalance[commitmentHash].initiator, // The user's EOA on the source chain.
            nullifierHash: nullifierHash,
            zkProof: proof,
            validationId: 0 // Initial request, no validationId yet
        });

        // 5. Send the CCIP message.
        _sendMessage(BORROW_USDC, abi.encode(crossChainBorrowInfo), 155_000);

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
            zkProof: bytes(""),
            validationId: 0 // Repay, no validation flow
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
            zkProof: proof,
            validationId: 0 // Repay, no validation flow
        });

        // TODO complete below logic
        // _sendMessage(BORROW_USDC, abi.encode(crossChainBorrowInfo));

        emit BorrowRepayWithCommitment(commitmentHash, amount);
    }

    function requestCrossChainBorrowValidation(
        address _collateralTokenOnSource,
        uint256 _amount,
        address _recipientOnTarget,
        address _depositorOnSource,
        bool _isPrivacyMode,
        bytes32 _commitmentHash
    ) internal returns (uint256 validationId) {
        require(_amount > 0, "Amount must be > 0");
        require(_recipientOnTarget != address(0), "Recipient cannot be zero address");
        require(_depositorOnSource != address(0), "Depositor cannot be zero address");

        SupportBorrowCollTokenInfo storage sbtci = supportBorrowCollTokenInfo[BORROW_USDC];
        require(sbtci.isSupported, "Borrowing USDC not supported or configured");
        require(sbtci.sourceChainCollManager != address(0) && sbtci.sourceChainSelector != 0, "Source chain info not set for validation");

        validationId = nextValidationId++;
        pendingCrossChainValidations[validationId] = PendingValidationInfo({
            recipientAddress: _recipientOnTarget,
            collateralTokenOnSource: _collateralTokenOnSource,
            depositorOnSource: _depositorOnSource,
            amount: _amount,
            requestTimestamp: uint64(block.timestamp),
            commitmentHash: _isPrivacyMode ? _commitmentHash : bytes32(0),
            isPrivacyMode: _isPrivacyMode,
            isActive: true
        });

        CrossChainBorrowInfo memory ccbi = CrossChainBorrowInfo({
            recipientAddress: _recipientOnTarget,
            collateralToken: _collateralTokenOnSource,
            borrowToken: BORROW_USDC,
            amount: _amount,
            status: BorrowStatus.BORROW_VALIDATE_REQUEST_SOURCE,
            sourceChainId: sbtci.sourceChainId,
            targetChainId: block.chainid,
            commitmentHash: _isPrivacyMode ? _commitmentHash : bytes32(0),
            depositor: _depositorOnSource,
            nullifierHash: bytes32(0),
            zkProof: bytes(""),
            validationId: validationId
        });

        _sendMessage(BORROW_USDC, abi.encode(ccbi), 500_000); // Gas from memory

        emit BorrowValidationRequested(validationId, _recipientOnTarget, _depositorOnSource, _collateralTokenOnSource, _amount, _isPrivacyMode);
        return validationId;
    }

    function _borrowApprovedAndTransferPrivate(bytes32 commitmentHash, address recipientAddress) internal {
        AvaiableBorrowBalance storage userBalance = privateBorrowTokenBalance[commitmentHash];
        require(userBalance.status == BorrowStatus.BORROW_PENDING_TARGET || userBalance.status == BorrowStatus.BORROW_CONFIRMED_SOURCE, "Private borrow not in valid state for approval");
        uint256 amountToTransfer = userBalance.pendingAmount;
        require(amountToTransfer > 0, "No pending amount to transfer for private borrow");

        userBalance.borrowedAmount += amountToTransfer;
        userBalance.pendingAmount = 0;
        userBalance.status = BorrowStatus.BORROW_CONFIRMED_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);
        
        // Actual token transfer for ZK might be via PrivacyPool withdrawal
        // IERC20(BORROW_USDC).safeTransfer(recipientAddress, amountToTransfer); 

        emit BorrowApprovedAndTransferWithCommitment(
            commitmentHash, 
            recipientAddress, 
            BORROW_USDC, 
            amountToTransfer
        );
    }

    function borrowApprovedAndTransfer(address recipientAddress, address collateralTokenOnSource, uint256 amountToTransfer) internal {
        require(amountToTransfer > 0, "Transfer amount must be > 0");

        AvaiableBorrowBalance storage userBalance = availableBorrowTokenBalance[recipientAddress];

        if (userBalance.collateralToken == address(0)) {
            userBalance.collateralToken = collateralTokenOnSource;
        }
        if (userBalance.borrowToken == address(0)) {
            userBalance.borrowToken = BORROW_USDC;
        }

        userBalance.borrowedAmount += amountToTransfer;
        userBalance.pendingAmount = 0; 
        userBalance.status = BorrowStatus.BORROW_CONFIRMED_TARGET;
        userBalance.updatedAt = uint64(block.timestamp);

        IERC20(BORROW_USDC).safeTransfer(recipientAddress, amountToTransfer);
        
        emit BorrowApprovedAndTransfer(
            recipientAddress,
            userBalance.collateralToken,
            userBalance.borrowToken,
            amountToTransfer
        );
        emit UserBorrowed(recipientAddress, BORROW_USDC, amountToTransfer, block.timestamp);
    }

    // Prepare the params for CCIP
    function initSourceChainParamsForCCIP(
        address borrowToken,
        address sourceChainCollManager,
        uint64 sourceChainSelector
    ) external onlyOwner {
        console.log("[BM.initSourceChainParamsForCCIP] Called for borrowToken:", borrowToken);
        console.log("[BM.initSourceChainParamsForCCIP] Setting sourceChainCollManager:", sourceChainCollManager);
        console.log("[BM.initSourceChainParamsForCCIP] Setting sourceChainSelector:", sourceChainSelector);
        supportBorrowCollTokenInfo[borrowToken].sourceChainSelector = sourceChainSelector;
        supportBorrowCollTokenInfo[borrowToken].sourceChainCollManager = sourceChainCollManager;
        supportBorrowCollTokenInfo[borrowToken].isSupported = true; // Explicitly set isSupported
    }

    // Initial user's borrow info(normal and privacy mode)
    function borrowInitial(CrossChainBorrowInfo memory crossChainBorrowInfo, bool isPrivacyMode) internal {
        console.log("[BM.borrowInitial] Received CCBI - depositor:", crossChainBorrowInfo.depositor);
        console.log("[BM.borrowInitial] Received CCBI - recipientAddress:", crossChainBorrowInfo.recipientAddress);

        AvaiableBorrowBalance memory avaiableBorrowBalance = AvaiableBorrowBalance({
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: crossChainBorrowInfo.borrowToken,
            initiator: crossChainBorrowInfo.depositor,       // CORRECTED: Use depositor as initiator
            originalDepositor: crossChainBorrowInfo.depositor, // This was already correct
            sourceChainId: crossChainBorrowInfo.sourceChainId,
            pendingAmount: 0,
            borrowedAmount: 0,
            status: BorrowStatus.INITIAL,
            proof: bytes(""),
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
            console.log("[BM.borrowInitial_NormalMode] Key for availableBorrowTokenBalance (using ccbi.recipientAddress):", crossChainBorrowInfo.recipientAddress);
            emit DebugBorrowInitialCalled(
                crossChainBorrowInfo.recipientAddress,
                crossChainBorrowInfo.depositor,
                crossChainBorrowInfo.collateralToken,
                avaiableBorrowBalance.initiator, // Should be depositor
                avaiableBorrowBalance.collateralToken,
                avaiableBorrowBalance.status, // Should be INITIAL
                avaiableBorrowBalance.originalDepositor // Should be depositor
            );
            availableBorrowTokenBalance[crossChainBorrowInfo.recipientAddress] = avaiableBorrowBalance; // Key by recipientAddress
            emit BorrowInitial(avaiableBorrowBalance.initiator, avaiableBorrowBalance.collateralToken, BORROW_USDC);
        }
    }

    // ... (rest of the code remains the same)

    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        console.log("[BM.ccipReceive] Entry. Gas left:", gasleft());
        emit CCIPReceive_Start(message.data);
        CrossChainBorrowInfo memory crossChainBorrowInfo = abi.decode(message.data, (CrossChainBorrowInfo));
        console.log("[BM.ccipReceive] After decode. Gas left:", gasleft());
        console.log("[BM.ccipReceive] Decoded Status:", uint256(crossChainBorrowInfo.status));
        console.log("[BM.ccipReceive] Decoded ValidationId:", crossChainBorrowInfo.validationId);

        // TODO, should emit the related event?
        // require(
        //     supportBorrowCollTokenInfo[crossChainBorrowInfo.borrowToken].isSupported,
        //     "Unsupported collateral token for borrow"
        // );

        emit CCIPReceive_AfterDecode(crossChainBorrowInfo.recipientAddress, crossChainBorrowInfo.commitmentHash, crossChainBorrowInfo.status);
        (bool isPrivacyMode, BorrowStatus status) = crossChainBorrowInfo.checkModeAndStatus();

        // TODO, CHECK BORROW INITIAL, BORROW APPROVED AND TRANSFER, REPAY CONFIRM, etc.
        // Quesiton: BorrowStatus's define can't deal some scenario, when user borrowApply, when not confirmed, but  reapy.
        emit CCIPReceive_AfterCheckMode(isPrivacyMode, status);

        if (status == BorrowStatus.INITIAL) {
            emit CCIPReceive_BeforeBorrowInitial(status);
            borrowInitial(crossChainBorrowInfo, isPrivacyMode);
        } else if (status == BorrowStatus.BORROW_CONFIRMED_SOURCE) {
            if (isPrivacyMode) {
                _borrowApprovedAndTransferPrivate(crossChainBorrowInfo.commitmentHash, crossChainBorrowInfo.recipientAddress);
            } else {
                borrowApprovedAndTransfer(crossChainBorrowInfo.recipientAddress, crossChainBorrowInfo.collateralToken, crossChainBorrowInfo.amount);
            }
        } else if (status == BorrowStatus.BORROW_VALIDATE_APPROVED_TARGET) {
            console.log("[BM.ccipReceive] Matched BORROW_VALIDATE_APPROVED_TARGET. Gas left:", gasleft());
            uint256 validationId = crossChainBorrowInfo.validationId;
            require(pendingCrossChainValidations[validationId].requestTimestamp != 0, "No matching pending validation"); // Check if exists

            PendingValidationInfo storage pvi = pendingCrossChainValidations[validationId];
            console.log("[BM.ccipReceive] After getting PVI. Gas left:", gasleft());
            console.log("[BM.ccipReceive] PVI recipient:", pvi.recipientAddress);
            console.log("[BM.ccipReceive] PVI amount:", pvi.amount);
            require(pvi.isActive, "Validation not active");
            pvi.isActive = false;

            if (pvi.isPrivacyMode) {
                require(pvi.commitmentHash == crossChainBorrowInfo.commitmentHash, "Commitment hash mismatch");
                _borrowApprovedAndTransferPrivate(pvi.commitmentHash, pvi.recipientAddress);
            } else {
                // The borrowApprovedAndTransfer function expects the recipient (user on this chain)
                console.log("[BM.ccipReceive] Before borrowApprovedAndTransfer. Gas left:", gasleft());
                borrowApprovedAndTransfer(pvi.recipientAddress, pvi.collateralTokenOnSource, pvi.amount);
                console.log("[BM.ccipReceive] After borrowApprovedAndTransfer. Gas left:", gasleft());
            }

            // Send BORROW_CONFIRMED_TARGET back to CollManagement on the source chain
            SupportBorrowCollTokenInfo storage sbtci = supportBorrowCollTokenInfo[BORROW_USDC];
            CrossChainBorrowInfo memory confirmationCcbi = CrossChainBorrowInfo({
                recipientAddress: pvi.recipientAddress,
                collateralToken: pvi.collateralTokenOnSource,
                borrowToken: BORROW_USDC,
                amount: pvi.amount,
                status: BorrowStatus.BORROW_CONFIRMED_TARGET,
                sourceChainId: sbtci.sourceChainId, // CollManagement's chain ID
                targetChainId: block.chainid,      // This BorrowManagement's chain ID
                commitmentHash: pvi.commitmentHash, // Propagate if it was a private mode borrow
                depositor: pvi.depositorOnSource,
                nullifierHash: bytes32(0), // Not applicable for this confirmation status
                zkProof: bytes(""),       // Not applicable
                validationId: validationId // Propagate the validationId from the approved request
            });
            console.log("[BM.ccipReceive] Before _sendMessage (confirmation). Gas left:", gasleft());
            _sendMessage(BORROW_USDC, abi.encode(confirmationCcbi), 45_000); // <--- This sends another message
            console.log("[BM.ccipReceive] After _sendMessage (confirmation). Gas left:", gasleft());

            // BorrowValidationApproved event is from source chain; target chain processes it.
            // Relevant events here are BorrowApprovedAndTransfer and UserBorrowed (emitted within borrowApprovedAndTransfer).

        } else if (status == BorrowStatus.BORROW_VALIDATE_REJECTED_TARGET) {
            uint256 validationId = crossChainBorrowInfo.validationId;
            require(pendingCrossChainValidations[validationId].requestTimestamp != 0, "No matching pending validation for rejection"); // Check if exists

            PendingValidationInfo storage pvi = pendingCrossChainValidations[validationId];
            require(pvi.isActive, "Validation not active for rejection");
            pvi.isActive = false;

            emit BorrowValidationRejected(validationId, pvi.depositorOnSource);
        }
    }

    // For now, we just support 1=>1 format, user deposit one collateralToken and can only borrow one borrowToken in target chain

    function _sendMessage(address borrowToken, bytes memory data, uint256 gasForDestCall) internal returns (bytes32 messageId) {
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
                    gasLimit: gasForDestCall, // Gas limit for the callback on the destination chain
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
        console.log("[BM._sendMessage] Target CollManagement Addr:", sourceChainCollManager);
        console.log("[BM._sendMessage] Encoded Receiver in Message:", abi.decode(message.receiver, (address)));
        console.log("[BM._sendMessage] Gas before getFee:", gasleft());
        uint256 fee = IRouterClient(router).getFee(sourceChainSelector, message);
        IERC20(linkToken).approve(address(router), fee);

        console.log("[BM._sendMessage] Gas before i_router.ccipSend:", gasleft());
        messageId = IRouterClient(router).ccipSend(sourceChainSelector, message);
        // TODO based on messageId. emit or integrate with front-end AI
    }
    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////

    // For link gas usage, just for hackathon, not for real production use
    function transferLinkToken(address to, uint256 amount) external onlyOwner {
        // Allow the owner to withdraw LINK tokens from the contract
        IERC20(linkToken).transfer(to, amount);
    }
}
