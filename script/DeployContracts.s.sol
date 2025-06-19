// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "./Helper.sol";
import {BorrowManagement} from "src/core/borrow/BorrowManagement.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import {MockERC20, ERC20} from "test/mock/MockERC20.sol";
import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";
import {CollManagement, DepositCollateralInfo, TargetChainBorowInfo} from "src/core/coll/CollManagement.sol";

// mockCollateralWETH : necessary praparation for the CollManagement and BorrowManagement
// PrivacyPool for the source  chain
// https://sepolia.etherscan.io/search?q=
// privacyPool in sepolia   https://sepolia.etherscan.io/address/0x6cb13dce38690d4ab49d17416c1df23cc811d5a5#code
// mockCollateralWETH https://sepolia.etherscan.io/address/0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE#code

contract DeployPrepareContractForSourceChain is Script, Helper {
    function run(uint256 blockChainID) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 mockCollateralWETH = new MockERC20("Mock Collateral ETH", "WETH");
        PrivacyPool privacyPool = new PrivacyPool(20, address(0), address(0), address(0), true); // ENABLE_ZK_BORROW_CHECK = true for deployment;

        console.log(
            "mockCollateralWETH contract deployed on ",
            networks[blockChainID],
            "with address: ",
            address(mockCollateralWETH)
        );

        console.log("PrivacyPool contract deployed on ", networks[blockChainID], "with address: ", address(privacyPool));

        vm.stopBroadcast();
    }
}

// mockBorrowUSDC : necessary praparation for the CollManagement and BorrowManagement
// PrivacyPool for the target  chain
// PrivacyPool https://testnet.snowtrace.io/address/0x64D392194d45727c061684c394035CfF240480D1/contract/43113/code
// https://repo.sourcify.dev/43113/0x64D392194d45727c061684c394035CfF240480D1 (verify the PrivacyPool contract)
// mockBorrowUSDC  https://testnet.snowtrace.io/address/0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5
contract DeployPrepareContractForTargetChain is Script, Helper {
    function run(uint256 blockChainID) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "USDC");
        PrivacyPool privacyPool = new PrivacyPool(20, address(0), address(0), address(0), true); // ENABLE_ZK_BORROW_CHECK = true for deployment;

        console.log(
            "mockBorrowUSDC contract deployed on ", networks[blockChainID], "with address: ", address(mockBorrowUSDC)
        );
        console.log("PrivacyPool contract deployed on ", networks[blockChainID], "with address: ", address(privacyPool));

        vm.stopBroadcast();
    }
}

// https://sepolia.etherscan.io/address/0x74ea849ba30b0a8ea2b749bb662516935331492c#code
// then necessary praparation for the CollManagement contract deployment
/*
 * 1) the address deployed the  CollManagement in souce chain should have enought native token for the related chain. current eth/Ethereum Sepolia
 * 2) CCIP fees by using LINK token, the CollManagement contract should have enough LINK token for the CCIP fees.
 * 3) The related contracts for CollManagement
 *  - chainlink price feed address  for the collateral and borrow token (TODO check should actually the address(collateral/ <collateral/usdc>price feed address) 
 *  - Collateral Token: mockCollateralWETH, current deployed by ourself. (TODO check using the offical token?)
 * (QUESTION? current onnly suppport the mockBorrowUSDC are same for source chain and target chain. this should adjust ,Temp use target chain's mockBorrowUSDC)
 *  - Borrow Token: mockBorrowUSDC, current deployed by ourself.
 *  - PrivacyPool for the source chain
 * - 
 * 
 */
contract DeployCollManagementSender is Script, Helper {
    uint256 public immutable COLLATERAL_RATIO = 15_000_000_000_000_000_000; // collateral ratio, 150%

    // TODO should input chainID
    function run(
        uint256 sourceBlockChainID,
        uint256 targetBlockChainID,
        address sourceCollateralToken,
        address targetBorrowUSDC,
        address privacyPool_source_chain
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address sourceRouter, address link,,) = getConfigFromNetwork(sourceBlockChainID);

        (address ETH_USD_PRICE_FEED, address USDC_USD_PRICE_FEED) = getPriceFeeds(sourceBlockChainID);
        CollManagement sender_collManagement = new CollManagement(
            sourceCollateralToken,
            ETH_USD_PRICE_FEED,
            targetBorrowUSDC,
            USDC_USD_PRICE_FEED,
            COLLATERAL_RATIO, // 150% collateral ratio
            targetBlockChainID,
            sourceRouter,
            privacyPool_source_chain,
            link
        );
        console.log(
            "CollManagement contract deployed on ",
            networks[sourceBlockChainID],
            "with address: ",
            address(sender_collManagement)
        );

        vm.stopBroadcast();
    }
}

