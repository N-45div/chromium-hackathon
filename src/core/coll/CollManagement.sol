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
    mapping(address => SupportCollInfo) public supportCollInfo; // the config for collateral
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(uint256 => TargetChainBorowInfo)) private crossBalances; // user => targetChainId => target borrow info

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

    constructor(
        address _collateralToken,
        address _collateralTokenPriceFeed,
        address _borrowToken,
        address _borrowTokenPriceFeed,
        uint256 _collateral_ratio,
        uint256 _targetChainId,
        address _destionChainRounter,
        address _privacyPool
    ) Ownable(msg.sender) CCIPReceiver(_destionChainRounter) {
        // initialize the support collateral config
        SupportCollInfo memory info = SupportCollInfo({
            collateralToken: _collateralToken,
            collateralRatio: _collateral_ratio,
            targetChainId: _targetChainId,
            borrowToken: _borrowToken,
            isSupported: true
        });
        supportCollInfo[_collateralToken] = info;

        // initialize the realted price feeds for collateral and borrow token
        priceFeeds[_collateralToken] = AggregatorV3Interface(_collateralTokenPriceFeed);
        priceFeeds[_borrowToken] = AggregatorV3Interface(_borrowTokenPriceFeed);

        privacyPool = _privacyPool;
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

        emit CollateralDeposited(msg.sender, depositInfo.collateralToken, depositInfo.amount);

        // Implementation for depositing collateral with target chain selection
        // todo CCIP message for the target chain
        bytes memory extraArgs = "0x";
        _sendMessage(depositInfo, extraArgs);
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

    function getAvaiableChainBorrowBalance(address /*user*/, uint8 /*targetChainId*/, address /*borrowToken*/)
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

    // TODO, below function should called by the CCIP message, either confirm the borrow or the repay

    function confirmTargetChainStatus(CrossChainBorrowInfo memory crossChainBorrowInfo) external {
        /**
         * Chain's PrivacyPool needs to verify these (e.g., check if commitmentHash belongs to the original depositor, mark nullifierHash as spent for that commitment on the source side to prevent double-borrowing against the same source deposit).
         * The user's collateral balance on the Source Chain (crossBalances) is always tied to their address. The link between this address and the commitmentHash is established and managed within the Source Chain's PrivacyPool during the private deposit. This ensures liquidations on the source are always against the actual depositor's address, regardless of borrow privacy on the target.
         * This approach ensures that the PrivacyPool contracts on both chains are the arbiters of ZK state, while CollManagement and BorrowManagement handle the financial logic and CCIP communication, passing ZK identifiers as needed.
         *
         *
         */
        // TODO, confirm the borrow status
        // 1. check the collateral ratio
        // 2. update the syncBorrowBalance for the user
        // 3. return result.

        // todo, check the collateral ratio
    }

    // TODO, implement support different chains
    function userCollateralRatio(address user, address collateralToken, address borrowToken)
        external
        view
        returns (uint256)
    {
        int256 collateralPrice = getLatestPrice(collateralToken);
        int256 borrowPrice = getLatestPrice(borrowToken);
        // default support one target chain
        uint256 targetChain = supportCollInfo[collateralToken].targetChainId;
        // todo  1e10 the difference decimal between WETH and USDC (optimize)
        return uint256(collateralPrice) * collateralBalances[user][collateralToken] * 1e18
            / (uint256(borrowPrice) * crossBalances[user][targetChain].syncBorrowBalance * 1e10 * 1e10);
    }

    function _sendMessage(DepositCollateralInfo memory depositInfo, bytes memory /*extraBytes*/) internal {
        //<---mock--->,waiting for CCIP
        // todo can reference below code
        // Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
        //     receiver: abi.encode(destinationMinter),
        //     data: abi.encodeWithSignature("mintFrom(address,uint256)", msg.sender, 1),
        //     tokenAmounts: new Client.EVMTokenAmount[](0),
        //     extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 980_000})),
        //     feeToken: address(linkToken)
        // });

        // // Get the fee required to send the message
        // uint256 fees = router.getFee(destinationChainSelector, message);

        // if (fees > linkToken.balanceOf(address(this))) {
        //     revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);
        // }

        // bytes32 messageId;
        // // Send the message through the router and store the returned message ID
        // messageId = router.ccipSend(destinationChainSelector, message);

        // TODO confirm
        // sync borrow info across chains
        // borrowToken
        // recipientAddress: the address can be borrowed on the target chain
        // syncBorrowBalance: the borrowed on the target chain, First DepositCollateral will set it to 0

        crossBalances[msg.sender][depositInfo.targetChainId] = TargetChainBorowInfo({
            borrowToken: depositInfo.borrowToken,
            recipientAddress: depositInfo.recipientAddress,
            syncBorrowBalance: 0
        });

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

        // TODO plan to apply below data as the typical CCIP message
        // CCIP(crossChainBorrowInfo) borrowInitial

        emit CollateralDepositedWithEnableBorrow(
            msg.sender,
            depositInfo.commitmentHash,
            depositInfo.collateralToken,
            depositInfo.amount,
            depositInfo.borrowToken,
            depositInfo.targetChainId,
            supportCollInfo[depositInfo.collateralToken].collateralRatio
        );
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

    // below funciton aim for mock test, should delete when deploy to mainnet
    function setCrossBalances(address user, address borrowToken, uint256 targetChainId, uint256 borrowedBalance)
        public
    {
        crossBalances[user][targetChainId] = TargetChainBorowInfo({
            borrowToken: borrowToken,
            recipientAddress: address(0),
            syncBorrowBalance: borrowedBalance
        });
    }
}
