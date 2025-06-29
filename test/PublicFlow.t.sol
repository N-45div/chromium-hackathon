// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {CollManagement} from "src/core/coll/CollManagement.sol";
import {BorrowManagement} from "src/core/borrow/BorrowManagement.sol";
import {IPrivacyPool} from "src/core/interfaces/IPrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mock/MockERC20.sol";

// --- Mock Contracts ---

contract MockRouter is IRouterClient {
    function getFee(uint64, Client.EVM2AnyMessage memory) external pure returns (uint256) {
        return 1e18;
    }

    function ccipSend(uint64, Client.EVM2AnyMessage memory) external payable returns (bytes32) {
        return bytes32(keccak256("ccip_message_id"));
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
    function withdraw(bytes calldata, address) external {}

    function authorizeBorrow(bytes32, bytes32, address, uint256, address, uint64, bytes calldata)
        external
        pure
        returns (bool)
    {
        return true;
    }

    function getRoot() external view returns (bytes32) {
        return bytes32(0);
    }
}

// --- Test Contract ---

contract PublicFlowTest is Test {
    uint64 constant SOURCE_CHAIN_SELECTOR = 1;
    uint64 constant TARGET_CHAIN_SELECTOR = 2;

    CollManagement source_collManagement;
    BorrowManagement target_borrowManagement;

    MockERC20 weth;
    MockERC20 usdc;
    MockERC20 link;
    MockRouter router;
    MockPrivacyPool privacyPool;

    address depositor = makeAddr("depositor");
    address recipient = makeAddr("recipient");

    function setUp() public {
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        link = new MockERC20("ChainLink", "LINK", 18);
        router = new MockRouter();
        privacyPool = new MockPrivacyPool();

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
        vm.deal(depositor, 10 ether);
        link.mint(address(source_collManagement), 100 ether);
        usdc.mint(address(target_borrowManagement), 1_000_000 * 1e6);

        vm.startPrank(depositor);
        weth.approve(address(source_collManagement), type(uint256).max);
        link.approve(address(source_collManagement), type(uint256).max);
        vm.stopPrank();
    }

    function test_Full_Public_Borrow_And_Repay_Cycle() public {
        uint256 depositAmount = 1 ether;
        uint256 borrowAmount = 1000 * 1e6; // 1000 USDC

        // === 1. DEPOSIT COLLATERAL (Source) & INITIATE BORROW (CCIP to Target) ===
        vm.startPrank(depositor);
        source_collManagement.depositCollateral{value: 1 ether}(address(weth), depositAmount, recipient);
        vm.stopPrank();

        // === 2. SIMULATE CCIP: Source -> Target (Borrow Initial) ===
        Client.Any2EVMMessage memory initialMessage = _buildMessage(
            SOURCE_CHAIN_SELECTOR,
            address(source_collManagement),
            _buildBorrowInfo(BorrowStatus.INITIAL, depositor, recipient, address(weth), address(usdc), borrowAmount)
        );
        vm.startPrank(address(router));
        target_borrowManagement.ccipReceive(initialMessage);
        vm.stopPrank();

        // === 3. APPLY FOR BORROW (Target) & REQUEST CONFIRMATION (CCIP to Source) ===
        vm.startPrank(recipient);
        target_borrowManagement.borrowApply(borrowAmount);
        vm.stopPrank();

        // === 4. SIMULATE CCIP: Target -> Source (Borrow Confirmation Request) ===
        Client.Any2EVMMessage memory confirmationRequestMessage = _buildMessage(
            TARGET_CHAIN_SELECTOR,
            address(target_borrowManagement),
            _buildBorrowInfo(
                BorrowStatus.BORROW_PENDING_TARGET, depositor, recipient, address(weth), address(usdc), borrowAmount
            )
        );
        vm.startPrank(address(router));
        source_collManagement.ccipReceive(confirmationRequestMessage);
        vm.stopPrank();

        // === 5. SIMULATE CCIP: Source -> Target (Borrow Approval) & VERIFY BORROW ===
        Client.Any2EVMMessage memory approvalMessage = _buildMessage(
            SOURCE_CHAIN_SELECTOR,
            address(source_collManagement),
            _buildBorrowInfo(
                BorrowStatus.BORROW_CONFIRMED_SOURCE, depositor, recipient, address(weth), address(usdc), borrowAmount
            )
        );
        vm.startPrank(address(router));
        target_borrowManagement.ccipReceive(approvalMessage);
        vm.stopPrank();

        assertEq(usdc.balanceOf(recipient), borrowAmount, "Recipient did not receive USDC");
        uint256 borrowed = source_collManagement.userDebt(depositor, address(usdc));
        assertEq(borrowed, borrowAmount, "Debt not recorded on source chain");

        // === 6. REPAY LOAN (Target) & REQUEST DEBT CLEARANCE (CCIP to Source) ===
        vm.startPrank(recipient);
        usdc.approve(address(target_borrowManagement), borrowAmount);
        target_borrowManagement.repayApply(borrowAmount);
        vm.stopPrank();

        // === 7. SIMULATE CCIP: Target -> Source (Repay Confirmation) ===
        Client.Any2EVMMessage memory repayRequestMessage = _buildMessage(
            TARGET_CHAIN_SELECTOR,
            address(target_borrowManagement),
            _buildBorrowInfo(
                BorrowStatus.REPAY_PENDING_TARGET, depositor, recipient, address(weth), address(usdc), borrowAmount
            )
        );
        vm.startPrank(address(router));
        source_collManagement.ccipReceive(repayRequestMessage);
        vm.stopPrank();

        // === 8. SIMULATE CCIP: Source -> Target (Repay Approval) & VERIFY REPAY ===
        Client.Any2EVMMessage memory repayApprovalMessage = _buildMessage(
            SOURCE_CHAIN_SELECTOR,
            address(source_collManagement),
            _buildBorrowInfo(
                BorrowStatus.REPAY_CONFIRMED_SOURCE, depositor, recipient, address(weth), address(usdc), borrowAmount
            )
        );
        vm.startPrank(address(router));
        target_borrowManagement.ccipReceive(repayApprovalMessage);
        vm.stopPrank();

        uint256 borrowedAfterRepay = source_collManagement.userDebt(depositor, address(usdc));
        assertEq(borrowedAfterRepay, 0, "Debt not cleared on source chain after repay");
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
