// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20 as OZERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {ICollManagement, DepositInfo, UserCollateralInfo} from "src/core/interfaces/ICollManagement.sol";
import {IPrivacyPool} from "src/core/interfaces/IPrivacyPool.sol";
import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";
import {CrossChainBorrowLib} from "src/core/CrossChainBorrowLib.sol";

interface IERC20withDecimals {
    function decimals() external view returns (uint8);
}

contract CollManagement is ICollManagement, CCIPReceiver, Ownable, AccessControl {
    using SafeERC20 for OZERC20;
    using CrossChainBorrowLib for CrossChainBorrowInfo;

    struct Collateral {
        address token;
        uint256 amount;
    }

    struct Debt {
        address token;
        uint256 amount;
    }

    // Struct to store parameters for a supported target chain
    struct TargetChainParams {
        uint64 chainSelector;
        address borrowManagementContract;
    }


    // Struct to store private deposit information
    struct PrivateDepositInfo {
        address collateralToken;
        uint256 amount;
    }

    address public immutable COLL_WETH;
    address private immutable linkToken;

    constructor(address _router, address _link, address _weth) CCIPReceiver(_router) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        linkToken = _link;
        COLL_WETH = _weth;
    }

    mapping(address => TargetChainParams) public targetChainParams;
    mapping(address => address) public priceFeeds;

    mapping(address => mapping(address => UserCollateralInfo)) public userCollateral;
    mapping(bytes32 => PrivateDepositInfo) public privateDeposits;

    mapping(address => mapping(address => uint256)) public userDebt;
    mapping(bytes32 => mapping(address => uint256)) public privateDebt;

    mapping(address => address[]) public userBorrowedTokens;
    mapping(address => mapping(address => bool)) private _hasDebtInToken;
    mapping(bytes32 => address[]) public commitmentBorrowedTokens;
    mapping(bytes32 => mapping(address => bool)) private _hasCommitmentDebtInToken;

    uint256 public liquidationThreshold = 150; // In percentage, e.g., 150 for 150%
    uint256 public liquidationBonus = 5; // In percentage, e.g., 5 for 5%

    mapping(address => address[]) public userDepositedCollaterals;
    mapping(address => mapping(address => bool)) private _hasDeposited;
    mapping(address => bytes32[]) public userCommitments;

    bytes32 public constant DEBT_ISSUER_ROLE = keccak256("DEBT_ISSUER_ROLE");
    IPrivacyPool public privacyPool;

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateralToken, uint256 amount);
    event BorrowRequestHandledOnSource(address indexed depositor, address indexed collateralToken, uint256 amount);
    event ZKBorrowRequestHandledOnSource(
        bytes32 indexed commitmentHash, address indexed recipientAddress, address borrowToken, uint256 amount
    );
    event ZKRepayPendingHandledOnSource(
        bytes32 indexed commitmentHash, address indexed repayer, address borrowToken, uint256 amount
    );
    event RepayCompletedOnSource(address indexed depositor, address indexed collateralToken, uint256 amount);
    event BorrowRequestFinalizedPrivate(bytes32 indexed commitmentHash, uint256 amount);
    event Liquidation(address indexed liquidator, address indexed user, address collateral, uint256 seizedAmount);

    error UnsupportedCollateralToken(address token);
    error ZeroAmount();
    error TargetChainNotSet();
    error NotEnoughLink(uint256 required, uint256 has);
    error InsufficientCollateral();
    error ActiveDebt();
    error NoCollateralFound();
    error PrivacyPoolNotSet();
    error AuthorizationFailed(bytes32 commitmentHash);
    error RepayMoreThanBorrowed(address depositor, address collateralToken, uint256 repayAmount, uint256 borrowedAmount);
    error RepayMoreThanBorrowedZK(
        bytes32 commitmentHash, address borrowToken, uint256 repayAmount, uint256 borrowedAmount
    );
    error PriceFeedNotSet(address token);
    error HealthFactorNotBelowThreshold();
    error NoDebtToRepay();
    error InsufficientFee();

    function setLiquidationThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 100, "Threshold must be > 100");
        liquidationThreshold = threshold;
    }

    function setLiquidationBonus(uint256 bonus) external onlyOwner {
        require(bonus < 100, "Bonus must be < 100");
        liquidationBonus = bonus;
    }

    function setPrivacyPool(address _privacyPoolAddress) external onlyOwner {
        if (_privacyPoolAddress == address(0)) revert PrivacyPoolNotSet();
        privacyPool = IPrivacyPool(_privacyPoolAddress);
    }

    function setPriceFeed(address _token, address _priceFeed) external onlyOwner {
        priceFeeds[_token] = _priceFeed;
    }

    function setTargetChainParams(address _collateralToken, uint64 _chainSelector, address _borrowManagementContract)
        external
        onlyOwner
    {
        targetChainParams[_collateralToken] =
            TargetChainParams({chainSelector: _chainSelector, borrowManagementContract: _borrowManagementContract});
    }

    /**
     * @notice Deposit collateral to be used for cross-chain borrowing.
     * @dev Sends a CCIP message to the target chain to notify it of the available collateral.
     * @param _collateralToken The address of the collateral token.
     * @param _amount The amount to deposit.
     * @param _recipient The recipient address on the target chain.
     */
    function depositCollateral(address _collateralToken, uint256 _amount, address _recipient) external payable {
        if (_collateralToken != COLL_WETH) revert UnsupportedCollateralToken(_collateralToken);
        if (_amount == 0) revert ZeroAmount();
        if (targetChainParams[_collateralToken].borrowManagementContract == address(0)) revert TargetChainNotSet();

        OZERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), _amount);

        userCollateral[msg.sender][_collateralToken].totalDeposited += _amount;

        if (!_hasDeposited[msg.sender][_collateralToken]) {
            _hasDeposited[msg.sender][_collateralToken] = true;
            userDepositedCollaterals[msg.sender].push(_collateralToken);
        }

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

        _sendMessagePayable(_collateralToken, abi.encode(crossChainBorrowInfo), 200_000);
    }

    /**
     * @notice Initiates a private (ZK) borrow by authorizing it with the PrivacyPool and sending a CCIP message.
     * @param _commitment The commitment hash for the private deposit.
     * @param _nullifierHash The nullifier hash to prevent double-spending.
     * @param _recipient The recipient address on the target chain.
     * @param _borrowAmount The amount to borrow.
     * @param _borrowToken The token to borrow.
     * @param _targetChainSelector The chain selector for the target chain.
     * @param _proof The ZK proof data.
     */
    function initiatePrivateBorrow(
        bytes32 _commitment,
        bytes32 _nullifierHash,
        address _recipient,
        uint256 _borrowAmount,
        address _borrowToken,
        uint64 _targetChainSelector,
        bytes calldata _proof
    ) external {
        // 1. Authorize the borrow with the PrivacyPool
        bool authorized = privacyPool.authorizeBorrow(
            _commitment, _nullifierHash, _recipient, _borrowAmount, _borrowToken, _targetChainSelector, _proof
        );
        if (!authorized) revert AuthorizationFailed(_commitment);

        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: _recipient,
            collateralToken: COLL_WETH,
            borrowToken: _borrowToken,
            amount: _borrowAmount,
            status: BorrowStatus.BORROW_PENDING_TARGET,
            sourceChainId: block.chainid,
            targetChainId: 0, // Target chain ID is not known here, but selector is sufficient
            targetChainSelector: _targetChainSelector,
            commitmentHash: _commitment,
            depositor: msg.sender,
            nullifierHash: _nullifierHash,
            zkProof: _proof,
            merkleRoot: privacyPool.getRoot()
        });

        _sendMessageFromContract(COLL_WETH, abi.encode(crossChainBorrowInfo), 200_000);
    }

    function depositPrivateCollateral(
        address _collateralToken,
        uint256 _amount,
        bytes32 _commitment,
        bytes calldata _proof
    ) external {
        if (_collateralToken != COLL_WETH) revert UnsupportedCollateralToken(_collateralToken);

        if (privacyPool == IPrivacyPool(address(0))) revert PrivacyPoolNotSet();
        privacyPool.deposit(_commitment, _proof, _collateralToken, _amount);

        privateDeposits[_commitment] = PrivateDepositInfo({collateralToken: _collateralToken, amount: _amount});

        emit CollateralDeposited(msg.sender, _collateralToken, _amount); // Note: msg.sender is the relayer
    }

    function withdrawCollateral(address collateralToken, uint256 amount) external {
        UserCollateralInfo storage uc = userCollateral[msg.sender][collateralToken];
        if (uc.totalDeposited < amount) revert InsufficientCollateral();

        address[] memory borrowedTokens = userBorrowedTokens[msg.sender];
        for (uint256 i = 0; i < borrowedTokens.length; i++) {
            if (userDebt[msg.sender][borrowedTokens[i]] > 0) {
                revert ActiveDebt();
            }
        }

        uc.totalDeposited -= amount;
        OZERC20(collateralToken).safeTransfer(msg.sender, amount);

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
        } else if (ccbi.status == BorrowStatus.BORROW_CONFIRMED_TARGET) {
            // This is the final confirmation from the target chain after disbursing funds.
            // We need to differentiate between public and private flows.
            if (ccbi.commitmentHash != bytes32(0)) {
                // PRIVATE FLOW: This is the first time we're recording the debt for this private borrow.
                if (privateDeposits[ccbi.commitmentHash].amount == 0) revert NoCollateralFound();

                privateDebt[ccbi.commitmentHash][ccbi.borrowToken] += ccbi.amount;

                emit BorrowRequestFinalizedPrivate(ccbi.commitmentHash, ccbi.amount);
            } else {
                if (userCollateral[ccbi.depositor][ccbi.collateralToken].totalDeposited == 0) {
                    revert NoCollateralFound();
                }

                userDebt[ccbi.depositor][ccbi.borrowToken] += ccbi.amount;

                if (!_hasDebtInToken[ccbi.depositor][ccbi.borrowToken]) {
                    _hasDebtInToken[ccbi.depositor][ccbi.borrowToken] = true;
                    userBorrowedTokens[ccbi.depositor].push(ccbi.borrowToken);
                }
                emit BorrowRequestHandledOnSource(ccbi.depositor, ccbi.collateralToken, ccbi.amount);
            }
        } else if (ccbi.status == BorrowStatus.REPAY_PENDING_TARGET) {
            _handleRepayPending(ccbi);
        }
    }

    /**
     * @notice Handles a borrow request from the target chain.
     * @dev Checks if the user has collateral, updates the borrowed amount, and sends a confirmation back.
     */
    function _handleBorrowPending(CrossChainBorrowInfo memory ccbi) internal {
        if (privacyPool == IPrivacyPool(address(0))) revert PrivacyPoolNotSet();

        CrossChainBorrowInfo memory responseCcbi;

        if (ccbi.commitmentHash != bytes32(0)) {
            privateDebt[ccbi.commitmentHash][ccbi.borrowToken] += ccbi.amount;
            if (!_hasCommitmentDebtInToken[ccbi.commitmentHash][ccbi.borrowToken]) {
                _hasCommitmentDebtInToken[ccbi.commitmentHash][ccbi.borrowToken] = true;
                commitmentBorrowedTokens[ccbi.commitmentHash].push(ccbi.borrowToken);
            }

            emit ZKBorrowRequestHandledOnSource(
                ccbi.commitmentHash, ccbi.recipientAddress, ccbi.borrowToken, ccbi.amount
            );

            responseCcbi = CrossChainBorrowInfo({
                status: BorrowStatus.BORROW_CONFIRMED_SOURCE,
                depositor: ccbi.depositor,
                recipientAddress: ccbi.recipientAddress,
                collateralToken: ccbi.collateralToken,
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                commitmentHash: ccbi.commitmentHash,
                nullifierHash: ccbi.nullifierHash,
                zkProof: ccbi.zkProof,
                merkleRoot: ccbi.merkleRoot,
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: ccbi.targetChainSelector
            });
        } else {
            if (userCollateral[ccbi.depositor][ccbi.collateralToken].totalDeposited == 0) revert NoCollateralFound();

            userDebt[ccbi.depositor][ccbi.borrowToken] += ccbi.amount;

            if (!_hasDebtInToken[ccbi.depositor][ccbi.borrowToken]) {
                _hasDebtInToken[ccbi.depositor][ccbi.borrowToken] = true;
                userBorrowedTokens[ccbi.depositor].push(ccbi.borrowToken);
            }

            emit BorrowRequestHandledOnSource(ccbi.depositor, ccbi.collateralToken, ccbi.amount);

            responseCcbi = CrossChainBorrowInfo({
                status: BorrowStatus.BORROW_CONFIRMED_SOURCE,
                depositor: ccbi.depositor,
                recipientAddress: ccbi.recipientAddress,
                collateralToken: ccbi.collateralToken,
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                commitmentHash: bytes32(0),
                nullifierHash: bytes32(0),
                zkProof: bytes(""),
                merkleRoot: bytes32(0),
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: ccbi.targetChainSelector
            });
        }

        _sendMessageFromContract(ccbi.collateralToken, abi.encode(responseCcbi), 100_000);
    }

    /**
     * @notice Handles a repay notification from the target chain.
     * @dev Decreases the user's borrowed amount and sends a confirmation back.
     */
    function _handleRepayPending(CrossChainBorrowInfo memory ccbi) internal {
        CrossChainBorrowInfo memory responseCcbi;

        if (ccbi.commitmentHash != bytes32(0)) {
            uint256 currentDebt = privateDebt[ccbi.commitmentHash][ccbi.borrowToken];
            if (currentDebt < ccbi.amount) {
                revert RepayMoreThanBorrowedZK(ccbi.commitmentHash, ccbi.borrowToken, ccbi.amount, currentDebt);
            }
            privateDebt[ccbi.commitmentHash][ccbi.borrowToken] -= ccbi.amount;

            emit ZKRepayPendingHandledOnSource(
                ccbi.commitmentHash, ccbi.recipientAddress, ccbi.borrowToken, ccbi.amount
            );
        } else {
            uint256 currentDebt = userDebt[ccbi.depositor][ccbi.borrowToken];
            if (currentDebt < ccbi.amount) {
                revert RepayMoreThanBorrowed(ccbi.depositor, ccbi.borrowToken, ccbi.amount, currentDebt);
            }
            userDebt[ccbi.depositor][ccbi.borrowToken] -= ccbi.amount;

            emit RepayCompletedOnSource(ccbi.depositor, ccbi.collateralToken, ccbi.amount);

            responseCcbi = CrossChainBorrowInfo({
                status: BorrowStatus.REPAY_CONFIRMED_SOURCE,
                depositor: ccbi.depositor,
                recipientAddress: ccbi.recipientAddress,
                collateralToken: ccbi.collateralToken,
                borrowToken: ccbi.borrowToken,
                amount: ccbi.amount,
                commitmentHash: bytes32(0),
                nullifierHash: bytes32(0),
                zkProof: bytes(""),
                merkleRoot: bytes32(0),
                sourceChainId: block.chainid,
                targetChainId: ccbi.targetChainId,
                targetChainSelector: ccbi.targetChainSelector
            });
        }

        _sendMessageFromContract(ccbi.collateralToken, abi.encode(responseCcbi), 100_000);
    }

    /**
     * @notice Sends a CCIP message to the target chain.
     */
    function _sendMessageFromContract(address _collateralToken, bytes memory _data, uint32 _gasLimit) internal {
        TargetChainParams memory params = targetChainParams[_collateralToken];
        IRouterClient router = IRouterClient(getRouter());

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(params.borrowManagementContract),
            data: _data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: _gasLimit, allowOutOfOrderExecution: false})
            ),
            feeToken: linkToken
        });

        uint256 fee = router.getFee(params.chainSelector, message);
        if (fee > OZERC20(linkToken).balanceOf(address(this))) {
            revert NotEnoughLink(fee, OZERC20(linkToken).balanceOf(address(this)));
        }

        OZERC20(linkToken).approve(address(router), fee);
        router.ccipSend(params.chainSelector, message);
    }

    function _sendMessagePayable(address _collateralToken, bytes memory _data, uint32 _gasLimit) internal {
        IRouterClient router = IRouterClient(this.getRouter());

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(targetChainParams[_collateralToken].borrowManagementContract),
            data: _data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: _gasLimit, allowOutOfOrderExecution: false})
            ),
            feeToken: address(0) // Use native currency for fee
        });

        uint256 fee = router.getFee(targetChainParams[_collateralToken].chainSelector, message);
        if (msg.value < fee) revert InsufficientFee();

        // Send the message
        router.ccipSend{value: fee}(targetChainParams[_collateralToken].chainSelector, message);
    }

    /**
     * @notice Allows the owner to transfer LINK tokens out of the contract.
     * @dev Useful for managing CCIP fee tokens.
     */
    function transferLinkToken(address to, uint256 amount) external onlyOwner {
        OZERC20(linkToken).transfer(to, amount);
    }

    // --- Internal Helper Functions ---

    function _getAmountInUSD(address token, uint256 amount) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        if (address(priceFeed) == address(0)) {
            return 0;
        }

        int256 price;
        uint8 priceFeedDecimals;

        try priceFeed.latestRoundData() returns (uint80, int256 p, uint256, uint256, uint80) {
            price = p;
        } catch {
            return 0;
        }

        try priceFeed.decimals() returns (uint8 d) {
            priceFeedDecimals = d;
        } catch {
            return 0;
        }

        if (price <= 0) {
            return 0;
        }

        uint8 tokenDecimals = IERC20withDecimals(token).decimals();

        return (amount * uint256(price) * (10 ** (uint256(18) - priceFeedDecimals))) / (10 ** tokenDecimals);
    }

    // --- Liquidation Logic ---

    function getHealthFactor(address user) public view returns (uint256) {
        uint256 totalCollateralValueUSD = 0;
        uint256 totalDebtValueUSD = 0;

        address[] memory collateralTokens = userDepositedCollaterals[user];
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address collateralToken = collateralTokens[i];
            uint256 collateralAmount = userCollateral[user][collateralToken].totalDeposited;
            if (collateralAmount > 0) {
                totalCollateralValueUSD += _getAmountInUSD(collateralToken, collateralAmount);
            }
        }

        address[] memory debtTokens = userBorrowedTokens[user];
        for (uint256 i = 0; i < debtTokens.length; i++) {
            address debtToken = debtTokens[i];
            uint256 debtAmount = userDebt[user][debtToken];
            if (debtAmount > 0) {
                totalDebtValueUSD += _getAmountInUSD(debtToken, debtAmount);
            }
        }

        bytes32[] memory commitments = userCommitments[user];
        for (uint256 i = 0; i < commitments.length; i++) {
            bytes32 commitment = commitments[i];
            PrivateDepositInfo storage depositInfo = privateDeposits[commitment];
            if (depositInfo.amount > 0) {
                totalCollateralValueUSD += _getAmountInUSD(depositInfo.collateralToken, depositInfo.amount);
            }

            address[] memory commitmentTokens = commitmentBorrowedTokens[commitment];
            for (uint256 j = 0; j < commitmentTokens.length; j++) {
                address debtToken = commitmentTokens[j];
                uint256 debtAmount = privateDebt[commitment][debtToken];
                if (debtAmount > 0) {
                    totalDebtValueUSD += _getAmountInUSD(debtToken, debtAmount);
                }
            }
        }

        if (totalDebtValueUSD == 0) {
            return type(uint256).max; // No debt, health is infinite
        }

        return (totalCollateralValueUSD * 1e18) / totalDebtValueUSD;
    }

    function isLiquidatable(address user) public view returns (bool) {
        uint256 health = getHealthFactor(user);
        if (health == type(uint256).max) return false;

        uint256 requiredHealth = (liquidationThreshold * 1e18) / 100;
        return health < requiredHealth;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, CCIPReceiver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getPriceFeed(address token) public view returns (address) {
        return address(priceFeeds[token]);
    }


    function issueDebtForTest(address user, address debtToken, uint256 amount) external onlyRole(DEBT_ISSUER_ROLE) {
        userDebt[user][debtToken] = amount;
        if (!_hasDebtInToken[user][debtToken] && amount > 0) {
            _hasDebtInToken[user][debtToken] = true;
            userBorrowedTokens[user].push(debtToken);
        }
    }

    function liquidateCollateral(address user, address debtToken, uint256 repayAmount) external {
        if (!isLiquidatable(user)) revert HealthFactorNotBelowThreshold();

        uint256 userDebtForToken = userDebt[user][debtToken];
        if (userDebtForToken == 0) revert NoDebtToRepay();
        if (repayAmount > userDebtForToken) {
            revert RepayMoreThanBorrowed(user, debtToken, repayAmount, userDebtForToken);
        }

        OZERC20(debtToken).safeTransferFrom(msg.sender, address(this), repayAmount);

        uint256 repaidValueUSD = _getAmountInUSD(debtToken, repayAmount);

        uint256 collateralToSeizeValueUSD = (repaidValueUSD * (100 + liquidationBonus)) / 100;
        address collateralToken = COLL_WETH;
        UserCollateralInfo storage uc = userCollateral[user][collateralToken];

        uint256 collateralTokenPriceUSD = _getAmountInUSD(collateralToken, 1e18); // Price of 1 full collateral token
        uint256 collateralAmountToSeize = (collateralToSeizeValueUSD * 1e18) / collateralTokenPriceUSD;

        if (uc.totalDeposited < collateralAmountToSeize) revert InsufficientCollateral();

        userDebt[user][debtToken] -= repayAmount;
        uc.totalDeposited -= collateralAmountToSeize;

        OZERC20(collateralToken).transfer(msg.sender, collateralAmountToSeize);

        emit Liquidation(msg.sender, user, collateralToken, collateralAmountToSeize);
    }


}
