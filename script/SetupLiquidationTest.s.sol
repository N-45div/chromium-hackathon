// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {BorrowManagement} from "src/core/borrow/BorrowManagement.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";
import {MockCCIPRouter} from "test/mock/MockCCIPRouter.sol";
import {LinkToken} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

contract SetupLiquidationTest is Script {
    // Anvil default account #2
    uint256 constant USER_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address user = vm.addr(USER_PRIVATE_KEY);

    function run() external {
        // Deploy mock contracts
        MockCCIPRouter router = new MockCCIPRouter();
        LinkToken link = new LinkToken();
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy a new BorrowManagement contract for the test
        BorrowManagement borrowManagement =
            new BorrowManagement(address(usdc), address(router), address(0), address(link));

        // Deploy mock price feeds
        // WETH price: $1600
        MockV3Aggregator wethPriceFeed = new MockV3Aggregator(18, 1600 * 1e18);
        // USDC price: $1
        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(6, 1 * 1e6);

        // Deploy and configure CollManagement
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        CollManagement collManagement = new CollManagement(address(router), address(link), address(weth));
        collManagement.setTargetChainParams(address(weth), 43113, address(borrowManagement));

        // Set price feeds in CollManagement
        collManagement.setPriceFeed(address(weth), address(wethPriceFeed));
        collManagement.setPriceFeed(address(usdc), address(usdcPriceFeed));

        vm.stopBroadcast();

        // Grant mint role to self, mint LINK, and fund CollManagement
        link.grantMintRole(address(this));
        link.mint(address(this), 1000 * 1e18); // Mint 1000 LINK to the script contract
        link.transfer(address(collManagement), 100 * 1e18); // Transfer 100 LINK to CollManagement

        // 1. Mint collateral to the user
        uint256 depositAmount = 10 * 1e18; // 10 WETH
        weth.mint(user, depositAmount);

        // 2. User approves and deposits collateral into CollManagement
        vm.startBroadcast(USER_PRIVATE_KEY);
        weth.approve(address(collManagement), depositAmount);
        collManagement.depositCollateral(address(weth), depositAmount, user); // recipient on target chain is also user
        vm.stopBroadcast();

        // 3. Set a large debt for the user to make them under-collateralized
        uint256 debtAmount = 16000 * 1e6; // 16,000 USDC (to ensure HF < 1)

        vm.startBroadcast(deployerPrivateKey);
        collManagement.grantRole(collManagement.DEBT_ISSUER_ROLE(), address(this));
        collManagement.issueDebtForTest(user, address(usdc), debtAmount);
        vm.stopBroadcast();

        console.log("Set up user", user, "with 10 WETH collateral and 1600 USDC debt.");

        console.log("CollManagement deployed to:", address(collManagement));
        console.log("WETH deployed to:", address(weth));
        console.log("USDC deployed to:", address(usdc));
    }
}
