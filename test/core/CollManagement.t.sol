// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import {BorrowManagement} from "src/core/borrow/BorrowManagement.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {MockCCIPRouter} from "test/mock/MockCCIPRouter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";
import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";
import {Groth16Verifier as DepositVerifier} from "contracts/DepositVerifier.sol";
import {Groth16Verifier as BorrowVerifier} from "contracts/BorrowVerifier.sol";

contract CollManagementTest is Test {
    CollManagement public collManagement;
    BorrowManagement public borrowManagement;
    PrivacyPool public privacyPool;
    MockERC20 public weth;
    MockERC20 public usdc;
    LinkToken public linkToken;
    MockCCIPRouter public router;
    DepositVerifier public depositVerifier;
    BorrowVerifier public borrowVerifier;

    address public user = address(1);
    uint256 public constant USER_WETH_BALANCE = 10 ether;
    uint64 public constant DEST_CHAIN_SELECTOR = 12345;

    function setUp() public {
        // Deploy Router and Link Token
        router = new MockCCIPRouter();
        linkToken = new LinkToken();

        // Deploy Verifiers
        depositVerifier = new DepositVerifier();
        borrowVerifier = new BorrowVerifier();

        // Deploy PrivacyPool
        privacyPool = new PrivacyPool(20, address(depositVerifier), address(borrowVerifier), address(linkToken), false);

        // Deploy Collateral and Borrow Tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy Core Contracts
        collManagement = new CollManagement(address(router), address(linkToken), address(weth));
        collManagement.setPrivacyPool(address(privacyPool));
        borrowManagement =
            new BorrowManagement(address(usdc), address(router), address(privacyPool), address(linkToken));

        // Fund user with collateral
        weth.mint(user, USER_WETH_BALANCE);

        // Grant LINK minting role and fund CollManagement
        linkToken.grantMintRole(address(this));
        linkToken.mint(address(collManagement), 100 ether);

        // Set up price feeds
        MockV3Aggregator wethPriceFeed = new MockV3Aggregator(8, 2000 * 1e8); // $2000
        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(8, 1 * 1e8); // $1
        collManagement.setPriceFeed(address(weth), address(wethPriceFeed));
        collManagement.setPriceFeed(address(usdc), address(usdcPriceFeed));

        // Set target chain params
        collManagement.setTargetChainParams(address(weth), DEST_CHAIN_SELECTOR, address(borrowManagement));
    }

    function test_depositCollateral_succeeds() public {
        vm.startPrank(user);
        weth.approve(address(collManagement), USER_WETH_BALANCE);

        // The call that was failing in the script
        collManagement.depositCollateral(address(weth), USER_WETH_BALANCE, user);
        vm.stopPrank();

        // Assert final state
        (uint256 totalDeposited,) = collManagement.userCollateral(user, address(weth));
        assertEq(totalDeposited, USER_WETH_BALANCE, "Collateral was not deposited correctly");
        assertEq(weth.balanceOf(address(collManagement)), USER_WETH_BALANCE, "CollManagement did not receive WETH");
    }

    function test_getHealthFactor_succeeds() public {
        // Setup the exact state from the script
        uint256 collateralAmount = 10 * 1e18; // 10 WETH
        uint256 debtAmount = 1600 * 1e6; // 1600 USDC

        // Deposit collateral
        vm.startPrank(user);
        weth.approve(address(collManagement), collateralAmount);
        collManagement.depositCollateral(address(weth), collateralAmount, user);
        vm.stopPrank();

        // Issue debt
        collManagement.grantRole(collManagement.DEBT_ISSUER_ROLE(), address(this));
        collManagement.issueDebtForTest(user, address(usdc), debtAmount);

        // Call the function
        uint256 healthFactor = collManagement.getHealthFactor(user);

        // WETH = $2000, USDC = $1
        // Collateral Value = 10 * 2000 = $20,000
        // Debt Value = 1600 * 1 = $1600
        // Expected HF = (20000 * 1e18) / 1600 = 12.5 * 1e18
        uint256 expectedHealthFactor = 125 * 1e17; // 12.5

        assertEq(healthFactor, expectedHealthFactor, "Health factor calculation is incorrect");
    }
}
