// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingSource.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) public { balanceOf[to] += amount; }
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "no balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract LendingSourceTest is Test {
    LendingSource public source;
    MockERC20 public token;

    function setUp() public {
        token = new MockERC20();
        source = new LendingSource(address(token), address(0x1234), 10001);
        token.mint(address(this), 100 ether);
    }

    function testDepositCollateral() public {
        token.transferFrom(address(this), address(source), 50 ether);
        source.depositCollateral(50 ether);
        assertEq(source.collaterals(address(this)), 50 ether);
    }
}
