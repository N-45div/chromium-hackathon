// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {MockERC20} from "./mock/MockERC20.sol";
import {BorrowManagement, AvaiableBorrowBalance} from "src/core/borrow/BorrowManagement.sol";
import {IBorrowManagement, SupportBorrowCollTokenInfo} from "src/core/interfaces/IBorrowManagement.sol";

import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import "forge-std/Test.sol";
import {MockRouter} from "./mock/MockRouter.sol";

contract BorrowManagementTest is Test {
    BorrowManagement borrowManagement;
    uint256 targetChainId = 43113; // Avalanche Fuji Testnet
    uint256 sourceChainId = 11155111; // Ethereum Sepolia
    address mockRouterAddress;
    MockRouter internal mockRouter;

    MockERC20 mockCollateralWETH;
    MockERC20 mockBorrowUSDC;
    MockERC20 mockLinkToken;
    PrivacyPool privacyPool;

    address manager = address(0x999);
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    // --- Local Event Definitions for vm.expectEmit ---
    event BorrowApprovedAndTransfer(address indexed user, address indexed collateralToken, address borrowToken, uint256 amount);
    event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);

    uint256 supplyUSDCINBorrowManagement = 10000e8; // 10000 USDC

    event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);
    event BorrowValidationRequested(uint256 indexed validationId, address indexed recipientAddress, address indexed depositorOnSource, address collateralTokenOnSource, uint256 amount, bool isPrivacyMode);
    event BorrowValidationApproved(uint256 indexed validationId, address indexed recipient, uint256 amount);
    event BorrowValidationRejected(uint256 indexed validationId, address indexed recipient, uint256 amount);
    event UserBorrowed(address indexed user, uint256 amount, bool isPrivacyMode);

    function setUp() public {
        mockRouter = new MockRouter();
        mockRouterAddress = address(mockRouter); // Mock router address
        mockCollateralWETH = new MockERC20("Mock Collateral ETH", "mETH");
        mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "mUSDC");
        mockLinkToken = new MockERC20("Mock LINK Token", "mLINK");
        // TODO, should change below params
        privacyPool = new PrivacyPool(20, address(0), address(0), address(0), false); // ENABLE_ZK_BORROW_CHECK = false for tests

        vm.startPrank(manager);
        borrowManagement = new BorrowManagement(
            address(mockBorrowUSDC), address(mockCollateralWETH), mockRouterAddress, address(privacyPool), address(mockLinkToken) // _linkToken
        );
        vm.stopPrank();

        mockBorrowUSDC.mint(address(borrowManagement), supplyUSDCINBorrowManagement);
        mockLinkToken.mint(address(borrowManagement), 1000e18); // Mint some mock LINK to BorrowManagement

        // Configure support info for BORROW_USDC for testing cross-chain messages
        // These are example values, ensure they are consistent with test expectations
        uint64 expectedSourceChainSelector = 12345; // Example CCIP selector for source chain
        address mockCollManagementOnSource = address(0xDEADBEEFCAFE); // Mock CollManagement address
        vm.startPrank(manager); // Only owner can update this in a real scenario, here using manager for setup
        borrowManagement.updateSupportBorrowCollTokenInfo(
            address(mockBorrowUSDC),
            address(mockCollateralWETH), // Assuming WETH is the collateral for BORROW_USDC config
            sourceChainId,               // The internal ID for source chain
            expectedSourceChainSelector,
            mockCollManagementOnSource,
            true
        );
        vm.stopPrank();
    }

    function testBorrowInitial() public {
        // user1 deposits collateral and enables borrowing
        mockDepositCollateralWithEnableBorrow(
            user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
        );

        (
            address collateralToken,
            address borrowToken,
            address initiator,
            uint256 sourceChainIdFromContract,
            uint256 pendingAmount,
            uint256 borrowedAmount,
            BorrowStatus status,
            bytes memory proof, // Corresponds to 'proof' in struct
            address originalDepositor, // Added new field
            uint64 updatedAt
        ) = borrowManagement.availableBorrowTokenBalance(user1);

        assertEq(collateralToken, address(mockCollateralWETH), "Collateral token mismatch");
        assertEq(borrowToken, address(mockBorrowUSDC), "Borrow token mismatch");
        assertEq(initiator, user1, "Initiator mismatch");
        assertEq(sourceChainIdFromContract, sourceChainId, "Source chain ID mismatch");
        assertEq(pendingAmount, 0, "Pending amount should be 0 after initial borrow");
        assertEq(borrowedAmount, 0, "Borrowed amount should be 0 after initial borrow");
        assertEq(uint8(status), uint8(BorrowStatus.INITIAL), "Status should be INIITIAL");
        assertEq(proof, bytes(""), "Proof should be empty after initial borrow");
        assertTrue(updatedAt > 0, "Updated at should be set after initial borrow");
    }

    function testBorrowApplyByWaitingConfirm() public {
        // user1 deposits collateral and enables borrowing
        mockDepositCollateralWithEnableBorrow(
            user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
        );

        // user1 applies for borrowing
        vm.startPrank(user1);
        borrowManagement.borrowApply(1000e8); // Apply to borrow 1000 USDC
        vm.stopPrank();

        (
            /*address collateralToken*/,
            /*address borrowToken*/,
            /*address initiator*/,
            /*uint256 _sourceChainId*/,
            uint256 pendingAmount,
            /*uint256 borrowedAmount*/,
            BorrowStatus status,
            bytes memory proof,
            /*address originalDepositor*/, // Account for the new field
            uint64 updatedAt
        ) = borrowManagement.availableBorrowTokenBalance(user1);

        assertEq(pendingAmount, 1000e8, "Pending amount should be 1000 USDC after borrow apply");
        assertEq(
            uint8(status),
            uint8(BorrowStatus.BORROW_PENDING_TARGET),
            "Status should be PENDING_SOURCE_CONFIRMATION"
        );
    }

    function testBorrowApplyWithMockSourceChainConfrim() public {
        // user1 deposits collateral and enables borrowing
        mockDepositCollateralWithEnableBorrow(
            user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
        );

        uint256 borrowAmount = 1000e8; // 1000 USDC
        // user1 applies for borrowing
        vm.startPrank(user1);
        borrowManagement.borrowApply(borrowAmount); // Apply to borrow 1000 USDC
        vm.stopPrank();

        mockSourceChainConfirmBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount);

        (
            /*address collateralToken*/,
            /*address borrowToken*/,
            /*address initiator*/,
            /*uint256 _sourceChainId*/,
            uint256 pendingAmount,
            uint256 borrowedAmount,
            BorrowStatus status,
            bytes memory proof,
            /*address originalDepositor*/, // Account for the new field
            uint64 updatedAt
        ) = borrowManagement.availableBorrowTokenBalance(user1);
        assertEq(pendingAmount, 0, "Pending amount should be 0 after source chain confirmation");
        assertEq(borrowedAmount, borrowAmount, "Borrowed amount should be 1000 USDC after source chain confirmation");
        assertEq(
            uint8(status),
            uint8(BorrowStatus.BORROW_CONFIRMED_TARGET),
            "Status should be APPROVED_BY_SOURCE after source chain confirmation"
        );
        assertTrue(updatedAt > 0, "Updated at should be set after source chain confirmation");
        // Check if the borrow token is transferred to the user
        assertEq(
            mockBorrowUSDC.balanceOf(user1), borrowAmount, "User should receive 1000 USDC after source confirmation"
        );
        // Check if the borrow token balance in BorrowManagement is reduced
        assertEq(
            mockBorrowUSDC.balanceOf(address(borrowManagement)),
            supplyUSDCINBorrowManagement - borrowAmount,
            "BorrowManagement should have reduced USDC balance"
        );
    }

    function testRepayWithOutConfirmInSourceChain() public {
        // user1 deposits collateral and enables borrowing
        mockDepositCollateralWithEnableBorrow(
            user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
        );

        uint256 borrowAmount = 1000e8; // 1000 USDC
        // user1 applies for borrowing
        vm.startPrank(user1);
        borrowManagement.borrowApply(borrowAmount); // Apply to borrow 1000 USDC
        vm.stopPrank();

        mockSourceChainConfirmBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount);

        // user1 repays the borrowed amount
        vm.startPrank(user1);
        mockBorrowUSDC.approve(address(borrowManagement), borrowAmount);
        borrowManagement.repayApply(borrowAmount);
        vm.stopPrank();

        (
            /*address collateralToken*/,
            /*address borrowToken*/,
            /*address initiator*/,
            /*uint256 _sourceChainId*/,
            uint256 pendingAmount,
            uint256 borrowedAmount,
            BorrowStatus status,
            bytes memory proof,
            /*address originalDepositor*/, // Account for the new field
            uint64 updatedAt
        ) = borrowManagement.availableBorrowTokenBalance(user1);

        assertEq(pendingAmount, 0, "Pending amount should be 0 after repayment");
        assertEq(borrowedAmount, 0, "Borrowed amount should be 0 after repayment");
        assertEq(
            uint8(status),
            uint8(BorrowStatus.REPAY_PENDING_TARGET),
            "Status should be REPAY_PENDING_SOURCE_CONFIRMATION after repayment"
        );
    }

    function testRepayWithConfirmInSourceChain() public {
        // user1 deposits collateral and enables borrowing
        mockDepositCollateralWithEnableBorrow(
            user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
        );

        uint256 borrowAmount = 1000e8; // 1000 USDC
        // user1 applies for borrowing
        vm.startPrank(user1);
        borrowManagement.borrowApply(borrowAmount); // Apply to borrow 1000 USDC
        vm.stopPrank();

        mockSourceChainConfirmBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount);

        // user1 repays the borrowed amount
        vm.startPrank(user1);
        mockBorrowUSDC.approve(address(borrowManagement), borrowAmount);
        borrowManagement.repayApply(borrowAmount);
        vm.stopPrank();

        mockSourceChainConfirmRepay(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount, BorrowStatus.REPAY_CONFIRMED_SOURCE);

        (
            /*address collateralToken*/,
            /*address borrowToken*/,
            /*address initiator*/,
            /*uint256 _sourceChainId*/,
            uint256 pendingAmount,
            uint256 borrowedAmount,
            BorrowStatus status,
            bytes memory proof,
            /*address originalDepositor*/, // Account for the new field
            uint64 updatedAt
        ) = borrowManagement.availableBorrowTokenBalance(user1);
        assertEq(pendingAmount, 0, "Pending amount should be 0 after repayment confirmation");
        assertEq(borrowedAmount, 0, "Borrowed amount should be 0 after repayment confirmation");
        assertEq(
            uint8(status),
            uint8(BorrowStatus.REPAY_PENDING_TARGET),
            "Status should be REPAY_PENDING_TARGET (as _ccipReceive doesn't yet handle REPAY_CONFIRMED_SOURCE)"
        );
        assertTrue(updatedAt > 0, "Updated at should be set after repayment confirmation");
        // Check if the borrow token is transferred back to BorrowManagement
        assertEq(
            mockBorrowUSDC.balanceOf(address(borrowManagement)),
            supplyUSDCINBorrowManagement,
            "BorrowManagement should have USDC balance back after repayment"
        );
        assertEq(mockBorrowUSDC.balanceOf(user1), 0, "User should have 0 USDC balance after repayment confirmation");
    }

    function mockDepositCollateralWithEnableBorrow(
        address depositor,
        address collateralToken,
        address borrowToken,
        uint256 _sourceChainId,
        uint256 _targetChainId
    ) public {
        CrossChainBorrowInfo memory info = CrossChainBorrowInfo({
            recipientAddress: depositor,      // user1
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            amount: 0,                        // Added
            status: BorrowStatus.INITIAL, // Initial setup, no amount borrowed yet
            sourceChainId: _sourceChainId,
            targetChainId: _targetChainId,
            commitmentHash: bytes32(0),
            depositor: depositor,             // Added (user1)
            nullifierHash: bytes32(0),
            zkProof: "",
            validationId: 0
        });
        // Emit the BorrowInitial event
        vm.expectEmit(true, true, true, false);
        emit BorrowInitial(user1, address(mockCollateralWETH), address(mockBorrowUSDC));
        // Simulate CCIP message arrival
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(keccak256(abi.encodePacked(block.timestamp, msg.sender))), // Mock messageId
            sourceChainSelector: uint64(_sourceChainId), // Mock source chain selector, ensure it's a valid CCIP chain selector
            sender: abi.encode(address(this)), // Mock sender (e.g., router on source chain)
            data: abi.encode(info), // The CrossChainBorrowInfo
            destTokenAmounts: new Client.EVMTokenAmount[](0) // No token transfer in this message
        });
        vm.startPrank(mockRouterAddress);
        borrowManagement.ccipReceive(message);
        vm.stopPrank();
    }

    function mockSourceChainConfirmBorrow(
        address user,
        address collateralToken,
        address borrowToken,
        uint256 amount
    ) public {
        CrossChainBorrowInfo memory info = CrossChainBorrowInfo({
            recipientAddress: user,
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            amount: amount,
            status: BorrowStatus(3), // BORROW_CONFIRMED_SOURCE
            sourceChainId: sourceChainId, // from contract state
            targetChainId: targetChainId, // from contract state
            commitmentHash: bytes32(0),   // Public mode
            depositor: user,
            nullifierHash: bytes32(0),
            zkProof: "",
            validationId: 0
        });

        Client.Any2EVMMessage memory ccipMessage = Client.Any2EVMMessage({
            messageId: bytes32(keccak256(abi.encodePacked(block.timestamp, msg.sender, "confirmBorrow"))), // Mock messageId
            sourceChainSelector: uint64(sourceChainId),
            sender: abi.encode(address(this)), // Mock sender (router on source chain)
            data: abi.encode(info),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        // Note: vm.expectEmit for BorrowApprovedAndTransfer should be in the calling test function
        vm.startPrank(mockRouterAddress);
        borrowManagement.ccipReceive(ccipMessage);
        vm.stopPrank();
    }

    function mockSourceChainConfirmRepay(
        address user,
        address collateralToken,
        address borrowToken,
        uint256 repayAmount,
        BorrowStatus statusToSet // This should be REPAY_CONFIRMED_SOURCE
    ) public {
        CrossChainBorrowInfo memory info = CrossChainBorrowInfo({
            recipientAddress: user, // For repay confirmation, recipient is the user who repaid
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            amount: repayAmount, // The amount repaid
            status: statusToSet, // Should be REPAY_CONFIRMED_SOURCE from source chain
            sourceChainId: sourceChainId, // from contract state
            targetChainId: targetChainId, // from contract state
            commitmentHash: bytes32(0),   // Assuming public mode for this mock
            depositor: user, // The original depositor/borrower
            nullifierHash: bytes32(0),
            zkProof: "",
            validationId: 0
        });

        Client.Any2EVMMessage memory ccipMessage = Client.Any2EVMMessage({
            messageId: bytes32(keccak256(abi.encodePacked(block.timestamp, msg.sender, "confirmRepay"))), // Mock messageId
            sourceChainSelector: uint64(sourceChainId),
            sender: abi.encode(address(this)), // Mock sender (router on source chain)
            data: abi.encode(info),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        // If BorrowManagement._ccipReceive is updated to handle REPAY_CONFIRMED_SOURCE and emits an event,
        // vm.expectEmit should be in the calling test function.
        vm.startPrank(mockRouterAddress);
        borrowManagement.ccipReceive(ccipMessage);
        vm.stopPrank();
    }

    function testRequestBorrowValidation_SuccessFlow() public {
        // --- Arrange ---
        // Initialize borrow balance for user1
        mockDepositCollateralWithEnableBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId);
        address depositorOnSourceChain = user1; // User1 is the depositor for this flow
        address collateralOnSourceChain = address(mockCollateralWETH);
        uint256 borrowAmount = 1000e8; // Borrow 1000 mUSDC
        bool isPrivacyMode = false;
        bytes32 commitmentHash = bytes32(0);

        // Get expected source chain details from setUp
        SupportBorrowCollTokenInfo memory sbtci;
        (sbtci.collateralToken, sbtci.sourceChainId, sbtci.sourceChainSelector, sbtci.sourceChainCollManager, sbtci.isSupported) = borrowManagement.supportBorrowCollTokenInfo(address(mockBorrowUSDC));
        uint64 expectedSourceChainSelector = sbtci.sourceChainSelector;
        address mockCollManagementOnSource = sbtci.sourceChainCollManager;

        uint256 initialLinkBalance = mockLinkToken.balanceOf(address(borrowManagement));

        // --- Act (Part 1: Request Validation) ---
        vm.startPrank(user1);
        // nextValidationId is internal, so we fetch it before the call to predict the ID
        uint256 expectedValidationId = borrowManagement.nextValidationId(); 

        vm.expectEmit(true, true, true, true, address(borrowManagement));
        emit BorrowValidationRequested(expectedValidationId, user1, depositorOnSourceChain, collateralOnSourceChain, borrowAmount, isPrivacyMode);
        
        borrowManagement.borrowApply(borrowAmount);
        vm.stopPrank();

        // --- Assert (Part 1: Validation Request Sent) ---
        BorrowManagement.PendingValidationInfo memory pendingInfo; // Declare struct variable
        (
            pendingInfo.recipientAddress,
            pendingInfo.collateralTokenOnSource,
            pendingInfo.depositorOnSource,
            pendingInfo.amount,
            pendingInfo.requestTimestamp,
            pendingInfo.commitmentHash,
            pendingInfo.isPrivacyMode,
            pendingInfo.isActive
        ) = borrowManagement.pendingCrossChainValidations(expectedValidationId); // Assign fields from getter

        assertTrue(pendingInfo.isActive, "Pending validation should be active");
        assertEq(pendingInfo.recipientAddress, user1, "Recipient address mismatch");
        assertEq(pendingInfo.collateralTokenOnSource, collateralOnSourceChain, "Collateral token mismatch");
        assertEq(pendingInfo.depositorOnSource, depositorOnSourceChain, "Depositor mismatch");
        assertEq(pendingInfo.amount, borrowAmount, "Amount mismatch");
        assertEq(pendingInfo.isPrivacyMode, isPrivacyMode, "Privacy mode mismatch");
        assertEq(pendingInfo.commitmentHash, commitmentHash, "Commitment hash mismatch");

        Client.EVM2AnyMessage memory sentMessage;
        // tokenAmounts is not returned by the getter for structs with dynamic arrays
        (sentMessage.receiver, sentMessage.data, sentMessage.feeToken, sentMessage.extraArgs) = mockRouter.lastMessageSent();
        // For this test, tokenAmounts is expected to be empty. If needed, MockRouter would need a specific getter or event for it.
        assertEq(sentMessage.receiver, abi.encode(mockCollManagementOnSource), "CCIP receiver mismatch");
        assertEq(mockRouter.lastDestinationChainSelector(), expectedSourceChainSelector, "CCIP destination selector mismatch");
        assertEq(sentMessage.feeToken, address(mockLinkToken), "Fee token should be LINK");
        assertTrue(initialLinkBalance > mockLinkToken.balanceOf(address(borrowManagement)), "Link balance should decrease");

        CrossChainBorrowInfo memory decodedInfoRequest = abi.decode(sentMessage.data, (CrossChainBorrowInfo));
        assertEq(uint8(decodedInfoRequest.status), uint8(BorrowStatus.BORROW_VALIDATE_REQUEST_SOURCE), "Status mismatch in CCIP message");
        assertEq(decodedInfoRequest.recipientAddress, user1, "Recipient in CCIP message mismatch");
        assertEq(decodedInfoRequest.depositor, depositorOnSourceChain, "Depositor in CCIP message mismatch");
        assertEq(decodedInfoRequest.collateralToken, collateralOnSourceChain, "Collateral token in CCIP message mismatch");
        assertEq(decodedInfoRequest.borrowToken, address(mockBorrowUSDC), "Borrow token in CCIP message mismatch");
        assertEq(decodedInfoRequest.amount, borrowAmount, "Amount in CCIP message mismatch");
        assertEq(decodedInfoRequest.targetChainId, block.chainid, "Target chain ID in CCIP message mismatch");
        assertEq(decodedInfoRequest.sourceChainId, sbtci.sourceChainId, "Source chain ID in CCIP message mismatch");

        // --- Act (Part 2: Simulate Approval from Source Chain) ---
        CrossChainBorrowInfo memory approvalInfo = CrossChainBorrowInfo({
            recipientAddress: user1,
            collateralToken: collateralOnSourceChain,
            borrowToken: address(mockBorrowUSDC),
            amount: borrowAmount,
            status: BorrowStatus.BORROW_VALIDATE_APPROVED_TARGET,
            sourceChainId: sbtci.sourceChainId, 
            targetChainId: targetChainId, 
            commitmentHash: commitmentHash,
            depositor: depositorOnSourceChain,
            nullifierHash: bytes32(0),
            zkProof: "",
            validationId: expectedValidationId
        });

        Client.Any2EVMMessage memory approvalMessage = Client.Any2EVMMessage({
            messageId: bytes32(keccak256(abi.encodePacked("approval_msg_id"))),
            sourceChainSelector: expectedSourceChainSelector, 
            sender: abi.encode(mockCollManagementOnSource), 
            data: abi.encode(approvalInfo),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        // Expect BorrowApprovedAndTransfer event
        // event BorrowApprovedAndTransfer(address indexed user, address indexed collateralToken, address borrowToken, uint256 amount);
        // Topic1: user, Topic2: collateralToken. Data: abi.encode(borrowToken, amount)
        vm.expectEmit(true, true, false, true, address(borrowManagement)); // check user, collateralToken, no 3rd topic, check data
        emit BorrowApprovedAndTransfer(user1, collateralOnSourceChain, address(mockBorrowUSDC), borrowAmount);

        // TODO: Add robust check for UserBorrowed event, potentially using vm.recordLogs()
        // event UserBorrowed(address indexed user, address indexed borrowToken, uint256 amount, uint256 timestamp);
        vm.expectEmit(true, true, false, true, address(borrowManagement));
        emit UserBorrowed(user1, address(mockBorrowUSDC), borrowAmount, block.timestamp);

        uint256 usdcBalanceBeforeBorrow = mockBorrowUSDC.balanceOf(address(borrowManagement));

        vm.startPrank(mockRouterAddress); 
        borrowManagement.ccipReceive(approvalMessage);
        vm.stopPrank();

        // --- Assert (Part 2: Approval Processed and Confirmation Sent) ---
        (
            pendingInfo.recipientAddress, 
            pendingInfo.collateralTokenOnSource,
            pendingInfo.depositorOnSource,
            pendingInfo.amount,
            pendingInfo.requestTimestamp,
            pendingInfo.commitmentHash,
            pendingInfo.isPrivacyMode,
            pendingInfo.isActive
        ) = borrowManagement.pendingCrossChainValidations(expectedValidationId);
        assertFalse(pendingInfo.isActive, "Pending validation should be inactive after approval");

        assertEq(mockBorrowUSDC.balanceOf(user1), borrowAmount, "User1 should receive borrowAmount");
        assertEq(mockBorrowUSDC.balanceOf(address(borrowManagement)), usdcBalanceBeforeBorrow - borrowAmount, "BorrowManagement mUSDC balance mismatch");

        Client.EVM2AnyMessage memory confirmationMessage;
        // tokenAmounts is not returned by the getter for structs with dynamic arrays
        (confirmationMessage.receiver, confirmationMessage.data, confirmationMessage.feeToken, confirmationMessage.extraArgs) = mockRouter.lastMessageSent();
        // For this test, tokenAmounts is expected to be empty. 
        assertEq(confirmationMessage.receiver, abi.encode(mockCollManagementOnSource), "Confirmation CCIP receiver mismatch");
        assertEq(mockRouter.lastDestinationChainSelector(), expectedSourceChainSelector, "Confirmation CCIP dest selector mismatch");
        
        CrossChainBorrowInfo memory decodedConfirmationInfo = abi.decode(confirmationMessage.data, (CrossChainBorrowInfo));
        assertEq(uint8(decodedConfirmationInfo.status), uint8(BorrowStatus.BORROW_CONFIRMED_TARGET), "Status mismatch in confirmation CCIP message");
        assertEq(decodedConfirmationInfo.recipientAddress, user1, "Recipient in confirmation CCIP mismatch");
        assertEq(decodedConfirmationInfo.depositor, depositorOnSourceChain, "Depositor in confirmation CCIP mismatch");
        assertEq(decodedConfirmationInfo.amount, borrowAmount, "Amount in confirmation CCIP mismatch");
        assertEq(decodedConfirmationInfo.sourceChainId, sbtci.sourceChainId, "Source chain ID in confirmation CCIP mismatch");
        assertEq(decodedConfirmationInfo.targetChainId, block.chainid, "Target chain ID in confirmation CCIP mismatch");
    }
}
