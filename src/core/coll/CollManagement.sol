// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@std/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
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
    mapping(bytes32 => bool) public processedValidationMessageIds; // messageId => processed
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
            targetChainBorrowManager: address(0),
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
            status: BorrowStatus.INITIAL,
            sourceChainId: block.chainid,
            targetChainId: 0,
            commitmentHash: depositInfo.commitmentHash,
            depositor: msg.sender,
            nullifierHash: bytes32(0),
            zkProof: bytes(""),
            validationId: 0
        });
        console.log("[CollMan.depositCollateral] Sending CCIP. msg.sender (expected depositor):", msg.sender);
        console.log("[CollMan.depositCollateral] depositInfo.recipientAddress (expected recipient_by_depositor):", depositInfo.recipientAddress);
        console.log("[CollMan.depositCollateral] ccbi.depositor:", crossChainBorrowInfo.depositor);
        console.log("[CollMan.depositCollateral] ccbi.recipientAddress:", crossChainBorrowInfo.recipientAddress);
        // CCIP send message to the target chain
        _sendMessage(depositInfo.collateralToken, abi.encode(crossChainBorrowInfo), 250_000);
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
        address targetChainBorrowManager,
        uint64 targetChainSelector
    ) external onlyOwner {
        if (!supportCollInfo[collateralToken].isSupported) {
            revert UnsupportedCollToken(collateralToken);
        }

        supportCollInfo[collateralToken].targetChainBorrowManager = targetChainBorrowManager;
        // targetChainSelector fixed value for chainlink ccip
        supportCollInfo[collateralToken].targetChainSelector = targetChainSelector;
    }

    // Normal borrowApply confirm, which means the source chain confirms the borrow
    // TODO refactor params. the params mess up
    function borrowApplyConfirm(CrossChainBorrowInfo memory crossChainBorrowInfo) internal {
        // update the syncBorrowBalance

        // TODO check data format
        // crossChainBorrowInfo.targetChainId here refers to the chain where the borrow occurred and which sent this message.
        // crossChainBorrowInfo.sourceChainId here refers to this CollManagement contract's chain.
        TargetChainBorowInfo storage currentTargetBorrowInfo =
            crossBalances[crossChainBorrowInfo.depositor][crossChainBorrowInfo.targetChainId];

        // Ensure that the borrow token in the message matches what's configured for this user/target chain.
        // This implies that an initial setup (e.g., via depositCollateral) should have occurred to set the borrowToken.
        require(
            currentTargetBorrowInfo.borrowToken != address(0),
            "CollManagement: Target borrow info not initialized for this user/targetChain"
        );
        require(
            currentTargetBorrowInfo.borrowToken == crossChainBorrowInfo.borrowToken,
            "CollManagement: Borrow token mismatch"
        );

        uint256 newTotalBorrowAmount = currentTargetBorrowInfo.syncBorrowBalance + crossChainBorrowInfo.amount;
        currentTargetBorrowInfo.syncBorrowBalance = newTotalBorrowAmount;

        emit SyncBorrowBalanceUpdated(
            crossChainBorrowInfo.depositor,
            crossChainBorrowInfo.collateralToken, // This is from the CCIP message; ensure it's consistently populated.
            crossChainBorrowInfo.targetChainId,   // The chain where the borrow occurred.
            currentTargetBorrowInfo.borrowToken,  // The token that was borrowed.
            newTotalBorrowAmount
        );

        // Conditional acknowledgment/confirmation message sending:
        // Only send a message out if this CollManagement instance is confirming a request it received
        // (e.g., if the incoming status was BORROW_PENDING_TARGET).
        // If the incoming status was BORROW_CONFIRMED_SOURCE, this contract has just been informed of a successful borrow
        // on the target chain, and its role is to update local debt, not send another message back for this flow.
        if (crossChainBorrowInfo.status == BorrowStatus.BORROW_PENDING_TARGET) {
            // This block executes if CollManagement received a BORROW_PENDING_TARGET message,
            // meaning it needs to validate and then send a confirmation (BORROW_CONFIRMED_SOURCE) 
            // to the target chain specified in the incoming crossChainBorrowInfo.targetChainId.

            // TODO: Add collateral ratio check here before confirming.
            // if (!validcollateralRatio(...)) { 
            //     // Optionally send a REJECTED status message back or simply revert.
            //     revert NoStatisfyCollateralRatio(...);
            // }

            CrossChainBorrowInfo memory ackInfo = CrossChainBorrowInfo({
                recipientAddress: crossChainBorrowInfo.recipientAddress, // Propagate recipient
                collateralToken: crossChainBorrowInfo.collateralToken,   // Propagate collateral token
                borrowToken: crossChainBorrowInfo.borrowToken,           // Propagate borrow token (token to be borrowed on target)
                amount: crossChainBorrowInfo.amount,                     // Propagate amount
                status: BorrowStatus.BORROW_CONFIRMED_SOURCE,            // This contract confirms the borrow from source perspective
                sourceChainId: block.chainid,                            // This chain is the source of this confirmation message
                targetChainId: crossChainBorrowInfo.targetChainId,       // Send to the chain that will execute/finalize the borrow
                commitmentHash: crossChainBorrowInfo.commitmentHash,     // Propagate ZK info if present and relevant for target
                depositor: crossChainBorrowInfo.depositor,               // Propagate original depositor
                nullifierHash: crossChainBorrowInfo.nullifierHash,       // Propagate ZK info
                zkProof: crossChainBorrowInfo.zkProof,                    // Propagate ZK info
                validationId: 0 // This flow does not use the new validationId system
            });
            
            // CCIP send message to the target chain that is awaiting this confirmation.
            // The collateralToken is used to find routing info via supportCollInfo.
            _sendMessage(crossChainBorrowInfo.collateralToken, abi.encode(ackInfo), 30_000);
        }
        // If crossChainBorrowInfo.status was BORROW_CONFIRMED_SOURCE, no further CCIP message is sent from this function.
        // The debt has been recorded locally.
    }

    /////////////////////////////////////////////////////////////////////////////// CCIP  ///////////////////////////////////////////////////////////////////////////////
    function _sendMessage(address collateralToken, bytes memory data, uint256 gasForDestCall) internal returns (bytes32 messageId) {
        address receiver = supportCollInfo[collateralToken].targetChainBorrowManager;
        uint64 destinationChainSelector = supportCollInfo[collateralToken].targetChainSelector;
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0), // only send message without token transfer
            extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: gasForDestCall, allowOutOfOrderExecution: true})),
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
        console.log("CollManagement._ccipReceive: Decoded status enum int:");
        console.logUint(uint(status));

        // According to status: logic switch
        console.log("CollManagement._ccipReceive: Checking BORROW_CONFIRMED_SOURCE (3). Current status:");
        console.logUint(uint(status));
        if (status == BorrowStatus.BORROW_CONFIRMED_SOURCE) {
            console.log("CollManagement._ccipReceive: Handling BORROW_CONFIRMED_SOURCE.");
            borrowApplyConfirm(crossChainBorrowInfo);
        } else {
            console.log("CollManagement._ccipReceive: Not BORROW_CONFIRMED_SOURCE. Checking BORROW_PENDING_TARGET (2). Current status:");
            console.logUint(uint(status));
            if (status == BorrowStatus.BORROW_PENDING_TARGET) {
                console.log("CollManagement._ccipReceive: Handling BORROW_PENDING_TARGET.");
                borrowApplyConfirm(crossChainBorrowInfo);
            } else {
                console.log("CollManagement._ccipReceive: Not BORROW_PENDING_TARGET. Checking BORROW_CONFIRMED_TARGET (9). Current status:");
                console.logUint(uint(status));
                if (status == BorrowStatus.BORROW_CONFIRMED_TARGET) { // Explicitly handle BORROW_CONFIRMED_TARGET
                    console.log("CollManagement._ccipReceive: Handling BORROW_CONFIRMED_TARGET.");
                    borrowApplyConfirm(crossChainBorrowInfo);
                } else {
                    console.log("CollManagement._ccipReceive: Not BORROW_CONFIRMED_TARGET. Checking BORROW_VALIDATE_REQUEST_SOURCE (8). Current status:");
                    console.logUint(uint(status));
                    if (status == BorrowStatus.BORROW_VALIDATE_REQUEST_SOURCE) {
                        if (processedValidationMessageIds[message.messageId]) {
                            console.log("CollManagement._ccipReceive: Duplicate BORROW_VALIDATE_REQUEST_SOURCE messageId, skipping:");
                            console.logBytes32(message.messageId);
                            return; // Or emit an event and return
                        }
                        processedValidationMessageIds[message.messageId] = true;
            // Target chain is asking this Source chain to validate a potential borrow
            address user = crossChainBorrowInfo.depositor; // Assuming depositor is the user on source chain
            address collateralTokenToValidate = crossChainBorrowInfo.collateralToken;
            address borrowTokenToValidate = crossChainBorrowInfo.borrowToken;
            uint256 requestedAmount = crossChainBorrowInfo.amount;

            // TODO: Implement robust validation logic. For now, placeholder.
            // This should check collateral balance, health factor against the requestedAmount.
            bool isAllowed = _isBorrowAllowed(user, collateralTokenToValidate, borrowTokenToValidate, requestedAmount);

            BorrowStatus responseStatus = isAllowed ? BorrowStatus.BORROW_VALIDATE_APPROVED_TARGET : BorrowStatus.BORROW_VALIDATE_REJECTED_TARGET;

            CrossChainBorrowInfo memory responseInfo = CrossChainBorrowInfo({
                recipientAddress: crossChainBorrowInfo.recipientAddress, // Propagate from original request
                collateralToken: collateralTokenToValidate,
                borrowToken: borrowTokenToValidate,
                amount: requestedAmount,
                status: responseStatus,
                sourceChainId: block.chainid, // This (source) chain is sending the validation response
                targetChainId: crossChainBorrowInfo.sourceChainId, // The original requester (target chain)
                commitmentHash: crossChainBorrowInfo.commitmentHash, // Propagate if present
                depositor: user,
                nullifierHash: crossChainBorrowInfo.nullifierHash, // Propagate if present
                zkProof: crossChainBorrowInfo.zkProof, // Propagate if present
                validationId: crossChainBorrowInfo.validationId // Propagate validationId
            });

            console.log("CollManagement._ccipReceive: Gas before _sendMessage for BORROW_VALIDATE_REQUEST_SOURCE response:");
            console.logUint(gasleft());
            // Send the response message back to the target chain.
            // _sendMessage uses supportCollInfo[collateralTokenToValidate] to get routing info.
            // This assumes collateralTokenToValidate is the key to find the route back to the requesting target chain.
            _sendMessage(collateralTokenToValidate, abi.encode(responseInfo), 300_000);
                    } else {
                        console.log("CollManagement._ccipReceive: UNHANDLED STATUS! Status:");
                        console.logUint(uint(status));
                    }
                }
            }
        }
        // TODO: Add handling for other relevant statuses like REPAY_CONFIRMED_SOURCE etc.
    }

    /**
     * @dev Internal function to check if a user is allowed to borrow a certain amount.
     * @param _user The address of the user.
     * @param _collateralToken The collateral token address.
     * @param _borrowToken The borrow token address.
     * @param _requestedBorrowAmount The amount the user wants to borrow.
     * @return True if the borrow is allowed, false otherwise.
     */
    function _isBorrowAllowed(
        address _user,
        address _collateralToken,
        address _borrowToken, // This is the token the user wants to borrow
        uint256 _requestedBorrowAmount
    ) internal view returns (bool) {
        if (!supportCollInfo[_collateralToken].isSupported || supportCollInfo[_collateralToken].borrowToken != _borrowToken) {
            // Either collateral not supported, or the requested borrow token doesn't match the configured one for this collateral
            return false;
        }

        uint256 userCollateralBalance = collateralBalances[_user][_collateralToken];
        if (userCollateralBalance == 0) {
            return false; // No collateral
        }

        int256 collateralPrice = getLatestPrice(_collateralToken);
        int256 borrowPrice = getLatestPrice(_borrowToken);

        if (collateralPrice <= 0 || borrowPrice <= 0) {
            return false; // Invalid prices
        }

        uint256 totalCollateralValueUSD = (userCollateralBalance * uint256(collateralPrice)) / (10 ** IERC20Metadata(_collateralToken).decimals());

        uint256 currentTotalBorrowedValueUSD;
        uint256[] memory activeChains = userActiveChains[_user];

        for (uint i = 0; i < activeChains.length; i++) {
            uint256 chainId = activeChains[i];
            TargetChainBorowInfo storage borrowInfo = crossBalances[_user][chainId];
            // Only consider debt of the same token type we are validating against
            if (borrowInfo.borrowToken == _borrowToken && borrowInfo.syncBorrowBalance > 0) {
                // Assume borrowPrice is for _borrowToken, so we can sum syncBorrowBalance directly
                // and convert to USD value later, or convert each syncBorrowBalance to USD if prices differ per chain (not current model)
                currentTotalBorrowedValueUSD += (borrowInfo.syncBorrowBalance * uint256(borrowPrice)) / (10 ** IERC20Metadata(_borrowToken).decimals());
            }
        }

        uint256 requestedBorrowValueUSD = (_requestedBorrowAmount * uint256(borrowPrice)) / (10 ** IERC20Metadata(_borrowToken).decimals());
        uint256 prospectiveTotalBorrowedValueUSD = currentTotalBorrowedValueUSD + requestedBorrowValueUSD;

        if (prospectiveTotalBorrowedValueUSD == 0) {
            return true; // No debt, always allowed if there's collateral
        }

        uint256 requiredCollateralRatio = supportCollInfo[_collateralToken].collateralRatio; // e.g., 150 for 150%
        
        // Check: (totalCollateralValueUSD / prospectiveTotalBorrowedValueUSD) * 100 >= requiredCollateralRatio
        // Or: totalCollateralValueUSD * 100 >= prospectiveTotalBorrowedValueUSD * requiredCollateralRatio
        return totalCollateralValueUSD * 100 >= prospectiveTotalBorrowedValueUSD * requiredCollateralRatio;
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

    // For link gas usage
    function transferLinkToken(address to, uint256 amount) external onlyOwner {
        // Allow the owner to withdraw LINK tokens from the contract
        IERC20(linkToken).transfer(to, amount);
    }
}
