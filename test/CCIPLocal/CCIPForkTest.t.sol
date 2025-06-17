// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20, ERC20} from "test/mock/MockERC20.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";

import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

import {Register} from "@chainlink/local/src/ccip/Register.sol";
import {CollManagement, DepositCollateralInfo, TargetChainBorowInfo} from "src/core/coll/CollManagement.sol";
import {BorrowManagement, AvaiableBorrowBalance} from "src/core/borrow/BorrowManagement.sol";
import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

contract CCIPForkTest is Test {
    address constant ETH_USD_ETHEREUM_SEPOLIA = address(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    address constant USDC_USD_ETHEREUM_SEPOLIA = address(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E);

    // related data for CollManagement, BorrowManagement
    CollManagement sender_collManagement;
    BorrowManagement receiver_borrowManagement;
    MockERC20 mockCollateralWETH;
    MockERC20 mockBorrowUSDC;
    MockV3Aggregator mockV3AggregatorCollateralWETH;
    MockV3Aggregator mockV3AggregatorBorrowUSDC;
    PrivacyPool privacyPool_source_chain;
    PrivacyPool privacyPool_target_chain;
    uint256 supplyUSDCINBorrowManagement = 10000e8; // 10000 USDC
    uint256 public immutable COLLATERAL_RATIO = 15_000_000_000_000_000_000; // collateral ratio, 150%

    uint256 sourceChainId = 11155111; // Ethereum Sepolia
    uint256 targetChainId = 43113; // Avalanche Fuji Testnet
    uint256 sourceFork;
    uint256 destinationFork;

    uint64 targetChainSelector; // For testing DepositCollateralInfo and enable borrow
    uint64 sourceChainSelector;

    // test users
    address depositor;
    address recipient_by_depositor;
    address stratoLend_manager;

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    function setUp() public {
        string memory SOURCE_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        string memory DESTINATION_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");
        // destinationFork = vm.createSelectFork(DESTINATION_RPC_URL, uint256(41967909)); // block number 63992922
        destinationFork = vm.createSelectFork(DESTINATION_RPC_URL);
        sourceFork = vm.createFork(SOURCE_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        // TODO for now, sourceChain and targetChain all use same address for mockCollateralWETH and mockBorrowUSDC

        depositor = makeAddr("depositor");
        recipient_by_depositor = makeAddr("recipient_by_depositor");
        stratoLend_manager = makeAddr("stratoLend_manager");
        vm.startPrank(stratoLend_manager);
        mockCollateralWETH = new MockERC20("Mock Collateral ETH", "WETH");
        mockBorrowUSDC = new MockERC20("Mock Borrow USDC", "USDC");
        vm.stopPrank();
        vm.makePersistent(address(mockCollateralWETH));
        vm.makePersistent(address(mockBorrowUSDC));
        vm.makePersistent(depositor);
        vm.makePersistent(recipient_by_depositor);
        vm.makePersistent(stratoLend_manager);

        Register.NetworkDetails memory sourceNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(sourceChainId);
        Register.NetworkDetails memory destNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(targetChainId);

        vm.selectFork(sourceFork);
        privacyPool_source_chain = new PrivacyPool(20, address(0));

        sender_collManagement = _createCollManagement(
            targetChainId,
            address(privacyPool_source_chain),
            sourceNetworkDetails.routerAddress,
            sourceNetworkDetails.linkAddress
        );
        vm.makePersistent(address(sender_collManagement));

        ccipLocalSimulatorFork.requestLinkFromFaucet(address(sender_collManagement), 10 ether);

        // This should also persistant?
        vm.selectFork(destinationFork);
        privacyPool_target_chain = new PrivacyPool(20, address(0));

        receiver_borrowManagement = _createBorrowManagement(
            destNetworkDetails.routerAddress, address(privacyPool_target_chain), destNetworkDetails.linkAddress
        );

        vm.makePersistent(address(receiver_borrowManagement));
        // ccipLocalSimulatorFork.requestLinkFromFaucet(address(receiver_borrowManagement), 10 ether);

        vm.selectFork(sourceFork);
        vm.prank(stratoLend_manager);
        sender_collManagement.initTargetChainParamsForCCIP(
            address(mockCollateralWETH), address(receiver_borrowManagement), destNetworkDetails.chainSelector
        );

        vm.selectFork(destinationFork);
        vm.prank(stratoLend_manager);
        receiver_borrowManagement.initSourceChainParamsForCCIP(
            address(mockBorrowUSDC), address(sender_collManagement), sourceNetworkDetails.chainSelector
        );
    }

    function testForkDepositCollWithEnableBorrowNormalMode() public {
        vm.selectFork(sourceFork);

        // Deposit collateral
        uint256 collateralAmount = 10 ether;
        vm.prank(stratoLend_manager);
        mockCollateralWETH.mint(depositor, collateralAmount);

        DepositCollateralInfo memory depositInfo = DepositCollateralInfo({
            collateralToken: address(mockCollateralWETH),
            amount: collateralAmount,
            targetChainId: targetChainId,
            borrowToken: address(mockBorrowUSDC),
            recipientAddress: recipient_by_depositor, // specify the recipient address
            proofA: bytes(""), // empty proof for normal mode
            commitmentHash: bytes32(0) // no commitment hash in normal mode
        });

        uint256 balanceOfDepositorBefore = mockCollateralWETH.balanceOf(depositor);
        vm.startPrank(depositor);
        mockCollateralWETH.approve(address(sender_collManagement), collateralAmount);

        sender_collManagement.depositCollateral(depositInfo);
        vm.stopPrank();

        uint256 balanceOfDepositorAfter = mockCollateralWETH.balanceOf(depositor);
        assertEq(balanceOfDepositorAfter, balanceOfDepositorBefore - collateralAmount);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        uint64 currentTimeStamp = uint64(block.timestamp);

        // check BorrowManagement
        (
            address collateralToken,
            address borrowToken,
            address initiator,
            uint256 sourceChainId2,
            uint256 pendingAmount,
            uint256 borrowedAmount,
            BorrowStatus status,
            bytes memory proof,
            uint64 updatedAt
        ) = receiver_borrowManagement.availableBorrowTokenBalance(recipient_by_depositor);
        assertEq(collateralToken, address(mockCollateralWETH), "Collateral token mismatch");
        assertEq(borrowToken, address(mockBorrowUSDC), "Borrow token mismatch");
        assertEq(initiator, depositor, "Initiator mismatch");
        assertEq(sourceChainId, sourceChainId2, "Source chain ID mismatch");
        assertEq(pendingAmount, 0, "Pending amount should be zero in normal mode");
        assertEq(borrowedAmount, 0, "Borrowed amount should be zero in normal mode");
        assertEq(uint8(status), uint8(BorrowStatus.INITIAL), "Status should be NONE");
        assertEq(proof, bytes(""), "Proof should be empty in normal mode");
        assertEq(currentTimeStamp, updatedAt);
    }

    // Notice, for now can't test below as can't fork the  fuji's latest block, which doesn't support the selectChain's chainselector
    // https://testnet.snowtrace.io/address/0xF694E193200268f9a4868e4Aa017A0118C9a8177/contract/43113/readContract?chainid=43113
    function testForkBorrowApplyWithConfirmedBySourceChain() public {
        vm.selectFork(sourceFork);

        // Deposit collateral
        uint256 collateralAmount = 10 ether;
        vm.prank(stratoLend_manager);
        mockCollateralWETH.mint(depositor, collateralAmount);

        DepositCollateralInfo memory depositInfo = DepositCollateralInfo({
            collateralToken: address(mockCollateralWETH),
            amount: collateralAmount,
            targetChainId: targetChainId,
            borrowToken: address(mockBorrowUSDC),
            recipientAddress: recipient_by_depositor, // specify the recipient address
            proofA: bytes(""), // empty proof for normal mode
            commitmentHash: bytes32(0) // no commitment hash in normal mode
        });

        uint256 balanceOfDepositorBefore = mockCollateralWETH.balanceOf(depositor);
        vm.startPrank(depositor);
        mockCollateralWETH.approve(address(sender_collManagement), collateralAmount);

        sender_collManagement.depositCollateral(depositInfo);
        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);

        vm.startPrank(recipient_by_depositor);
        receiver_borrowManagement.borrowApply(100e8);
        vm.stopPrank();
    }

    function _createCollManagement(uint256 targetChainId, address privacyPool, address sourceRouter, address linkToken)
        internal
        returns (CollManagement sender_collManagement)
    {
        vm.prank(stratoLend_manager);
        sender_collManagement = new CollManagement(
            address(mockCollateralWETH),
            ETH_USD_ETHEREUM_SEPOLIA,
            address(mockBorrowUSDC),
            USDC_USD_ETHEREUM_SEPOLIA,
            COLLATERAL_RATIO, // 150% collateral ratio
            targetChainId,
            sourceRouter,
            privacyPool,
            linkToken
        );
    }

    function _createBorrowManagement(address destationRouter, address privacyPool, address linkToken)
        internal
        returns (BorrowManagement receiver_borrowManagement)
    {
        vm.prank(stratoLend_manager);
        receiver_borrowManagement = new BorrowManagement(
            address(mockBorrowUSDC), address(mockCollateralWETH), destationRouter, privacyPool, linkToken
        );

        vm.prank(stratoLend_manager);
        mockBorrowUSDC.mint(address(receiver_borrowManagement), supplyUSDCINBorrowManagement);
    }

    function testTransferLinkToken() public {
        vm.selectFork(sourceFork);

        address linkToken = ccipLocalSimulatorFork.getNetworkDetails(sourceChainId).linkAddress;
        uint256 linkBalanceBefore = ERC20(linkToken).balanceOf(depositor);
        uint256 transferAmount = 1 ether;
        vm.startPrank(stratoLend_manager);
        sender_collManagement.transferLinkToken(depositor, transferAmount);
        vm.stopPrank();
        uint256 linkBalanceAfter = ERC20(linkToken).balanceOf(depositor);
        assertEq(linkBalanceAfter - linkBalanceBefore, 1 ether, "Link token transfer failed");

        // avax fuji tesnet should check. fork doesn't work [Revert] EvmError: Revert
        vm.selectFork(destinationFork);
        linkToken = ccipLocalSimulatorFork.getNetworkDetails(targetChainId).linkAddress;
        uint256 linkBalanceInReceiverBefore = ERC20(linkToken).balanceOf(recipient_by_depositor);
        vm.startPrank(stratoLend_manager);
        receiver_borrowManagement.transferLinkToken(recipient_by_depositor, transferAmount);
        vm.stopPrank();
        uint256 linkBalanceInReceiverAfter = ERC20(linkToken).balanceOf(recipient_by_depositor);
        assertEq(
            linkBalanceInReceiverAfter - linkBalanceInReceiverBefore, 1 ether, "Link token transfer failed in receiver"
        );
    }
}
