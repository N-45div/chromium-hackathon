// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/core/privacy/PrivacyProxy.sol";
import "../src/core/coll/CollManagement.sol";
import "../src/core/privacy/verifiers/DepositVerifier.sol";
import "../src/core/privacy/verifiers/BorrowVerifier.sol";
import "./mock/MockERC20.sol";
import "../src/core/interfaces/ICollManagement.sol";

/**
 * @title PrivacyTest
 * @author StratoLend
 * @notice This test validates the end-to-end private deposit flow through the PrivacyProxy.
 */
contract PrivacyTest is Test {
    PrivacyProxy internal privacyProxy;
    CollManagement internal collManagement;
    MockERC20 internal weth;

    address internal user = address(1);
    uint256 internal constant DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        // Deploy Mock WETH
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        weth.mint(user, DEPOSIT_AMOUNT);

        // Deploy Core Contracts
        collManagement = new CollManagement(address(0), address(0), address(weth)); // Mock router and link

        // Deploy ZK Module
        DepositVerifier depositVerifier = new DepositVerifier();
        BorrowVerifier borrowVerifier = new BorrowVerifier();
        privacyProxy = new PrivacyProxy(
            20, // Merkle tree levels
            address(collManagement),
            address(depositVerifier),
            address(borrowVerifier)
        );

        // User approves the proxy to spend their WETH
        vm.startPrank(user);
        weth.approve(address(privacyProxy), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    /**
     * @notice Tests that a private deposit through the proxy correctly updates the CollManagement contract.
     */
    function test_PrivateDeposit() public {
        // 1. User generates a commitment off-chain
        uint256 commitment = 123456789; // Dummy commitment for testing

        // 2. User calls the deposit function on the proxy
        vm.startPrank(user);
        privacyProxy.deposit(address(weth), DEPOSIT_AMOUNT, commitment);
        vm.stopPrank();

        // 3. Verify the state of the CollManagement contract
        (uint256 totalDeposited, ) = collManagement.userCollateral(address(privacyProxy), address(weth));

        assertEq(totalDeposited, DEPOSIT_AMOUNT, "CollManagement should have the correct deposit amount");

        // 4. Verify token balances
        assertEq(weth.balanceOf(address(collManagement)), DEPOSIT_AMOUNT, "CollManagement should hold the WETH");
        assertEq(weth.balanceOf(user), 0, "User's WETH balance should be zero");
    }
}
