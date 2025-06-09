// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// todo add chainlink price feed
// todo add CCIP
// TODO import issue for CCIP
import {IRouterClient} from "@chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {ICollManagement, DepositCollateralInfo, TargetChainBorowInfo} from "src/core/interfaces/ICollManagement.sol";

contract CollManagement is ICollManagement, CCIPReceiver {
    using SafeERC20 for IERC20;

    uint256 public immutable COLLATERAL_RATIO = 1_500_000_000_000_000_000; // collateral ratio, 150%

    mapping(address => bool) public supportCollToken;
    mapping(address => mapping(address => bool)) public supportCollBorrowToken;
    mapping(address => mapping(address => uint256)) public collateralBalances;
    mapping(address => mapping(uint256 => TargetChainBorowInfo)) private crossBalances; // user => targetChainId => target borrow info

    event CollateralDeposited(address indexed user, address collateralToken, uint256 amount);
    event CollateralDepositedWithEnableBorrow(
        address indexed user,
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
    // TODO, adjust below data
    error BeyondCollateralRatio(address user, uint256 UserCollateralRatio);
    // TODO how to show the data?
    error SyncBorrowRatioFail(address collateralToken, address borrowToken, uint256 borrowAmount);

    constructor() Ownable(msg.sender) {}

    // TODO chainlink price feed

    // Just just deposit collateral without specific borrow token in target chain
    // Supply the flexibility for user change the borrow token later
    function depositCollateral(address collateralToken, uint256 amount) external {
        if (amount <= 0) {
            revert NotEnoughDeposit(collateralToken, amount);
        }
        if (!supportCollToken[collateralToken]) {
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

        if (!supportedCollBorrowToken[depositInfo.collateralToken][depositInfo.borrowToken]) {
            revert UnsupportedCollBorrowToken(depositInfo.collateralToken, depositInfo.borrowToken);
        }

        if (depositInfo.recipientAddress = address(0)) {
            // TODO trigger  privacy mode
        }

        depositInfo.collateralToken.safeTransferFrom(msg.sender, address(this), depositInfo.amount);
        collateralBalances[msg.sender][depositInfo.collateralToken] += depositInfo.amount;

        emit CollateralDeposited(msg.sender, depositInfo.collateralToken, depositInfo.amount);

        // Implementation for depositing collateral with target chain selection
        // todo CCIP message for the target chain
        _sendMessage(depositInfo, extraArgs);
    }

    function withdrawCollateral(address collateralToken, uint256 amount) external {
        // Check if the user has enough collateral balance
        if (collateralBalances[msg.sender][collateralToken] < amount) {
            revert NotEnoughCollateral(collateralToken, amount);
        }

        // Check the avaiable collateral token can be withdrawn
        //  (collateralToken's price * amount  - borrowToken's price * borrowBalance) / collateralToken's price
        collateralBalances[msg.sender][collateralToken] -= amount;
        IERC20(collateralToken).safeTransfer(msg.sender, amount);
        // TODO after withdraw, check the borrow ratio
        // collateralToken's price * amount / borrowToken's price * borrowBalance > collateralRatio
    }

    // Below can be borrowed by third parties or AI
    function liquidateCollateral(address collateralToken, address user) external {
        // Check or not can be liquidated
        //  collateralToken's price * amount / borrowToken's price * borrowBalance > collateralRatio
        // BeyondCollateralRatio
        // TODO, the profit liquidator can get
    }

    function setSupportedCollBorrowToken(address collateralToken, address borrowToken) external onlyAdmin {
        supportCollToken[collateralToken] = true;
        supportedCollBorrowToken[collateralToken][borrowToken] = true;
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

    function _sendMessage(DepositCollateralInfo depositInfo, bytes memory extraBytes) internal {
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
        crossBalances[depositInfo.user][depositInfo.targetChainId] = TargetChainBorowInfo({
            borrowToken: depositInfo.borrowToken,
            amount: depositInfo.recipientAddress,
            syncBorrowBalance: 0
        });

        // CollateralDepositedWithEnableBorrow
        emit CollateralDepositedWithEnableBorrow(
            msg.sender,
            depositInfo.collateralToken,
            depositInfo.amount,
            depositInfo.borrowToken,
            depositInfo.targetChainId,
            COLLATERAL_RATIO
        );
    }

    // When borrower borrows the token on the target chain, this function will be called By the CCIP message
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // sync check the  COLLATERAL_RATIO for source chain
        // collateralToken's price * amount / borrowToken's price * borrowBalance > collateralRatio
        // return false? inform front-end AI. trigger the source chain: this user can't borrow the token
        // TODO decode the message
        emit SyncBorrowRatioFail(message.collateralToken, message.borrowToken, message.amount);

        // update the user's syncBorrowBalance in source chain
        crossBalances[depositInfo.user][depositInfo.targetChainId] = TargetChainBorowInfo({
            borrowToken: depositInfo.borrowToken,
            amount: depositInfo.recipientAddress,
            syncBorrowBalance: 0 // should update
        });

        emit SyncBorrowBalanceUpdated(
            depositInfo.user,
            depositInfo.collateralToken,
            depositInfo.targetChainId,
            depositInfo.borrowToken,
            0 // // should update
        );
    }
}
