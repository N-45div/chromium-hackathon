// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.30;

// import {MockERC20} from "./mock/MockERC20.sol";
// import {BorrowManagement, AvaiableBorrowBalance} from "src/core/borrow/BorrowManagement.sol";

// import {CrossChainBorrowInfo} from "src/core/interfaces/ICollManagement.sol";
// import {BorrowStatus} from "src/core/interfaces/IBorrowManagement.sol";
// import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";
// import "forge-std/Test.sol";

// contract BorrowManagementTest is Test {
//     BorrowManagement borrowManagement;
//     uint256 targetChainId = 43113; // Avalanche Fuji Testnet
//     uint256 sourceChainId = 11155111; // Ethereum Sepolia

//     MockERC20 mockCollateralWETH;
//     MockERC20 mockBorrowUSDC;
//     PrivacyPool privacyPool;

//     address manager = address(0x999);
//     address user1 = address(0x1111);
//     address user2 = address(0x2222);

//     uint256 supplyUSDCINBorrowManagement = 10000e8; // 10000 USDC

//     event BorrowInitial(address indexed initiator, address indexed collateralToken, address borrowToken);

//     function setUp() public {
//         address routerAddress = address(0x1234); // Mock router address TODO
//         mockCollateralWETH = new MockERC20("Mock Collateral ETH", "mETH");
//         mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "mUSDC");
//         // TODO, should change below params
//         privacyPool = new PrivacyPool(20, address(0));

//         vm.startPrank(manager);
//         borrowManagement = new BorrowManagement(
//             address(mockBorrowUSDC), address(mockCollateralWETH), routerAddress, address(privacyPool)
//         );
//         vm.stopPrank();

//         mockBorrowUSDC.mint(address(borrowManagement), supplyUSDCINBorrowManagement);
//     }

//     function testBorrowInitial() public {
//         // user1 deposits collateral and enables borrowing
//         mockDepositCollateralWithEnableBorrow(
//             user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
//         );

//         (
//             address collateralToken,
//             address borrowToken,
//             address initiator,
//             uint256 sourceChainIdFromContract,
//             uint256 pendingAmount,
//             uint256 borrowedAmount,
//             BorrowStatus status,
//             bytes memory commit,
//             uint64 updatedAt
//         ) = borrowManagement.availableBorrowTokenBalance(user1);

//         assertEq(collateralToken, address(mockCollateralWETH), "Collateral token mismatch");
//         assertEq(borrowToken, address(mockBorrowUSDC), "Borrow token mismatch");
//         assertEq(initiator, user1, "Initiator mismatch");
//         assertEq(sourceChainIdFromContract, sourceChainId, "Source chain ID mismatch");
//         assertEq(pendingAmount, 0, "Pending amount should be 0 after initial borrow");
//         assertEq(borrowedAmount, 0, "Borrowed amount should be 0 after initial borrow");
//         assertEq(uint8(status), uint8(BorrowStatus.INITIAL), "Status should be INIITIAL");
//         assertEq(commit, "", "Commit should be empty after initial borrow");
//         assertTrue(updatedAt > 0, "Updated at should be set after initial borrow");
//     }

//     function testBorrowApplyByWaitingConfirm() public {
//         // user1 deposits collateral and enables borrowing
//         mockDepositCollateralWithEnableBorrow(
//             user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
//         );

//         // user1 applies for borrowing
//         vm.startPrank(user1);
//         borrowManagement.borrowApply(1000e8); // Apply to borrow 1000 USDC
//         vm.stopPrank();

//         (
//             /*address collateralToken*/,
//             /*address borrowToken*/,
//             /*address initiator*/,
//             /*uint256 _sourceChainId*/,
//             uint256 pendingAmount,
//             /*uint256 borrowedAmount*/,
//             BorrowStatus status,
//             bytes memory proof,
//             uint64 updatedAt
//         ) = borrowManagement.availableBorrowTokenBalance(user1);

//         assertEq(pendingAmount, 1000e8, "Pending amount should be 1000 USDC after borrow apply");
//         assertEq(
//             uint8(status),
//             uint8(BorrowStatus.BORROW_PENDING_SOURCE_CONFIRMATION),
//             "Status should be PENDING_SOURCE_CONFIRMATION"
//         );
//     }

//     function testBorrowApplyWithMockSourceChainConfrim() public {
//         // user1 deposits collateral and enables borrowing
//         mockDepositCollateralWithEnableBorrow(
//             user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
//         );

//         uint256 borrowAmount = 1000e8; // 1000 USDC
//         // user1 applies for borrowing
//         vm.startPrank(user1);
//         borrowManagement.borrowApply(borrowAmount); // Apply to borrow 1000 USDC
//         vm.stopPrank();

//         mockSourceChainConfirmBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount);

//         (
//             /*address collateralToken*/,
//             /*address borrowToken*/,
//             /*address initiator*/,
//             /*uint256 _sourceChainId*/,
//             uint256 pendingAmount,
//             uint256 borrowedAmount,
//             BorrowStatus status,
//             bytes memory proof,
//             uint64 updatedAt
//         ) = borrowManagement.availableBorrowTokenBalance(user1);
//         assertEq(pendingAmount, 0, "Pending amount should be 0 after source chain confirmation");
//         assertEq(borrowedAmount, borrowAmount, "Borrowed amount should be 1000 USDC after source chain confirmation");
//         assertEq(
//             uint8(status),
//             uint8(BorrowStatus.BORROW_APPROVED_BY_SOURCE),
//             "Status should be APPROVED_BY_SOURCE after source chain confirmation"
//         );
//         assertTrue(updatedAt > 0, "Updated at should be set after source chain confirmation");
//         // Check if the borrow token is transferred to the user
//         assertEq(
//             mockBorrowUSDC.balanceOf(user1), borrowAmount, "User should receive 1000 USDC after source confirmation"
//         );
//         // Check if the borrow token balance in BorrowManagement is reduced
//         assertEq(
//             mockBorrowUSDC.balanceOf(address(borrowManagement)),
//             supplyUSDCINBorrowManagement - borrowAmount,
//             "BorrowManagement should have reduced USDC balance"
//         );
//     }

