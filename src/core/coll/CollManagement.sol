// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink-ccip/chains/evm/contracts/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {PriceFeedConsumer} from "src/chainlink/PriceFeedConsumer.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {
    ICollManagement,
    DepositCollateralInfo,
    TargetChainBorowInfo,
    SupportCollInfo,
    CrossChainBorrowInfo
} from "src/core/interfaces/ICollManagement.sol";

import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";

contract CollManagement is ICollManagement, CCIPReceiver, PriceFeedConsumer, Ownable {
    using SafeERC20 for IERC20;

    address private immutable privacyPool;
    address private immutable linkToken; //now use link pay for the fees
    mapping(address => SupportCollInfo) public supportCollInfo; // the config for collateral
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(uint256 => TargetChainBorowInfo)) public crossBalances; // user => targetChainId => target borrow info

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount);
    // This event includes two types: nomal/private deposit and deposit with enable borrow
    event CollateralDepositedWithEnableBorrow(
        address indexed user,
        bytes32 commitmentHash,
        address collateralToken,
        uint256 amount,
        address borrowToken,
        uint256 targetChainId,
        uint256 collateralRatio
    );
    event CollateralWithdrawn(address indexed user, address indexed collateralToken, uint256 amount);
    event SyncBorrowBalanceUpdated(
        address indexed user,
        address collateralToken,
        uint256 targetChainId,
        address borrowToken,
        uint256 syncBorrowBalance
    );

    //errors
    error UnsupportedCollToken(address collateralToken);
    error UnsupportedCollBorrowToken(address collateralToken, address borrowToken);
    error NotEnoughDeposit(address collateralToken, uint256 amount);
    error NotEnoughCollateral(address collateralToken, uint256 amount);
    // TODO how to show the data?
    error SyncBorrowRatioFail(address collateralToken, address borrowToken, uint256 borrowAmount);
    error NoStatisfyCollateralRatio(
        address collateralToken, uint256 amount, address borrowToken, uint256 borrowdBalance
    );

    // TODO optimize how to initialize CCIP related params
    constructor(
        address _collateralToken,
        address _collateralTokenPriceFeed,
        address _borrowToken,
        address _borrowTokenPriceFeed,
        uint256 _collateral_ratio,
        uint256 _targetChainId,
        address _rounter,
        address _privacyPool,
        address _linkToken
    ) Ownable(msg.sender) CCIPReceiver(_rounter) {
        // initialize the support collateral config
        SupportCollInfo memory info = SupportCollInfo({
            collateralToken: _collateralToken,
            collateralRatio: _collateral_ratio,
            targetChainId: _targetChainId,
            targerChainBorrowManager: address(0),
            borrowToken: _borrowToken,
            targetChainSelector: 0,
            isSupported: true
        });

        supportCollInfo[_collateralToken] = info;

        // initialize the realted price feeds for collateral and borrow token
        priceFeeds[_collateralToken] = AggregatorV3Interface(_collateralTokenPriceFeed);
        priceFeeds[_borrowToken] = AggregatorV3Interface(_borrowTokenPriceFeed);

        privacyPool = _privacyPool;
        linkToken = _linkToken;
    }

    // Just deposit collateral without specific borrow token in target chain
    // Supply the flexibility for user change the borrow token later
    function depositCollateral(address collateralToken, uint256 amount) external {
        if (amount <= 0) {
            revert NotEnoughDeposit(collateralToken, amount);
        }

        if (!supportCollInfo[collateralToken].isSupported) {
            revert UnsupportedCollToken(collateralToken);
        }

        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender][collateralToken] += amount;
    }

    // User deposits collateral with a specific borrow token, then CCIP message is sent to the target chain
    function depositCollateral(DepositCollateralInfo memory depositInfo) external {
        if (depositInfo.amount <= 0) {
            revert NotEnoughDeposit(depositInfo.collateralToken, depositInfo.amount);
        }

        if (
            !supportCollInfo[depositInfo.collateralToken].isSupported
                || supportCollInfo[depositInfo.collateralToken].borrowToken != depositInfo.borrowToken
        ) {
            revert UnsupportedCollBorrowToken(depositInfo.collateralToken, depositInfo.borrowToken);
        }

        if (depositInfo.recipientAddress == address(0)) {
            // TODO CHECK

            // PrivacyPool(privacyPool).deposit(
            //     depositInfo.commitmentHash, depositInfo.proofA, depositInfo.collateralToken, depositInfo.amount
            // );
        }

        IERC20(depositInfo.collateralToken).safeTransferFrom(msg.sender, address(this), depositInfo.amount);
        collateralBalances[msg.sender][depositInfo.collateralToken] += depositInfo.amount;
        crossBalances[msg.sender][depositInfo.targetChainId] = TargetChainBorowInfo({
            borrowToken: depositInfo.borrowToken,
            recipientAddress: depositInfo.recipientAddress,
            syncBorrowBalance: 0
        });

        emit CollateralDeposited(msg.sender, depositInfo.collateralToken, depositInfo.amount);

        // Pack the cross-chain borrow info to send to the target chain
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: depositInfo.recipientAddress,
            collateralToken: depositInfo.collateralToken,
            borrowToken: depositInfo.borrowToken,
            sourceChainId: block.chainid, // current chain id
            targetChainId: depositInfo.targetChainId,
            commitmentHash: depositInfo.commitmentHash,
            nullifierHash: 0, // should be set when the source chain confirms the borrow
            zkProof: depositInfo.proofA
        });
        // CCIP send message to the target chain
        _sendMessage(depositInfo.collateralToken, abi.encode(crossChainBorrowInfo));
    }

    function withdrawCollateral(address collateralToken, uint256 amount) external {
        if (!supportCollInfo[collateralToken].isSupported) {
            revert UnsupportedCollToken(collateralToken);
        }

        // Check if the user has enough collateral balance
        if (collateralBalances[msg.sender][collateralToken] < amount) {
            revert NotEnoughCollateral(collateralToken, amount);
        }

        // default support one target chain
        uint256 targetChain = supportCollInfo[collateralToken].targetChainId;

        uint256 syncBorrowBalance = crossBalances[msg.sender][targetChain].syncBorrowBalance;
        if (syncBorrowBalance > 0) {
            validcollateralRatio(
                collateralToken,
                collateralBalances[msg.sender][collateralToken] - amount,
                crossBalances[msg.sender][targetChain].borrowToken,
                syncBorrowBalance
            );
        }
        collateralBalances[msg.sender][collateralToken] -= amount;
        IERC20(collateralToken).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, collateralToken, amount);
    }

    // Below can be borrowed by third parties or AI
    function liquidateCollateral(address collateralToken, address user) external {
        // Check or not can be liquidated
        //  collateralToken's price * amount / borrowToken's price * borrowBalance > collateralRatio
        // BeyondCollateralRatio
        // TODO, the profit liquidator can get
    }

    function getAvaiableChainBorrowBalance(address, /*user*/ uint8, /*targetChainId*/ address /*borrowToken*/ )
        external
        view
        override
        returns (uint256)
    {
        // TODO, combine below data and priceFeed, calculate the available borrow balance
        // crossBalances[depositInfo.user][depositInfo.targetChainId];

        return 0;
    }

    // return the max market value can be withdraw for collateralToken or borrow for borrowToken
    function validcollateralRatio(address collateralToken, uint256 amount, address borrowToken, uint256 borrowedAmount)
        internal
        view
        returns (uint256)
    {
        int256 collateralPrice = getLatestPrice(collateralToken);

        int256 borrowPrice = getLatestPrice(borrowToken);

        uint256 COLLATERAL_RATIO = supportCollInfo[collateralToken].collateralRatio;

        if (
            ((uint256(collateralPrice) * amount * 1e18) / (uint256(borrowPrice) * borrowedAmount * 1e10 * 1e10))
                <= COLLATERAL_RATIO
        ) {
            revert NoStatisfyCollateralRatio(collateralToken, amount, borrowToken, borrowedAmount);
        }

        return uint256(collateralPrice) * amount * COLLATERAL_RATIO / (uint256(borrowPrice) * borrowedAmount);
    }

    /**
     * Below function responds to the borrowApply/repay(both also involved the privacy mode) from the target chain.
     *
     * Check process
     *
     * 1) check data formart (CrossChainBorrowInfo)
     * 2) check respond which type
     *  1) borrowApply 2) borrowApply(Provacy) 3) repay 4) repay(Privacy)
     *
     * 3) The logic for each type
     *   1. borrowApply: check whether or not  the user's collateral ratio is health, if valid, then update crossBalances[msg.sender][targetChain].syncBorrowBalance.
     * Then call borrowApprovedAndTransfer in target chain by CCIP message.
     * TODO considering add new BorrowStatus, which should shows the source's chain's confirmation status
     *   2. repay: same logic, alothough validate collateral ratio seems unnecessary, keep the logic consistent with borrowApply seems better.
     *   3. borrowApply(Provacy):
     *
     * As Sektorial12 mentioned(as below), which means the logic checking commitmentHash and their orginal depositor's address belongs to the PrivacyPool contract
     *
     * The user's collateral balance on the Source Chain (crossBalances) is always tied to their address. The link between this address and the commitmentHash is established
     * and managed within the Source Chain's PrivacyPool during the private deposit. This ensures liquidations on the source are always against the actual depositor's address, regardless of borrow privacy on the target.
     * https://github.com/N-45div/chromium-hackathon/issues/4#issuecomment-2966105941
     *
     *
     * So the withdrawCollateral and liquidateCollateral during the  privacy mode should check privacy borrow in target chain
     *
     *   4. repay(Privacy): TODO chekck
     *
     * 4) Define the communication rules for cross-chain borrowApply/repay for this function. (normal/privacy mode)
     *    borrowApply in target chain, update  BorrowStatus.BORROW_PENDING_SOURCE_CONFIRMATION.
     *          ==> curret funciton in source chain BorrowStatus.BORROW_CONFIRMED_SOURCE_CONFIRMATION.
     *          ==> borrowApprovedAndTransfer in target chain  BorrowStatus.BORROW_APPROVED
     *
     *   repay in target chain, update BorrowStatus.REPAY_PENDING_SOURCE_CONFIRMATION.
     *          ==> curret funciton in source chain BorrowStatus.REPAY_CONFIRMED_SOURCE_CONFIRMATION
     *          ==> repayConfirm in target chain  BorrowStatus.REPAY_CONFIRMED
     *
     *
     */
    function confirmTargetChainStatus(CrossChainBorrowInfo memory crossChainBorrowInfo) external {}

    // TODO, implement support different chains
    /// @notice Returns the real-time collateral ratio (scaled by 1e18) for a user.
    /// Formula:
    ///     (collateralPrice * collateralAmount) / (borrowPrice * borrowedAmount)
    /// All token amounts are normalised to 18 decimals to make the ratio comparable
    /// across assets with different ERC-20 decimals.
    function userCollateralRatio(address user, address collateralToken, address borrowToken)
        external
        view
        returns (uint256)
    {
        // 1. Fetch on-chain prices (8 decimals from Chainlink feeds)
        int256 collateralPrice = getLatestPrice(collateralToken); // 8 decimals
        int256 borrowPrice = getLatestPrice(borrowToken); // 8 decimals

        // 2. Resolve the *synced* borrow balance for the target chain that this
        //    collateralToken maps to (in the simplified hackathon design each
        //    collateral only supports one target chain).
        uint256 targetChain = supportCollInfo[collateralToken].targetChainId;
        uint256 borrowedAmount = crossBalances[user][targetChain].syncBorrowBalance;

        // Edge-case: if nothing has been borrowed yet, the ratio is infinite.
        if (borrowedAmount == 0) return type(uint256).max;

        uint256 collateralAmount = collateralBalances[user][collateralToken];

        // 3. Normalise token amounts to 18 decimals so price*amount math stays
        //    consistent regardless of ERC-20 decimals.
        uint8 collDec = IERC20Metadata(collateralToken).decimals();
        uint8 borrowDec = IERC20Metadata(borrowToken).decimals();

        // Normalize amounts to 18-decimals precision
        uint256 collateralNorm;
        if (collDec == 18) collateralNorm = collateralAmount;
        else if (collDec < 18) collateralNorm = collateralAmount * (10 ** uint256(18 - collDec));
        else collateralNorm = collateralAmount / (10 ** uint256(collDec - 18));

        uint256 borrowNorm;
        if (borrowDec == 18) borrowNorm = borrowedAmount;
        else if (borrowDec < 18) borrowNorm = borrowedAmount * (10 ** uint256(18 - borrowDec));
        else borrowNorm = borrowedAmount / (10 ** uint256(borrowDec - 18));

        // 4. Compute and return the ratio (scale = 1e18 for extra precision).
        //    Prices have 8 decimals, so we multiply numerator by 1e8 to balance.
        return (uint256(collateralPrice) * collateralNorm) * 1e18 / (uint256(borrowPrice) * borrowNorm);
    }

    function initTargetChainParamsForCCIP(
        address collateralToken,
        address targerChainBorrowManager,
        uint64 targetChainSelector
    ) external onlyOwner {
        if (!supportCollInfo[collateralToken].isSupported) {
            revert UnsupportedCollToken(collateralToken);
        }

        supportCollInfo[collateralToken].targerChainBorrowManager = targerChainBorrowManager;
        // targetChainSelector fixed value for chainlink ccip
        supportCollInfo[collateralToken].targetChainSelector = targetChainSelector;
    }

    // For now, we just support 1=>1 format, user deposit one collateralToken and can only borrow one borrowToken in target chain
    function _sendMessage(address collateralToken, bytes memory data) internal returns (bytes32 messageId) {
        address receiver = supportCollInfo[collateralToken].targerChainBorrowManager;
        uint64 destinationChainSelector = supportCollInfo[collateralToken].targetChainSelector;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0), // only send message without token transfer
            extraArgs: "",
            feeToken: linkToken
        });

        // Initialize a router client instance to interact with cross-chain router
        // CHECKING ........................
        IRouterClient router = IRouterClient(getRouter());
        // CHECKING ........................

        uint256 fee = IRouterClient(router).getFee(destinationChainSelector, message);
        IERC20(linkToken).approve(address(router), fee);

        messageId = IRouterClient(router).ccipSend(destinationChainSelector, message);

        // TODO based on messageId. emit or integrate with front-end AI
    }

    // When borrower borrows the token on the target chain, this function will be called By the CCIP message
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        DepositCollateralInfo memory depositInfo = abi.decode(message.data, (DepositCollateralInfo));

        // sync check the  COLLATERAL_RATIO for source chain
        // collateralToken's price * amount / borrowToken's price * borrowBalance > collateralRatio
        // return false? inform front-end AI. trigger the source chain: this user can't borrow the token
        // TODO decode the message
        // revert SyncBorrowRatioFail(depositInfo.collateralToken, depositInfo.borrowToken, depositInfo.amount);

        // update the user's syncBorrowBalance in source chain
        address depositUser = address(0x01); // todo, get the corrosponding deposit user

        crossBalances[depositUser][depositInfo.targetChainId] = TargetChainBorowInfo({
            borrowToken: depositInfo.borrowToken,
            recipientAddress: depositInfo.recipientAddress,
            syncBorrowBalance: 0 // should update
        });

        emit SyncBorrowBalanceUpdated(
            depositUser,
            depositInfo.collateralToken,
            depositInfo.targetChainId,
            depositInfo.borrowToken,
            0 // // should update
        );
    }
}