// https://testnet.snowtrace.io/address/0xfa12b0c5af2d60a4748f4038163854e8faad26d8
contract DeployBorrowManagementReceiver is Script, Helper {
    function run(
        uint256 targetBlockChainID,
        address sourceCollateralToken,
        address targetBorrowUSDC,
        address targetChainPrivacyPool
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address targetRouter, address linkToken,,) = getConfigFromNetwork(targetBlockChainID);

        BorrowManagement receiver_borrowManagement = new BorrowManagement(
            targetBorrowUSDC, sourceCollateralToken, targetRouter, targetChainPrivacyPool, linkToken
        );
        console.log(
            "borrowManagement contract deployed on ",
            networks[targetBlockChainID],
            "with address: ",
            address(receiver_borrowManagement)
        );

        vm.stopBroadcast();
    }
}

// Set the router for the StratoLend Network
// 1) Mint  mockBorrowUSDC for BorrowManagement
// 2) set each other's address for the CollManagement and BorrowManagement
// 4) set targetChainSelector for CollManagement, set sourceChainSelector for BorrowManagement
// 5) make CollManagement and BorrowManagement can withdraw the LINK token for the CCIP fees
contract SetRouterForStratoLendNetWorkForSource is Script, Helper {
    function run(
        address sender_collManagement,
        address receiver_borrowManagement,
        address mockCollateralWETH,
        uint256 targetBlockChainID
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (,,, uint64 targetChainSelector) = getConfigFromNetwork(targetBlockChainID);

        CollManagement(sender_collManagement).initTargetChainParamsForCCIP(
            mockCollateralWETH, receiver_borrowManagement, targetChainSelector
        );

        vm.stopBroadcast();
    }
}

contract SetRouterForStratoLendNetWorkForTarget is Script, Helper {
    function run(
        address sender_collManagement,
        address receiver_borrowManagement,
        address targetBorrowUSDC,
        uint256 sourceBlockChainID
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address targetRouter, address linkToken,, uint64 sourceChainSelector) =
            getConfigFromNetwork(sourceBlockChainID);
        BorrowManagement(receiver_borrowManagement).initSourceChainParamsForCCIP(
            targetBorrowUSDC, sender_collManagement, sourceChainSelector
        );
        vm.stopBroadcast();
    }
}

// Prepare
// 1) user select collateral token in the source chain. should confime have sufficient collateral token
// 2) if use specify recipient, should confirm the recipient address  (doing)
// 3) before borrow, should confirm the borrowManagemet have enough borrow token (mockBorrowUSDC) for the user

// TODO can reference blew code , directly execute the send function
contract DepositCollateral is Script, Helper {
    function run(
        address sender_collManagement,
        address mockCollateralWETH,
        uint256 collateralAmount,
        uint256 targetChainId,
        address mockBorrowUSDC,
        address recipient_by_depositor
    ) external {
        DepositCollateralInfo memory depositInfo = DepositCollateralInfo({
            collateralToken: mockCollateralWETH,
            amount: collateralAmount,
            targetChainId: targetChainId,
            borrowToken: mockBorrowUSDC,
            recipientAddress: recipient_by_depositor, // specify the recipient address
            proofA: bytes(""), // empty proof for normal mode
            commitmentHash: bytes32(0) // no commitment hash in normal mode
        });

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ERC20(mockCollateralWETH).approve(sender_collManagement, collateralAmount);
        CollManagement(sender_collManagement).depositCollateral(depositInfo);

        vm.stopBroadcast();
    }
}

// below should check
// 1. fuji operate
contract BorrowApply is Script, Helper {
    function run(address receiver_borrowManagement, uint256 borrowAmount) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_RONDOMER_USER");
        vm.startBroadcast(deployerPrivateKey);

        BorrowManagement(receiver_borrowManagement).borrowApply(borrowAmount);

        vm.stopBroadcast();
    }
}
