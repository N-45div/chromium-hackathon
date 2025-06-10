// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {MockERC20} from "./mock/MockERC20.sol";
import {BorrowManagement, AvaiableBorrowBalance} from "src/core/borrow/BorrowManagement.sol";
import "forge-std/Test.sol";

contract BorrowManagementTest is Test {
    BorrowManagement borrowManagement;

    MockERC20 mockCollateralWETH;
    MockERC20 mockBorrowUSDC;

    address manager = address(0x999);
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    function setUp() public {
        address routerAddress = address(0x1234); // Mock router address TODO
        mockCollateralWETH = new MockERC20("Mock Collateral ETH", "mETH");
        mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "mUSDC");

        vm.startPrank(manager);
        borrowManagement = new BorrowManagement(routerAddress, address(mockBorrowUSDC));
        borrowManagement.setSupportBorrowCollToken(address(mockBorrowUSDC), address(mockCollateralWETH));
        vm.stopPrank();
    }

    function testBorrow() public {}

    function testRepay() public {}

    function testSetSupportBorrowCollToken() public {
        // Set support for a new collateral token
        vm.startPrank(manager);
        borrowManagement.setSupportBorrowCollToken(address(mockBorrowUSDC), address(mockCollateralWETH));
        vm.stopPrank();

        // Check if the support is set correctly
        assertTrue(borrowManagement.supportBorrowCollToken(address(mockBorrowUSDC), address(mockCollateralWETH)));
    }

    // below funciton inherited from CCIPReceiver
    // function testCcipReceive() public {
    //     BorrowInfo memory info = BorrowInfo({
    //         user: address(0xABCD),
    //         token: address(0),
    //         amount: 100 ether,
    //         sourceChainSelector: 0,
    //         targetChainSelector: 0
    //     });
    //     bytes memory message = abi.encode(info);
    //     borrowManagement.ccipReceive(message);
    //     assertEq(borrowManagement.userBorrowed(address(0xABCD)), 100 ether);
    // }
}
