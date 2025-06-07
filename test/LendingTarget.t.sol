// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingTarget.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) public { balanceOf[to] += amount; }
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "no balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract LendingTargetTest is Test {
    LendingTarget public target;
    MockERC20 public loanToken;
    address public user = address(0xABCD);

    function setUp() public {
        loanToken = new MockERC20();
        target = new LendingTarget(address(loanToken), address(0x1234), 10001);
        loanToken.mint(address(target), 1000 ether);
    }

    function testCcipReceiveAndBorrow() public {
        bytes memory message = abi.encode(user, 100 ether);
        target.ccipReceive(message);
        uint256 preBal = loanToken.balanceOf(user);
        target.borrowEnableBySourceChain(user, 50 ether);
        uint256 postBal = loanToken.balanceOf(user);
        assertEq(postBal - preBal, 50 ether);
    }
}