//     function testRepayWithOutConfirmInSourceChain() public {
//         // user1 deposits collateral and enables borrowing
//         mockDepositCollateralWithEnableBorrow(
//             user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
//         );

//         uint256 borrowAmount = 1000e8; // 1000 USDC
//         // user1 applies for borrowing
//         vm.startPrank(user1);
//         borrowManagement.borrowApply(borrowAmount); // Apply to borrow 1000 USDC
//         vm.stopPrank();

//         mockSourceChainConfirmBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount);

//         // user1 repays the borrowed amount
//         vm.startPrank(user1);
//         mockBorrowUSDC.approve(address(borrowManagement), borrowAmount);
//         borrowManagement.repay(borrowAmount);
//         vm.stopPrank();

//         (
//             /*address collateralToken*/,
//             /*address borrowToken*/,
//             /*address initiator*/,
//             /*uint256 _sourceChainId*/,
//             uint256 pendingAmount,
//             uint256 borrowedAmount,
//             BorrowStatus status,
//             bytes memory proof,
//             uint64 updatedAt
//         ) = borrowManagement.availableBorrowTokenBalance(user1);

//         assertEq(pendingAmount, 0, "Pending amount should be 0 after repayment");
//         assertEq(borrowedAmount, 0, "Borrowed amount should be 0 after repayment");
//         assertEq(
//             uint8(status),
//             uint8(BorrowStatus.REPAY_PENDING_SOURCE_CONFIRMATION),
//             "Status should be REPAY_PENDING_SOURCE_CONFIRMATION after repayment"
//         );
//     }

//     function testRepayWithConfirmInSourceChain() public {
//         // user1 deposits collateral and enables borrowing
//         mockDepositCollateralWithEnableBorrow(
//             user1, address(mockCollateralWETH), address(mockBorrowUSDC), sourceChainId, targetChainId
//         );

//         uint256 borrowAmount = 1000e8; // 1000 USDC
//         // user1 applies for borrowing
//         vm.startPrank(user1);
//         borrowManagement.borrowApply(borrowAmount); // Apply to borrow 1000 USDC
//         vm.stopPrank();

//         mockSourceChainConfirmBorrow(user1, address(mockCollateralWETH), address(mockBorrowUSDC), borrowAmount);

//         // user1 repays the borrowed amount
//         vm.startPrank(user1);
//         mockBorrowUSDC.approve(address(borrowManagement), borrowAmount);
//         borrowManagement.repay(borrowAmount);
//         vm.stopPrank();

//         mockSourceChainConfirmRepay(user1, BorrowStatus.REPAY_CONFIRMED_BY_SOURCE);

//         (
//             /*address collateralToken*/,
//             /*address borrowToken*/,
//             /*address initiator*/,
//             /*uint256 _sourceChainId*/,
//             uint256 pendingAmount,
//             uint256 borrowedAmount,
//             BorrowStatus status,
//             bytes memory proof,
//             uint64 updatedAt
//         ) = borrowManagement.availableBorrowTokenBalance(user1);
//         assertEq(pendingAmount, 0, "Pending amount should be 0 after repayment confirmation");
//         assertEq(borrowedAmount, 0, "Borrowed amount should be 0 after repayment confirmation");
//         assertEq(
//             uint8(status),
//             uint8(BorrowStatus.REPAY_CONFIRMED_BY_SOURCE),
//             "Status should be REPAY_CONFIRMED_BY_SOURCE after repayment confirmation"
//         );
//         assertTrue(updatedAt > 0, "Updated at should be set after repayment confirmation");
//         // Check if the borrow token is transferred back to BorrowManagement
//         assertEq(
//             mockBorrowUSDC.balanceOf(address(borrowManagement)),
//             supplyUSDCINBorrowManagement,
//             "BorrowManagement should have USDC balance back after repayment"
//         );
//         assertEq(mockBorrowUSDC.balanceOf(user1), 0, "User should have 0 USDC balance after repayment confirmation");
//     }

//     function mockDepositCollateralWithEnableBorrow(
//         address depositor,
//         address collateralToken,
//         address borrowToken,
//         uint256 _sourceChainId,
//         uint256 _targetChainId
//     ) public {
//         CrossChainBorrowInfo memory info = CrossChainBorrowInfo({
//             recipientAddress: depositor,
//             collateralToken: collateralToken,
//             borrowToken: borrowToken,
//             sourceChainId: _sourceChainId,
//             targetChainId: _targetChainId,
//             commitmentHash: bytes32(0),
//             nullifierHash: bytes32(0),
//             zkProof: ""
//         });
//         // Emit the BorrowInitial event
//         vm.expectEmit(true, true, true, false);
//         emit BorrowInitial(user1, address(mockCollateralWETH), address(mockBorrowUSDC));
//         borrowManagement.borrowInitial(info);
//     }

//     function mockSourceChainConfirmBorrow(address user, address /*collateralToken*/, address /*borrowToken*/, uint256 /*amount*/)
//         public
//     {
//         borrowManagement.borrowApprovedAndTransfer(user);
//     }

//     function mockSourceChainConfirmRepay(address user, BorrowStatus status) public {
//         borrowManagement.setAvailableBorrowTokenBalance(user, status);
//     }
// }
