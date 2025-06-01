// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MockLending.sol";

contract MockLendingTest is Test {
    MockLending lending;

    function setUp() public {
        lending = new MockLending();
    }

    function testDeposit() public {
        lending.deposit{value: 1 ether}();
        assertEq(lending.deposits(address(this)), 1 ether);
    }

    function testBorrow() public {
        lending.borrow(500);
        assertTrue(true); // borrow 不 revert 即通过
    }
}
