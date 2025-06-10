// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "./utils/Cheats.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import "src/core/coll/CollManagement.sol";

import {MockERC20} from "./mock/MockERC20.sol";

contract CollManagementTest is Test {
    CollManagement collManagement;

    Cheats cheats;

    MockERC20 mockETH;
    MockERC20 mockUSDC;

    function setUp() public {
        address rounter = address(0x1234); // Mock router address TODO
        collManagement = new CollManagement(rounter);
        cheats = Cheats(address(this));
        mockETH = new MockERC20("Mock ETH", "mETH");
        mockUSDC = new MockERC20("Mock USDC", "mUSDC");

        // Set up the mock ETH as a supported collateral token
        collManagement.setSupportCollBorrowToken(address(mockETH), address(mockUSDC));
    }

    function testDepositCollateral() public {
        // Mint some mock ETH to the test contract
        mockETH.mint(address(this), 1000 ether);

        uint256 startBalance = collManagement.collateralBalances(address(this), address(mockETH));
        mockETH.approve(address(collManagement), 100 ether);
        collManagement.depositCollateral(address(mockETH), 100 ether);
        // Check if the mortgage is renewed
        assertEq(collManagement.collateralBalances(address(this), address(mockETH)), startBalance + 100 ether);

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
