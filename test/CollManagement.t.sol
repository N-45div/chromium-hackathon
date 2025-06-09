// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "./utils/Cheats.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import "src/core/coll/CollManagement.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CollManagementTest is Test {
    CollManagement collManagement;

    Cheats cheats;

    function setUp() public {
        collManagement = new CollManagement();
        cheats = Cheats(address(this));
        mockETH = new ERC20("Mock ETH", "mETH");

        // Set up the mock ETH as a supported collateral token
        borrowManagement.setSupportBorrowCollToken(address(mockETH), address(mockETH));
    }

    function testDepositCollateral() public {
        // Mint some mock ETH to the test contract
        mockETH.mint(address(this), 1000 ether);
        uint256 startBalance = collateralBalances[address(this)][address(mockETH)];
        collManagement.depositCollateral(100 ether);
        // Check if the mortgage is renewed
        assertEq(collManagement.userCollateral(address(this)), startBalance + 100 ether);
        collateralBalances[address(this)][address(mockETH)];

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
