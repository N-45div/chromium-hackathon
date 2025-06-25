// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

enum BorrowStatus {
    NONE,
    INITIAL, // Collateral deposited, borrow available on target
    BORROW_PENDING_TARGET, // Target requests borrow validation from Source
    BORROW_CONFIRMED_SOURCE, // Source confirms borrow is valid
    BORROW_CONFIRMED_TARGET, // Target acknowledges confirmation, funds available
    REPAY_PENDING_TARGET, // Target requests repay validation from Source
    REPAY_CONFIRMED_SOURCE // Source confirms repay is valid

}

struct CrossChainBorrowInfo {
    address recipientAddress; // (Normal Mode) User address on target chain
    address collateralToken;
    address borrowToken;
    uint256 amount; // The borrow or repay amount
    BorrowStatus status; // The status of the cross-chain operation
    uint256 sourceChainId;
    uint256 targetChainId;
    uint64 targetChainSelector; // CCIP selector for the target chain
    bytes32 commitmentHash; // (Privacy Mode) Links to the private deposit
    address depositor; // (Normal Mode) User address on source chain
    bytes32 nullifierHash; // (Privacy Mode) Prevents double-spending
    bytes zkProof; // (Privacy Mode) Spend authorization proof
    bytes32 merkleRoot; // (Privacy Mode) Merkle root for ZK proofs on target chain
}

import {TargetChainBorrowInfo} from "src/core/interfaces/ICollManagement.sol";

using CrossChainBorrowLib for CrossChainBorrowInfo global;

error InvalidCrossChainMessageMode();

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
            revert InvalidCrossChainMessageMode();
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
