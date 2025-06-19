// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";

import {IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/ccip/CCIPLocalSimulator.sol";
import {CCIPLocalSimulator} from "@chainlink/local/ccip/CCIPLocalSimulator.sol";

import {CollManagement, DepositCollateralInfo, TargetChainBorowInfo} from "src/core/coll/CollManagement.sol";
import {BorrowManagement, AvaiableBorrowBalance} from "src/core/borrow/BorrowManagement.sol";
import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

contract CCIPLocalTest is Test {
    // related data for CollManagement, BorrowManagement
    CollManagement sender_collManagement;
    BorrowManagement receiver_borrowManagement;
    MockERC20 mockCollateralWETH;
    MockERC20 mockBorrowUSDC;
    MockV3Aggregator mockV3AggregatorCollateralWETH;
    MockV3Aggregator mockV3AggregatorBorrowUSDC;
    PrivacyPool privacyPool;
    uint256 supplyUSDCINBorrowManagement = 10000e8; // 10000 USDC
    uint256 public immutable COLLATERAL_RATIO = 15_000_000_000_000_000_000; // collateral ratio, 150%

    // uint256 sourceChainId = 11155111; // Ethereum Sepolia
    // uint256 targetChainId = 43113; // Avalanche Fuji Testnet
    uint256 sourceChainId = 31337; // local test apply 31337
    uint256 targetChainId = 31337; // local test apply 31337

    uint64 targetChainSelector; // For testing DepositCollateralInfo and enable borrow
    uint64 sourceChainSelector;

    // test users
    address user1 = address(uint160(uint256(keccak256("user1"))));
    address user2_user1 = address(uint160(uint256(keccak256("user2_user1"))));
    address manager = address(uint160(uint256(keccak256("manager"))));

    CCIPLocalSimulator public ccipLocalSimulator;

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            WETH9 wrappedNative,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        // Local test, make below as same. For fork, should change
        targetChainSelector = chainSelector;
        sourceChainSelector = chainSelector;

        _initContracts(address(linkToken), address(sourceRouter), address(destinationRouter));

        uint256 linkForFees = 10_000 ether;
        ccipLocalSimulator.requestLinkFromFaucet(address(sender_collManagement), linkForFees);
        ccipLocalSimulator.requestLinkFromFaucet(address(receiver_borrowManagement), linkForFees);
    }

    function testDepositCollWithEnableBorrowNormalMode() public {
        // Deposit collateral
        uint256 collateralAmount = 10 ether; // Example amount, replace with actual value
        vm.startPrank(manager);
        mockCollateralWETH.mint(user1, collateralAmount);
        vm.stopPrank();
        DepositCollateralInfo memory depositInfo = DepositCollateralInfo({
            collateralToken: address(mockCollateralWETH),
            amount: collateralAmount,
            targetChainId: targetChainId,
            borrowToken: address(mockBorrowUSDC),
            recipientAddress: user2_user1, // specify the recipient address
            proofA: bytes(""), // empty proof for normal mode
            commitmentHash: bytes32(0) // no commitment hash in normal mode
        });

        vm.startPrank(user1);
        mockCollateralWETH.approve(address(sender_collManagement), collateralAmount);

        sender_collManagement.depositCollateral(depositInfo);
        vm.stopPrank();

        // Check Collateral
        assertEq(
            mockCollateralWETH.balanceOf(address(sender_collManagement)), collateralAmount, "Collateral not deposited"
        );

        (address borrowToken, address recipientAddress, uint256 syncBorrowBalance) =
            sender_collManagement.crossBalances(user1, targetChainId);
        assertEq(borrowToken, address(mockBorrowUSDC), "Borrow token not set correctly");
        assertEq(recipientAddress, user2_user1, "Recipient address not set correctly");
        assertEq(syncBorrowBalance, 0, "Sync borrow balance should be zero in normal mode");

        // check BorrowManagement
        (
            address collateralToken,
            address borrowToken2,
            address initiator,
            uint256 _sourceChainId,
            uint256 pendingAmount,
            uint256 borrowedAmount,
            BorrowStatus status,
            bytes memory proof,
            address originalDepositor, // Added new field
            uint64 updatedAt
        ) = receiver_borrowManagement.availableBorrowTokenBalance(user2_user1);
        assertEq(collateralToken, address(mockCollateralWETH), "Collateral token mismatch");
        assertEq(borrowToken2, address(mockBorrowUSDC), "Borrow token mismatch");
        assertEq(initiator, user2_user1, "Initiator mismatch");
        assertEq(sourceChainId, sourceChainId, "Source chain ID mismatch");
        assertEq(pendingAmount, 0, "Pending amount should be zero in normal mode");
        assertEq(borrowedAmount, 0, "Borrowed amount should be zero in normal mode");
        assertEq(uint8(status), uint8(BorrowStatus.INITIAL), "Status should be NONE");
        assertEq(proof, bytes(""), "Proof should be empty in normal mode");
        // assertEq(updatedAt, 0, "Updated at should be zero in normal mode");
    }

    function testBorrowApplyWithConfirmedBySourceChain() public {
        // Deposit collateral
        uint256 collateralAmount = 10 ether; // Example amount, replace with actual value
        vm.startPrank(manager);
        mockCollateralWETH.mint(user1, collateralAmount);

        DepositCollateralInfo memory depositInfo = DepositCollateralInfo({
            collateralToken: address(mockCollateralWETH),
            amount: collateralAmount,
            targetChainId: targetChainId,
            borrowToken: address(mockBorrowUSDC),
            recipientAddress: user2_user1, // specify the recipient address
            proofA: bytes(""), // empty proof for normal mode
            commitmentHash: bytes32(0) // no commitment hash in normal mode
        });

        vm.startPrank(user1);
        mockCollateralWETH.approve(address(sender_collManagement), collateralAmount);

        sender_collManagement.depositCollateral(depositInfo);
        vm.stopPrank();

        uint256 startBalance = mockBorrowUSDC.balanceOf(user2_user1);
        vm.startPrank(user2_user1);
        receiver_borrowManagement.borrowApply(100e8); // 100 USDC
        vm.stopPrank();
        uint256 endBalance = mockBorrowUSDC.balanceOf(user2_user1);
        assertEq(endBalance - startBalance, 100e8, "Borrow amount not applied correctly");
    }

    // TODO list. the necessary test features list for hackathon

    function _initContracts(address linkToken, address sourceRouter, address destinationRouter)
        internal
    {
        // initialize CollManagement
        vm.startPrank(manager);
        mockCollateralWETH = new MockERC20("Mock Collateral ETH", "mETH");
        mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "mUSDC");
        vm.stopPrank();
        // mock V3 Aggregators for price feeds
        mockV3AggregatorCollateralWETH = new MockV3Aggregator(18, 2000 * 10 ** 18); // Mock price for WETH
        mockV3AggregatorBorrowUSDC = new MockV3Aggregator(8, 1 * 10 ** 8); // Mock price for USDC
        // TODO, should change below params
        privacyPool = new PrivacyPool(20, address(0), address(0), address(0), false); // ENABLE_ZK_BORROW_CHECK = false for tests

        vm.startPrank(manager);
        //   uint64 _targetChainSelector,
        // address _targerChainBorrowManager

        sender_collManagement = new CollManagement(
            address(mockCollateralWETH),
            address(mockV3AggregatorCollateralWETH),
            address(mockBorrowUSDC),
            address(mockV3AggregatorBorrowUSDC),
            COLLATERAL_RATIO, // 150% collateral ratio
            targetChainId,
            sourceRouter,
            address(privacyPool),
            linkToken
        );

        // initialize BorrowManagement
        // TODO confirm linkToken same for source and target chain?
        receiver_borrowManagement = new BorrowManagement(
            address(mockBorrowUSDC), address(mockCollateralWETH), destinationRouter, address(privacyPool), linkToken
        );

        mockBorrowUSDC.mint(address(receiver_borrowManagement), supplyUSDCINBorrowManagement);

        sender_collManagement.initTargetChainParamsForCCIP(
            address(mockCollateralWETH), address(receiver_borrowManagement), targetChainSelector
        );

        receiver_borrowManagement.initSourceChainParamsForCCIP(
            address(mockBorrowUSDC), address(sender_collManagement), sourceChainSelector
        );

        vm.stopPrank();
    }
}
