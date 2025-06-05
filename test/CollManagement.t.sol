// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {CollManagement} from 'src/core/coll/CollManagement.sol';
import 'forge-std/Test.sol';
import './utils/Cheats.sol';

contract CollManagementTest is Test {
    CollManagement collManagement;

    Cheats cheats;

    function setUp() public {
        collManagement = new CollManagement();
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
}
