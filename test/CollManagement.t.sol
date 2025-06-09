// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import 'forge-std/Test.sol';
import './utils/Cheats.sol';
// import {CollManagement} from 'src/core/coll/CollManagement.sol';
import "../../src/core/coll/CollManagement.sol";
import "../../src/core/interfaces/BorrowInfo.sol";

contract CollManagementTest is Test {
    CollManagement collManagement;

    Cheats cheats;

    function setUp() public {
        collManagement = new CollManagement();
        cheats = Cheats(address(this));
    }

    function testDepositCollateral() public {
        uint256 startBalance = collManagement.userCollateral(address(this));
        collManagement.depositCollateral(100 ether);
        // Check if the mortgage is renewed
        assertEq(collManagement.userCollateral(address(this)), startBalance + 100 ether);
        // You can also test emit events, or mock the content of cross-chain messages
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
