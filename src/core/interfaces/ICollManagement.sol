// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

struct DepositCollateralInfo {
    address collateralToken;
    uint256 amount;
    uint256 targetChainId;
    address borrowToken;
    address recipientAddress; // zero address means no specify
    bytes proofA;
    bytes32 commitmentHash;
}

struct CrossChainBorrowInfo {
    address recipientAddress; // zero address means no specify
    address collateralToken;
    address borrowToken;
    uint256 sourceChainId; // for refeence, if needed
    uint256 targetChainId; // for refeence, if needed
    bytes32 commitmentHash; // linking to the private balance/deposit
    bytes32 nullifierHash; //  for spend authorization, especially when Source confirms a borrow
    bytes zkProof;
}

// TODO, below how to integrate with privacy mode
struct TargetChainBorowInfo {
    address borrowToken;
    address recipientAddress; // zero address means no specify
    uint256 syncBorrowBalance;
}

struct SupportCollInfo {
    address collateralToken;
    uint256 collateralRatio;
    uint256 targetChainId;
    uint64 targetChainSelector; //  chainlink ChainSelector
    address targerChainBorrowManager;
    address borrowToken;
    bool isSupported;
}

interface ICollManagement {
    // just depositCollateral without selecting the target chain and the borrow token
    function depositCollateral(address collateralToken, uint256 amount) external;

    // depositCollateral by selecting the target chain and the borrow token, and specifying the address who can borrow
    function depositCollateral(DepositCollateralInfo memory depositInfo) external;

    function withdrawCollateral(address collateralToken, uint256 amount) external;

    function liquidateCollateral(address collateralToken, address user) external;

    // query the available borrow balance on the target chain for the specified borrow token
    function getAvaiableChainBorrowBalance(address user, uint8 targetChainId, address borrowToken)
        external
        view
        returns (uint256);
}
