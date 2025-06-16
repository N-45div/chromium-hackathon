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
    SupportCollInfo
} from "src/core/interfaces/ICollManagement.sol";

import {CrossChainBorrowInfo, BorrowStatus} from "src/core/CrossChainBorrowLib.sol";

import {PrivacyPool} from "src/core/privacy/PrivacyPool.sol";

contract CollManagement is ICollManagement, CCIPReceiver, PriceFeedConsumer, Ownable {
    using SafeERC20 for IERC20;

    address private immutable privacyPool;
    address private immutable linkToken; //now use link pay for the fees
    mapping(address => SupportCollInfo) public supportCollInfo; // the config for collateral
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(uint256 => TargetChainBorowInfo)) public crossBalances; // user => targetChainId => target borrow info
    address public supportedCollateralToken;
    mapping(address => uint256[]) public userActiveChains; // user => array of targetChainIds
    mapping(address => mapping(uint256 => bool)) private _hasActiveChain; // user => targetChainId => bool
    address[] public depositors;
    mapping(address => bool) private isDepositor;

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
        supportedCollateralToken = _collateralToken;
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

    // Deposit collateral without specific borrow token in target chain
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

        if (!isDepositor[msg.sender]) {
            isDepositor[msg.sender] = true;
            depositors.push(msg.sender);
        }
        crossBalances[msg.sender][depositInfo.targetChainId] = TargetChainBorowInfo({
            borrowToken: depositInfo.borrowToken,
            recipientAddress: depositInfo.recipientAddress,
            syncBorrowBalance: 0
        });

        if (!_hasActiveChain[msg.sender][depositInfo.targetChainId]) {
            _hasActiveChain[msg.sender][depositInfo.targetChainId] = true;
            userActiveChains[msg.sender].push(depositInfo.targetChainId);
        }

        emit CollateralDeposited(msg.sender, depositInfo.collateralToken, depositInfo.amount);

        // Pack the cross-chain borrow info to send to the target chain
        CrossChainBorrowInfo memory crossChainBorrowInfo = CrossChainBorrowInfo({
            recipientAddress: depositInfo.recipientAddress,
            collateralToken: depositInfo.collateralToken,
            borrowToken: depositInfo.borrowToken,
            amount: depositInfo.amount,
            status: BorrowStatus.NONE,
            sourceChainId: block.chainid, // current chain id
            targetChainId: depositInfo.targetChainId,
            commitmentHash: depositInfo.commitmentHash,
            depositor: msg.sender, // the user who deposits the collateral
            nullifierHash: 0, // should be set when the source chain confirms the borrow
            // HACKATHON NOTE: The zkProof bytes are custom-encoded for this hackathon.
            // The first 32 bytes represent `syncBorrowBalance`, and the rest is the actual ZK proof.
            // Any code using this proof MUST first slice the bytes accordingly before passing to a verifier.
            // Example: bytes memory actualProof = abi.encodePacked(crossChainBorrowInfo.zkProof[32:]);
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

    // TODO validcollateralRatio/maxWithdrawableCollateral/calCollateralRatio should test
    function validcollateralRatio(address collateralToken, uint256 amount, address borrowToken, uint256 borrowedAmount)
        internal
        view
        returns (bool isValid)
    {
        int256 collateralPrice = getLatestPrice(collateralToken);

        int256 borrowPrice = getLatestPrice(borrowToken);

        uint256 collateralRatio = supportCollInfo[collateralToken].collateralRatio;

        return true;
        // TODO, should check the collateral ratio
        // calCollateralRatio(collateralToken, amount, borrowToken, borrowedAmount) <= collateralRatio ? true : false;
    }

    function maxWithdrawableCollateral(
        address user,
        address collateralToken,
        address borrowToken,
        uint256 borrowedAmount
    ) public view returns (uint256) {
        if (!supportCollInfo[collateralToken].isSupported) {
            revert UnsupportedCollToken(collateralToken);
        }
        uint256 collateralRatio = supportCollInfo[collateralToken].collateralRatio;
        int256 collateralPrice = getLatestPrice(collateralToken);
        int256 borrowPrice = getLatestPrice(borrowToken);

        // Check the collateral ratio
        uint256 amount = collateralBalances[user][collateralToken];
        return uint256(collateralPrice) * amount * collateralRatio / (uint256(borrowPrice) * borrowedAmount);
    }

    function calCollateralRatio(address collateralToken, uint256 amount, address borrowToken, uint256 borrowedAmount)
        internal
        view
        returns (uint256 collateralRatio)
    {
        int256 collateralPrice = getLatestPrice(collateralToken);
        int256 borrowPrice = getLatestPrice(borrowToken);
        return (uint256(collateralPrice) * amount * 1e18) / (uint256(borrowPrice) * borrowedAmount * 1e10 * 1e10);
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

    // Normal borrowApply confirm, which means the source chain confirms the borrow
    // TODO refactor params. the params mess up
    function borrowApplyConfirm(CrossChainBorrowInfo memory crossChainBorrowInfo) internal {
        // update the syncBorrowBalance

        // TODO check data format
        TargetChainBorowInfo memory targetChainBorowInfo =
            crossBalances[crossChainBorrowInfo.depositor][crossChainBorrowInfo.targetChainId];

        require(
            targetChainBorowInfo.borrowToken == crossChainBorrowInfo.borrowToken
                && targetChainBorowInfo.recipientAddress == crossChainBorrowInfo.recipientAddress,
            "borrow token not match"
        );

        uint256 totalBorrowAmount = targetChainBorowInfo.syncBorrowBalance + crossChainBorrowInfo.amount;

        // TODO, should inform the source chain, not confirm the borrowApply
        if (
            !validcollateralRatio(
                crossChainBorrowInfo.collateralToken,
                collateralBalances[crossChainBorrowInfo.depositor][crossChainBorrowInfo.collateralToken],
                targetChainBorowInfo.borrowToken,
                totalBorrowAmount
            )
        ) {
            revert NoStatisfyCollateralRatio(
                crossChainBorrowInfo.collateralToken,
                collateralBalances[crossChainBorrowInfo.depositor][crossChainBorrowInfo.collateralToken],
                targetChainBorowInfo.borrowToken,
                totalBorrowAmount
            );
        }

        crossBalances[crossChainBorrowInfo.depositor][crossChainBorrowInfo.sourceChainId].syncBorrowBalance =
            totalBorrowAmount;

        emit SyncBorrowBalanceUpdated(
            crossChainBorrowInfo.depositor,
            crossChainBorrowInfo.collateralToken,
            crossChainBorrowInfo.sourceChainId,
            targetChainBorowInfo.borrowToken,
            totalBorrowAmount
        );

        // TODO below function should refactor
        CrossChainBorrowInfo memory ackInfo = CrossChainBorrowInfo({
            recipientAddress: crossChainBorrowInfo.recipientAddress,
            collateralToken: crossChainBorrowInfo.collateralToken,
            borrowToken: crossChainBorrowInfo.borrowToken,
            amount: crossChainBorrowInfo.amount,
            status: BorrowStatus.BORROW_CONFIRMED_SOURCE, // update the status
            sourceChainId: block.chainid, // current chain id
            targetChainId: crossChainBorrowInfo.sourceChainId,
            commitmentHash: "",
            depositor: crossChainBorrowInfo.depositor, // the user who deposits the collateral
            nullifierHash: 0, // should be set when the source chain confirms the borrow
            zkProof: ""
        });
        // CCIP send message to the target chain
        _sendMessage(crossChainBorrowInfo.collateralToken, abi.encode(ackInfo));
    }

    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////
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

    /**
     * Below function responds to the borrowApply/repay(both also involved the privacy mode) from the target chain.
     *
     * Check process
     *
     * 1) check data formart (CrossChainBorrowInfo)
     * 2) check respond which type
     *  1) borrowApply 2) borrowApply(Privacy) 3) repay 4) repay(Privacy)
     *
     * 3) The logic for each type
     *   1. borrowApply: check whether or not  the user's collateral ratio is health, if valid, then update crossBalances[msg.sender][targetChain].syncBorrowBalance.
     * Then call borrowApprovedAndTransfer in target chain by CCIP message.
     * TODO considering add new BorrowStatus, which should shows the source's chain's confirmation status
     *   2. repay: same logic, alothough validate collateral ratio seems unnecessary, keep the logic consistent with borrowApply seems better.
     *   3. borrowApply(Privacy):
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
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        CrossChainBorrowInfo memory crossChainBorrowInfo = abi.decode(message.data, (CrossChainBorrowInfo));

        // check data format
        (bool isPrivacyMode, BorrowStatus status) = crossChainBorrowInfo.checkModeAndStatus();

        // According to status: logic switch TOOD Add more related logic
        if (status == BorrowStatus.BORROW_PENDING_TARGET) {
            borrowApplyConfirm(crossChainBorrowInfo);
            // TODO below test just for roundTest
        }
    }
    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////

    function getDepositors() external view returns (address[] memory) {
        return depositors;
    }

    function isLiquidatable(address user) external view returns (bool) {
        uint256 userCollateralBalance = collateralBalances[user][supportedCollateralToken];
        if (userCollateralBalance == 0) {
            return false; // No collateral, nothing to liquidate
        }

        // Assuming price feed returns price with 8 decimals
        int256 collateralPrice = getLatestPrice(supportedCollateralToken);
        uint256 totalCollateralValue = (userCollateralBalance * uint256(collateralPrice)) / (10 ** 8);

        uint256 totalBorrowValue;
        uint256[] memory activeChains = userActiveChains[user];

        for (uint256 i = 0; i < activeChains.length; i++) {
            uint256 chainId = activeChains[i];
            TargetChainBorowInfo memory borrowInfo = crossBalances[user][chainId];
            if (borrowInfo.syncBorrowBalance > 0) {
                int256 borrowTokenPrice = getLatestPrice(borrowInfo.borrowToken);
                // Assuming price feed returns price with 8 decimals
                uint256 borrowValue = (borrowInfo.syncBorrowBalance * uint256(borrowTokenPrice)) / (10 ** 8);
                totalBorrowValue += borrowValue;
            }
        }

        if (totalBorrowValue == 0) {
            return false; // No debt, cannot be liquidated
        }

        uint256 requiredCollateralRatio = supportCollInfo[supportedCollateralToken].collateralRatio; // This is a percentage, e.g., 150

        // This checks if: (totalCollateralValue / totalBorrowValue) < (requiredCollateralRatio / 100)
        return totalCollateralValue * 100 < totalBorrowValue * requiredCollateralRatio;
    }
}
