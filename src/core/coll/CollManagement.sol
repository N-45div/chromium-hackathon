// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";

import {ICollManagement, DepositInfo, UserCollateralInfo} from "src/core/interfaces/ICollManagement.sol";
import {IPrivacyPool} from "src/core/interfaces/IPrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

contract CollManagement is ICollManagement, CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    // Struct to store parameters for a supported target chain
    struct TargetChainParams {
        uint64 chainSelector;
        address borrowManagementContract;
    }

    // The collateral token contract address (e.g., WETH)
    address public immutable COLL_WETH;
    // The LINK token contract address for CCIP fees
    address private immutable linkToken;

    // Mapping from a collateral token to its supported target chain parameters.
    // For this version, we assume 1 collateral token maps to 1 target chain.
    mapping(address => TargetChainParams) public targetChainParams;
    mapping(address => address) public priceFeeds;

    // Mapping: user => collateral token => UserCollateralInfo (for public borrows)
    mapping(address => mapping(address => UserCollateralInfo)) public userCollateral;

    // Mapping: commitmentHash => UserCollateralInfo (for ZK private borrows)
    mapping(bytes32 => UserCollateralInfo) public privateUserCollateral;

    // PrivacyPool contract instance
    IPrivacyPool public privacyPool;

    // --- Events ---
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateralToken, uint256 amount);
    event BorrowRequestHandledOnSource(address indexed depositor, address indexed collateralToken, uint256 amount);
    event ZKBorrowRequestHandledOnSource(bytes32 indexed commitmentHash, address indexed recipientAddress, address borrowToken, uint256 amount);
    event ZKRepayPendingHandledOnSource(bytes32 indexed commitmentHash, address indexed repayer, address borrowToken, uint256 amount);
    event RepayCompletedOnSource(address indexed depositor, address indexed collateralToken, uint256 amount);

    // --- Errors ---
    error UnsupportedCollateralToken(address token);
    error ZeroAmount();
    error TargetChainNotSet();
    error InsufficientCollateral();
    error ActiveDebt();
    error NoCollateralFound();
    error PrivacyPoolNotSet();
    error AuthorizationFailed(bytes32 commitmentHash);
    error RepayMoreThanBorrowed(address depositor, address collateralToken, uint256 repayAmount, uint256 borrowedAmount);
    error RepayMoreThanBorrowedZK(bytes32 commitmentHash, address borrowToken, uint256 repayAmount, uint256 borrowedAmount);

    constructor(address _collateralToken, address _router, address _linkToken, address _privacyPoolAddress) CCIPReceiver(_router) Ownable(msg.sender) {
        COLL_WETH = _collateralToken;
        linkToken = _linkToken;
        if (_privacyPoolAddress == address(0)) revert PrivacyPoolNotSet();
        privacyPool = IPrivacyPool(_privacyPoolAddress);
    }

    function setPrivacyPool(address _privacyPoolAddress) external onlyOwner {
        if (_privacyPoolAddress == address(0)) revert PrivacyPoolNotSet();
        privacyPool = IPrivacyPool(_privacyPoolAddress);
    }

    function setCollateralToken(address _collateralToken, address _priceFeed) external onlyOwner {
        // COLL_WETH is immutable and set in the constructor.
        // This function should only be called if _collateralToken matches COLL_WETH,
        // or if the intention is to only set priceFeeds for the already configured COLL_WETH.
        // For safety, ensure we are setting the price feed for the configured COLL_WETH.
        if (_collateralToken != COLL_WETH) revert UnsupportedCollateralToken(_collateralToken);
        priceFeeds[_collateralToken] = _priceFeed;
    }

    function setTargetChainParams(
        address _collateralToken,
        uint64 _chainSelector,
        address _borrowManagementContract
    ) external onlyOwner {
        if (_collateralToken != COLL_WETH) revert UnsupportedCollateralToken(_collateralToken);
        targetChainParams[_collateralToken] = TargetChainParams({
            chainSelector: _chainSelector,
            borrowManagementContract: _borrowManagementContract
        });
    }

    /**
     * @notice Deposit collateral to be used for cross-chain borrowing.
     * @dev Sends a CCIP message to the target chain to notify it of the available collateral.
     * @param _collateralToken The address of the collateral token.
     * @param _amount The amount to deposit.
     * @param _recipient The recipient address on the target chain.
     */
    function depositCollateral(address _collateralToken, uint256 _amount, address _recipient) external {
        if (_collateralToken != COLL_WETH) revert UnsupportedCollateralToken(_collateralToken);
        if (_amount == 0) revert ZeroAmount();
        if (targetChainParams[_collateralToken].borrowManagementContract == address(0)) revert TargetChainNotSet();

        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), _amount);

        userCollateral[msg.sender][_collateralToken].totalDeposited += _amount;

        emit CollateralDeposited(msg.sender, _collateralToken, _amount);

        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: _recipient,
            collateralToken: _collateralToken,
            borrowToken: address(0),
            amount: _amount,
            status: BorrowStatus.INITIAL,
            sourceChainId: block.chainid,
            targetChainId: 0, // Target chain ID is not known here
            depositor: msg.sender,
            targetChainSelector: targetChainParams[_collateralToken].chainSelector,
            commitmentHash: bytes32(0),
            nullifierHash: bytes32(0),
            zkProof: bytes(""),
            merkleRoot: bytes32(0)
        });

        _sendMessage(_collateralToken, abi.encode(crossChainBorrowInfo), 200_000);
    }

    /**
     * @notice Withdraw collateral.
     * @param collateralToken The address of the collateral token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdrawCollateral(address collateralToken, uint256 amount) external {
        UserCollateralInfo storage uc = userCollateral[msg.sender][collateralToken];
        if (uc.totalDeposited < amount) revert InsufficientCollateral();
        if (uc.totalBorrowed > 0) revert ActiveDebt();

        uc.totalDeposited -= amount;
        IERC20(collateralToken).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, collateralToken, amount);
    }

    /**
     * @notice Handles incoming CCIP messages from other chains.
     * @dev This function is called by the CCIP router.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        CrossChainBorrowInfo memory ccbi = abi.decode(message.data, (CrossChainBorrowInfo));

        if (ccbi.status == BorrowStatus.BORROW_PENDING_TARGET) {
            _handleBorrowPending(ccbi);
        } else if (ccbi.status == BorrowStatus.REPAY_PENDING_TARGET) {
            _handleRepayPending(ccbi);
        }
        // Other statuses are ignored by this contract
    }

    /**
     * @notice Handles a borrow request from the target chain.
     * @dev Checks if the user has collateral, updates the borrowed amount, and sends a confirmation back.
     */
    function _handleBorrowPending(CrossChainBorrowInfo memory ccbi) internal {
        if (privacyPool == IPrivacyPool(address(0))) revert PrivacyPoolNotSet();

        CrossChainBorrowInfo memory responseCcbi;

        if (ccbi.commitmentHash != bytes32(0)) {
            // ZK Private Borrow Flow
            // Ensure collateral for ZK borrows is managed by PrivacyPool, not directly here with userCollateral
            // PrivacyPool.authorizeBorrow will verify the ZK aspects (proof, nullifier, commitment existence)
            // and ensure the commitment corresponds to sufficient collateral.

            // The `ccbi.depositor` in this case might be the PrivacyPool contract itself, or the original EOA
            // that interacted with PrivacyPool. `authorizeBorrow` uses the commitment to find the deposit.
            bool success = privacyPool.authorizeBorrow(
                ccbi.commitmentHash,
                ccbi.nullifierHash,
                ccbi.recipientAddress, // recipient on target chain
                ccbi.amount,           // borrowAmount
                ccbi.borrowToken,
                ccbi.targetChainSelector, // Selector for the target chain (BorrowManagement's chain)
                ccbi.zkProof
            );
            if (!success) revert AuthorizationFailed(ccbi.commitmentHash);

            // Track borrowed amount against the commitment
            // Note: UserCollateralInfo might need adjustment if ZK deposits aren't directly 'deposited' here
            // For now, assume PrivacyPool handles the collateral check, and we just track debt.
            privateUserCollateral[ccbi.commitmentHash].totalBorrowed += ccbi.amount;
            // We might also want to store ccbi.collateralToken with the commitment if not already implicitly known
            // privateUserCollateral[ccbi.commitmentHash].token = ccbi.collateralToken; // If UserCollateralInfo stores token

            emit ZKBorrowRequestHandledOnSource(ccbi.commitmentHash, ccbi.recipientAddress, ccbi.collateralToken, ccbi.amount);

            responseCcbi = CrossChainBorrowInfo({
                recipientAddress: ccbi.recipientAddress, // Propagate recipient
                collateralToken: ccbi.collateralToken,
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                status: BorrowStatus.BORROW_CONFIRMED_SOURCE,
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: ccbi.targetChainSelector, // Propagate selector
                commitmentHash: ccbi.commitmentHash, // IMPORTANT: Propagate for ZK flow
                depositor: ccbi.depositor, // Propagate original depositor/initiator if meaningful
                nullifierHash: ccbi.nullifierHash, // Propagate if needed by target, though likely not for confirmation
                zkProof: bytes(""), // Proof not needed for confirmation message
                merkleRoot: ccbi.merkleRoot // Propagate if needed
            });
        } else {
            // Public Borrow Flow (existing logic)
            bool isAllowed = userCollateral[ccbi.depositor][ccbi.collateralToken].totalDeposited > 0;
            if (!isAllowed) revert NoCollateralFound();

            userCollateral[ccbi.depositor][ccbi.collateralToken].totalBorrowed += ccbi.amount;

            emit BorrowRequestHandledOnSource(ccbi.depositor, ccbi.collateralToken, ccbi.amount);

            responseCcbi = CrossChainBorrowInfo({
                recipientAddress: ccbi.recipientAddress,
                collateralToken: ccbi.collateralToken,
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                status: BorrowStatus.BORROW_CONFIRMED_SOURCE,
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: ccbi.targetChainSelector, // Propagate selector
                commitmentHash: bytes32(0), // No commitment for public borrows
                depositor: ccbi.depositor,
                nullifierHash: bytes32(0),
                zkProof: bytes(""),
                merkleRoot: bytes32(0)
            });
        }

        _sendMessage(ccbi.collateralToken, abi.encode(responseCcbi), 100_000);
    }

    /**
     * @notice Handles a repay notification from the target chain.
     * @dev Decreases the user's borrowed amount and sends a confirmation back.
     */
    function _handleRepayPending(CrossChainBorrowInfo memory ccbi) internal {
        // User repays on BorrowManagement, BorrowManagement sends REPAY_PENDING_TARGET to CollManagement
        // CollManagement updates user's borrowed amount and sends REPAY_CONFIRMED_SOURCE back to BorrowManagement
        CrossChainBorrowInfo memory responseCcbi;

        if (ccbi.commitmentHash != bytes32(0)) {
            // ZK Private Repay
            UserCollateralInfo storage puc = privateUserCollateral[ccbi.commitmentHash];
            if (puc.totalBorrowed < ccbi.amount) {
                revert RepayMoreThanBorrowedZK(ccbi.commitmentHash, ccbi.borrowToken, ccbi.amount, puc.totalBorrowed);
            }
            puc.totalBorrowed -= ccbi.amount;

            responseCcbi = CrossChainBorrowInfo({
                recipientAddress: ccbi.recipientAddress, // This is the original recipient of the ZK borrow
                collateralToken: ccbi.borrowToken, // For repay, this is the token context
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                status: BorrowStatus.REPAY_CONFIRMED_SOURCE,
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: 0, // Not strictly needed for repay confirmation back to target
                commitmentHash: ccbi.commitmentHash, // Propagate commitment hash for ZK repay
                depositor: ccbi.depositor, // Original depositor/initiator
                nullifierHash: bytes32(0),
                zkProof: bytes(""),
                merkleRoot: ccbi.merkleRoot // Propagate from incoming ZK repay message
            });
            emit ZKRepayPendingHandledOnSource(ccbi.commitmentHash, ccbi.recipientAddress, ccbi.borrowToken, ccbi.amount);
        } else {
            // Public Repay
            UserCollateralInfo storage uc = userCollateral[ccbi.depositor][ccbi.collateralToken];
            if (uc.totalBorrowed < ccbi.amount) {
                // Ensure this error is defined or use a generic one
                revert RepayMoreThanBorrowed(ccbi.depositor, ccbi.collateralToken, ccbi.amount, uc.totalBorrowed);
            }
            uc.totalBorrowed -= ccbi.amount;
            emit RepayCompletedOnSource(ccbi.depositor, ccbi.collateralToken, ccbi.amount);

            responseCcbi = CrossChainBorrowInfo({
                recipientAddress: ccbi.recipientAddress,
                collateralToken: ccbi.collateralToken,
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                status: BorrowStatus.REPAY_CONFIRMED_SOURCE,
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: 0, // Not strictly needed for repay confirmation back to target
                commitmentHash: bytes32(0), // Public repay doesn't use commitment hash
                depositor: ccbi.depositor,
                nullifierHash: bytes32(0),
                zkProof: bytes(""),
                merkleRoot: bytes32(0)
            });
        }

        _sendMessage(ccbi.collateralToken, abi.encode(responseCcbi), 100_000);
    }

    /**
     * @notice Sends a CCIP message to the target chain.
     */
    function _sendMessage(address collateralToken, bytes memory data, uint256 gasForDestCall) internal returns (bytes32 messageId) {
        TargetChainParams storage params = targetChainParams[collateralToken];
        if (params.borrowManagementContract == address(0)) revert TargetChainNotSet();

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(params.borrowManagementContract),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: gasForDestCall, allowOutOfOrderExecution: true})
            ),
            feeToken: linkToken
        });

        IRouterClient router = IRouterClient(getRouter());
        uint256 fee = router.getFee(params.chainSelector, message);
        IERC20(linkToken).approve(address(router), fee);

        messageId = router.ccipSend(params.chainSelector, message);
    }

    /**
     * @notice Allows the owner to transfer LINK tokens out of the contract.
     * @dev Useful for managing CCIP fee tokens.
     */
    function transferLinkToken(address to, uint256 amount) external onlyOwner {
        IERC20(linkToken).transfer(to, amount);
    }
}
