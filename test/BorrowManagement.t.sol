// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {MockERC20} from "./mock/MockERC20.sol";
import {BorrowManagement, AvaiableBorrowBalance} from "src/core/borrow/BorrowManagement.sol";
import "forge-std/Test.sol";
import "./utils/Cheats.sol";

contract BorrowManagementTest is Test {
    BorrowManagement borrowManagement;

    Cheats cheats;

    MockERC20 mockETH;

    function setUp() public {
        address routerAddress = address(0x1234); // Mock router address TODO
        borrowManagement = BorrowManagement(routerAddress);
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
