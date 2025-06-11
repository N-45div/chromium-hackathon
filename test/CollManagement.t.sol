// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import "src/core/coll/CollManagement.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockV3Aggregator} from "./mock/MockV3Aggregator.sol";

contract CollManagementTest is Test {
    CollManagement collManagement;

    MockERC20 mockCollateralWETH;
    MockERC20 mockBorrowUSDC;
    MockV3Aggregator mockV3AggregatorCollateralWETH;
    MockV3Aggregator mockV3AggregatorBorrowUSDC;

    uint256 public immutable COLLATERAL_RATIO = 15_000_000_000_000_000_000; // collateral ratio, 150%
    uint256 targetChainId = 43113; // Avalanche Fuji Testnet

    address manager = address(0x999);
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    event CollateralWithdrawn(address indexed user, address indexed collateralToken, uint256 amount);

    function setUp() public {
        // todo init uint256 public immutable COLLATERAL_RATIO = 15_000_000_000_000_000_000; // collateral ratio, 150%

        address rounter = address(0x1234); // Mock router address TODO
        mockCollateralWETH = new MockERC20("Mock Collateral ETH", "mETH");
        mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "mUSDC");

        // mock V3 Aggregators for price feeds
        mockV3AggregatorCollateralWETH = new MockV3Aggregator(18, 2000 * 10 ** 18); // Mock price for WETH
        mockV3AggregatorBorrowUSDC = new MockV3Aggregator(8, 1 * 10 ** 8); // Mock price for USDC

        vm.startPrank(manager);

        collManagement = new CollManagement(
            address(mockCollateralWETH),
            address(mockV3AggregatorCollateralWETH),
            address(mockBorrowUSDC),
            address(mockV3AggregatorBorrowUSDC),
            COLLATERAL_RATIO, // 150% collateral ratio
            targetChainId,
            rounter
        );

        vm.stopPrank();
    }

    function testDepositCollateral() public {
        mockCollateralWETH.mint(user1, 1000 ether);

        uint256 startBalance = collManagement.collateralBalances(user1, address(mockCollateralWETH));
        vm.startPrank(user1);
        mockCollateralWETH.approve(address(collManagement), 100 ether);
        collManagement.depositCollateral(address(mockCollateralWETH), 100 ether);
        vm.stopPrank();
        // Check if the mortgage is renewed
        assertEq(collManagement.collateralBalances(user1, address(mockCollateralWETH)), startBalance + 100 ether);

        // You can also test emit events, or mock the content of cross-chain messages
    }

    function testWithdrawCollateral() public {
        mockCollateralWETH.mint(user1, 100 ether);

        // user1 deposits 100 WETH as collateral
        uint256 startBalance = collManagement.collateralBalances(user1, address(mockCollateralWETH));

        vm.startPrank(user1);
        mockCollateralWETH.approve(address(collManagement), 100 ether);
        collManagement.depositCollateral(address(mockCollateralWETH), 100 ether);
        vm.stopPrank();

        // user1 withdraws 50 WETH
        vm.startPrank(user1);
        collManagement.setCrossBalances(user1, address(mockBorrowUSDC), targetChainId, 0 ether); // no borrow USDC in target chain
        vm.expectEmit(true, true, true, false);
        emit CollateralWithdrawn(user1, address(mockCollateralWETH), 50 ether);
        collManagement.withdrawCollateral(address(mockCollateralWETH), 50 ether);
        vm.stopPrank();

        assertEq(
            collManagement.collateralBalances(user1, address(mockCollateralWETH)), startBalance + 100 ether - 50 ether
        );
    }

    function testWithdrawCollateralWhenBorrowBeyondCollateralRatio() public {
        mockCollateralWETH.mint(user1, 10 ether);

        // user1 deposits 100 WETH as collateral
        uint256 startBalance = collManagement.collateralBalances(user1, address(mockCollateralWETH));

        vm.startPrank(user1);
        mockCollateralWETH.approve(address(collManagement), 10 ether);
        collManagement.depositCollateral(address(mockCollateralWETH), 10 ether); // 10 WETH deposited, market value 20k USD
        vm.stopPrank();

        // mimic cross-chain borrow USDC,user1 borrows 1000 USDC in target chain
        collManagement.setCrossBalances(user1, address(mockBorrowUSDC), targetChainId, 10000 * 1e8); // borrow 1000 USDC in target chain

        uint256 userCollateralRatio =
            collManagement.userCollateralRatio(user1, address(mockCollateralWETH), address(mockBorrowUSDC));
        console.log("userCollateralRatio: ", userCollateralRatio);

        // user1 withdraws 1 WETH
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                CollManagement.NoStatisfyCollateralRatio.selector,
                address(mockCollateralWETH),
                10 ether - 1 ether,
                address(mockBorrowUSDC),
                10000 * 1e8
            )
        );
        collManagement.withdrawCollateral(address(mockCollateralWETH), 1 ether);
        vm.stopPrank();
    }

    function testBorrowTokeModifiedBySourceChain() public returns (bool) {
        return true;
    }

    function testSetSupportedCollBorrowToken() public returns (bool) {
        return true;
    }

    function testGetAvaiableChainBorrowBalance() public returns (bool) {
        return true;
    }
}
