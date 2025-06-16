// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

enum BorrowStatus {
    NONE,
    INITIAL,
    BORROW_PENDING_TARGET,
    BORROW_CONFIRMED_SOURCE,
    BORROW_CONFIRMED_TARGET,
    REPAY_PENDING_TARGET,
    REPAY_CONFIRMED_SOURCE,
    REPAY_CONFIRMED_TARGET
}

struct CrossChainBorrowInfo {
    address recipientAddress; // zero address means no specify
    address collateralToken;
    address borrowToken;
    uint256 amount; // the borrow amount or repay amount
    BorrowStatus status; // the status of the borrow operation
    uint256 sourceChainId; // for refeence, if needed
    uint256 targetChainId; // for refeence, if needed
    bytes32 commitmentHash; // linking to the private balance/deposit
    address depositor; //
    bytes32 nullifierHash;
    //  for spend authorization, especially when Source confirms a borrow
    bytes zkProof;
}

import {TargetChainBorowInfo} from "src/core/interfaces/ICollManagement.sol";

using CrossChainBorrowLib for CrossChainBorrowInfo global;

library CrossChainBorrowLib {
    // add helper functions for CrossChainBorrowInfo if needed

    // TODO should adjust
    function checkModeAndStatus(CrossChainBorrowInfo memory self)
        internal
        pure
        returns (bool isPrivacyMode, BorrowStatus status)
    {
        // bool valid = (recipientAddress == address(0x0)) == (commitmentHash == bytes32(0)); TODO this expression? can apply?
        if (
            (self.recipientAddress == address(0x0) && self.commitmentHash == bytes32(0))
                || (self.recipientAddress != address(0x0) && self.commitmentHash != bytes32(0))
        ) {
            //  TODO add this error Data format error
            revert();
        }

        if (self.commitmentHash != bytes32(0)) {
            isPrivacyMode = true;
        } else {
            isPrivacyMode = false;
        }

        return (isPrivacyMode, self.status);
    }

    // add other need funcitons, such as privacy mode check, status check, etc.
}
