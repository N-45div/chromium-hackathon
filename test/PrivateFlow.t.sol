// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import {BorrowManagement} from "src/core/borrow/BorrowManagement.sol";
import {MockVerifier} from "./mock/MockVerifier.sol";
import {PrivacyPool} from "../src/core/privacy/PrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {IPrivacyPool} from "src/core/interfaces/IPrivacyPool.sol";
import {ProofHelper} from "./helper/ProofHelper.sol";

// --- Mock Contracts ---

contract MockRouter is IRouterClient {
    Client.Any2EVMMessage private _lastMessageSent;
    uint64 private _lastDestinationChainSelector;

    function getFee(uint64, Client.EVM2AnyMessage memory) external pure returns (uint256) {
        return 1e18;
    }

    function ccipSend(uint64 destinationChainSelector, Client.EVM2AnyMessage memory message)
        external
        payable
        returns (bytes32)
    {
        _lastDestinationChainSelector = destinationChainSelector;
        bytes32 messageId = keccak256(abi.encodePacked(block.timestamp, destinationChainSelector, message.data));
        _lastMessageSent = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: uint64(block.chainid),
            sender: abi.encode(address(this)),
            data: message.data,
            destTokenAmounts: message.tokenAmounts
        });
        return messageId;
    }

    function getLastMessageSent() external view returns (uint64, Client.Any2EVMMessage memory) {
        return (_lastDestinationChainSelector, _lastMessageSent);
    }

    function isChainSupported(uint64) external pure returns (bool) {
        return true;
    }

    function getSupportedTokens(uint64) external pure returns (address[] memory) {
        address[] memory tokens;
        return tokens;
    }

    function getOnRamp(uint64, address) external pure returns (address, address) {
        return (address(0), address(0));
    }

    function getOffRamp(uint64, address, address) external pure returns (address[] memory) {
        address[] memory ramps;
        return ramps;
    }

    function getSupportedSourceChains(uint64) external pure returns (uint64[] memory) {
        uint64[] memory chains;
        return chains;
    }

    function getSupportedDestinationChains(uint64) external pure returns (uint64[] memory) {
        uint64[] memory chains;
        return chains;
    }
}

contract MockPrivacyPool is IPrivacyPool {
    function deposit(bytes32, bytes calldata, address, uint256) external {}

    function authorizeBorrow(bytes32, bytes32, address, uint256, address, uint64, bytes calldata)
        external
        pure
        returns (bool)
    {
        return true;
    }

    function getRoot() external pure returns (bytes32) {
        return bytes32(0);
    }
}

// --- Test Contract ---

