// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {BorrowManagement, AvaiableBorrowInfo} from 'src/core/borrow/BorrowManagement.sol';
import 'forge-std/Test.sol';
import './utils/Cheats.sol';
import "../../src/core/interfaces/BorrowInfo.sol";

contract BorrowManagementTest is Test {
    BorrowManagement borrowManagement;

    Cheats cheats;

    function setUp() public {
        borrowManagement = new BorrowManagement();
        cheats = Cheats(address(this));
    }

    function testDepositCollateral() public returns (bool) {
        return true;
    }

    function testDepositCollateralWithInfo() public returns (bool) {
        return true;
    }

    function testWithdrawCollateral() public returns (bool) {
        return true;
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

    function testCcipReceive() public {
    BorrowInfo memory info = BorrowInfo({
        user: address(0xABCD),
        token: address(0),
        amount: 100 ether,
        sourceChainSelector: 0,
        targetChainSelector: 0
    });
    bytes memory message = abi.encode(info);
    borrowManagement.ccipReceive(message);
    assertEq(borrowManagement.userBorrowed(address(0xABCD)), 100 ether);
    }
}
