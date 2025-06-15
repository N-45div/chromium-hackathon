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

    function getAvaiableChainBorrowBalance(address user, uint8 targetChainId, address borrowToken)
        external
        view
        override
        returns (uint256)
    {
        // TODO, combine below data and priceFeed, calculate the available borrow balance
        // crossBalances[depositInfo.user][depositInfo.targetChainId];

        return 0;
    }

    // Reverts if ratio falls below required level.
    function validcollateralRatio(address collateralToken, uint256 amount, address borrowToken, uint256 borrowedAmount)
        internal
        view
        returns (uint256)
    {
        uint256 collateralPrice = _scalePrice(getLatestPrice(collateralToken));
        uint256 borrowPrice = _scalePrice(getLatestPrice(borrowToken));

        uint256 requiredRatio = supportCollInfo[collateralToken].collateralRatio;

        uint256 current = (collateralPrice * amount) * 1e18 / (borrowPrice * borrowedAmount);
        if (current <= requiredRatio) {
            revert NoStatisfyCollateralRatio(collateralToken, amount, borrowToken, borrowedAmount);
        }

        return (collateralPrice * amount * requiredRatio) / (borrowPrice * borrowedAmount);
    }

    // This function is triggered (via CCIP) by the target-chain BorrowManagement
    // contract once a borrow *or* repay action has been finalised on the target
    // chain. The payload tells us which position to update and the *new* synced
    // borrow balance after the action. We then re-validate the collateral ratio
    // on the source chain and persist the new balance.
    function confirmTargetChainStatus(CrossChainBorrowInfo memory crossChainBorrowInfo) external {
        
        require(crossChainBorrowInfo.zkProof.length >= 32, "Coll: invalid payload");
        uint256 newSyncBorrowBalance = abi.decode(crossChainBorrowInfo.zkProof, (uint256));

    
        bool isPrivacy = crossChainBorrowInfo.commitmentHash != bytes32(0);
        if (isPrivacy) {
            require(
                !PrivacyPool(privacyPool).nullifiers(crossChainBorrowInfo.nullifierHash),
                "Coll: nullifier already spent"
            );
        }

    
        uint256 userCollateral = collateralBalances[crossChainBorrowInfo.recipientAddress][
            crossChainBorrowInfo.collateralToken
        ];

        // Will revert,if ratio not satisfied
        validcollateralRatio(
            crossChainBorrowInfo.collateralToken,
            userCollateral,
            crossChainBorrowInfo.borrowToken,
            newSyncBorrowBalance
        );

        if (isPrivacy) {
            PrivacyPool(privacyPool).markNullifier(crossChainBorrowInfo.nullifierHash);
        }

        crossBalances[crossChainBorrowInfo.recipientAddress][crossChainBorrowInfo.targetChainId]
            .syncBorrowBalance = newSyncBorrowBalance;

        emit SyncBorrowBalanceUpdated(
            crossChainBorrowInfo.recipientAddress,
            crossChainBorrowInfo.collateralToken,
            crossChainBorrowInfo.targetChainId,
            crossChainBorrowInfo.borrowToken,
            newSyncBorrowBalance
        );
    }

    // Returns the live collateral ratio (1e18 scale).
    function userCollateralRatio(address user, address collateralToken, address borrowToken)
        external
        view
        returns (uint256)
    {
        uint256 collateralPrice = _scalePrice(getLatestPrice(collateralToken));
        uint256 borrowPrice = _scalePrice(getLatestPrice(borrowToken));

        uint256 targetChain = supportCollInfo[collateralToken].targetChainId;
        uint256 borrowedAmount = crossBalances[user][targetChain].syncBorrowBalance;

        if (borrowedAmount == 0) return type(uint256).max;

        uint256 collateralAmount = collateralBalances[user][collateralToken];
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

        return (collateralPrice * collateralNorm) * 1e18 / (borrowPrice * borrowNorm);
    }

    function _sendMessage(DepositCollateralInfo memory depositInfo, bytes memory extraBytes) internal {
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
    // Scale Chainlink price (8 decimals) to 18.
    function _scalePrice(int256 price) internal pure returns (uint256) {
        require(price > 0, "Invalid price");
        return uint256(price) * 1e10;
    }

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