contract PrivateFlowTest is Test {
    uint64 constant SOURCE_CHAIN_SELECTOR = 1;
    uint64 constant TARGET_CHAIN_SELECTOR = 2;

    CollManagement source_collManagement;
    BorrowManagement target_borrowManagement;

    MockERC20 weth;
    MockERC20 usdc;
    MockERC20 link;
    MockRouter router;
    PrivacyPool privacyPool;
    MockVerifier depositVerifier;
    MockVerifier borrowVerifier;
    ProofHelper proofHelper;

    address depositor = makeAddr("depositor");
    address recipient = makeAddr("recipient");

    function setUp() public {
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        link = new MockERC20("ChainLink", "LINK", 18);
        router = new MockRouter();
        depositVerifier = new MockVerifier();
        borrowVerifier = new MockVerifier();
        proofHelper = new ProofHelper();
        privacyPool = new PrivacyPool(20, address(depositVerifier), address(borrowVerifier), address(link), true);

        source_collManagement = new CollManagement(address(router), address(link), address(weth));
        source_collManagement.setPrivacyPool(address(privacyPool));
        target_borrowManagement =
            new BorrowManagement(address(usdc), address(router), address(privacyPool), address(link));

        source_collManagement.setTargetChainParams(
            address(weth), TARGET_CHAIN_SELECTOR, address(target_borrowManagement)
        );
        target_borrowManagement.setSourceChainParams(
            address(weth), block.chainid, SOURCE_CHAIN_SELECTOR, address(source_collManagement), TARGET_CHAIN_SELECTOR
        );

        weth.mint(depositor, 100 ether);
        link.mint(address(source_collManagement), 100 ether);
        usdc.mint(address(target_borrowManagement), 1_000_000 * 1e6);

        vm.startPrank(depositor);
        weth.approve(address(source_collManagement), type(uint256).max);
        link.approve(address(source_collManagement), type(uint256).max);
        vm.stopPrank();
    }

    function test_Full_Private_Borrow_And_Repay_Cycle() public {
        uint256 depositAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC

        // === 1. DEPOSIT PRIVATE COLLATERAL (Source) ===
        (bytes32 commitment, bytes32 nullifier, bytes memory depositProof) = proofHelper.generateDepositInputs();

        vm.startPrank(depositor);
        source_collManagement.depositPrivateCollateral(address(weth), depositAmount, commitment, depositProof);
        vm.stopPrank();

        // === 2. INITIATE PRIVATE BORROW (Source) & AUTHORIZE (CCIP to Target) ===
        bytes memory borrowProof = proofHelper.generateBorrowProof();
        vm.startPrank(depositor);
        source_collManagement.initiatePrivateBorrow(
            commitment, nullifier, recipient, borrowAmount, address(usdc), TARGET_CHAIN_SELECTOR, borrowProof
        );
        vm.stopPrank();

        // === 3. SIMULATE CCIP: Source -> Target (Borrow Authorization) ===
        (uint64 sentMessageDestChain, Client.Any2EVMMessage memory sentMessage) = router.getLastMessageSent();
        assertEq(sentMessageDestChain, TARGET_CHAIN_SELECTOR, "Borrow authorization sent to wrong chain");
        vm.startPrank(address(router));
        target_borrowManagement.ccipReceive(sentMessage);
        vm.stopPrank();

        // === 4. SIMULATE CCIP: Target -> Source (Borrow Confirmation) ===
        (uint64 destChainSelector, Client.Any2EVMMessage memory confirmationMessage) = router.getLastMessageSent();

        // Assert that the message is being sent to the correct destination (source chain)
        assertEq(destChainSelector, SOURCE_CHAIN_SELECTOR, "Confirmation message sent to wrong chain");

        vm.startPrank(address(router));
        source_collManagement.ccipReceive(confirmationMessage);
        vm.stopPrank();

        // === 5. VERIFY FINAL STATE ===
        assertEq(usdc.balanceOf(recipient), borrowAmount, "Recipient did not receive borrowed USDC");
        uint256 borrowedAmountAfter = source_collManagement.privateDebt(commitment, address(usdc));
        assertEq(borrowedAmountAfter, borrowAmount, "Source chain private debt incorrect");
        // Note: We need to inspect the private balance mapping in BorrowManagement
        // This requires making the mapping public or adding a getter. For now, we skip this assertion.

        // === 6. REPAY PRIVATE BORROW (Target) & INITIATE CCIP to Source ===
        vm.startPrank(recipient);
        usdc.approve(address(target_borrowManagement), borrowAmount);
        target_borrowManagement.repayApplyPrivate(commitment, borrowAmount);
        vm.stopPrank();

        // === 7. SIMULATE CCIP: Target -> Source (Repay Initial) ===
        (uint64 repayDestChain, Client.Any2EVMMessage memory repayMessage) = router.getLastMessageSent();
        assertEq(repayDestChain, SOURCE_CHAIN_SELECTOR, "Repay message sent to wrong chain");
        vm.startPrank(address(router));
        source_collManagement.ccipReceive(repayMessage);
        vm.stopPrank();

        // === 8. SIMULATE CCIP: Source -> Target (Repay Confirmation) ===
        (uint64 repayFinalDestChain, Client.Any2EVMMessage memory repayFinalMessage) = router.getLastMessageSent();
        assertEq(repayFinalDestChain, TARGET_CHAIN_SELECTOR, "Repay confirmation sent to wrong chain");
        vm.startPrank(address(router));
        target_borrowManagement.ccipReceive(repayFinalMessage);
        vm.stopPrank();

        // === 9. VERIFY FINAL STATE AFTER REPAY ===
        assertEq(usdc.balanceOf(recipient), 0, "Recipient USDC balance not zero after repay");
        uint256 borrowedAmountFinal = source_collManagement.privateDebt(commitment, address(usdc));
        assertEq(borrowedAmountFinal, 0, "Source chain private debt not cleared");
    }

    function _buildBorrowInfo(
        BorrowStatus status,
        address _depositor,
        address _recipient,
        address _collToken,
        address _borrowToken,
        uint256 _amount
    ) internal pure returns (CrossChainBorrowInfo memory) {
        return CrossChainBorrowInfo({
            recipientAddress: _recipient,
            collateralToken: _collToken,
            borrowToken: _borrowToken,
            amount: _amount,
            status: status,
            sourceChainId: 1, // Mock value for source chain
            targetChainId: 2, // Mock value for target chain
            targetChainSelector: 2, // Mock value for target chain
            commitmentHash: bytes32(0),
            depositor: _depositor,
            nullifierHash: bytes32(0),
            zkProof: "",
            merkleRoot: bytes32(0)
        });
    }

    function _buildMessage(uint64 sourceChainSelector, address sender, CrossChainBorrowInfo memory borrowInfo)
        internal
        view
        returns (Client.Any2EVMMessage memory)
    {
        return Client.Any2EVMMessage({
            messageId: bytes32(
                keccak256(abi.encode(borrowInfo.status, borrowInfo.depositor, borrowInfo.recipientAddress, block.timestamp))
            ),
            sourceChainSelector: sourceChainSelector,
            sender: abi.encode(sender),
            data: abi.encode(borrowInfo),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
    }
}
