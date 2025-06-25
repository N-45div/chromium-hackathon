// SPDX-License-Identifier: MIT
// Inspired by Tornado Cash's MerkleTreeWithHistory.sol
pragma solidity 0.8.30;

/**
 * @title MerkleTree
 * @author Sektorial12 (Cascade)
 * @notice A library for managing an append-only Merkle tree.
 */
library MerkleTree {
    struct Tree {
        uint32 levels;
        bytes32[] filledSubtrees;
        bytes32[] roots;
        uint256 nextIndex;
    }

    /**
     * @notice Initializes the Merkle tree.
     * @param _levels The number of levels in the tree.
     */
    function initialize(Tree storage self, uint32 _levels) internal {
        require(_levels > 0, "Levels must be greater than 0");
        self.levels = _levels;
        self.filledSubtrees = new bytes32[](_levels);
        self.roots.push(0); // Initial root
    }

    /**
     * @notice Inserts a new leaf into the tree.
     * @param leaf The leaf to insert.
     * @return The index of the inserted leaf.
     */
    function insert(Tree storage self, bytes32 leaf) internal returns (uint256) {
        uint256 currentIndex = self.nextIndex;
        require(currentIndex < 2 ** self.levels, "Tree is full");

        bytes32 currentLevelHash = leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < self.levels; i++) {
            if (currentIndex % 2 == 0) {
                // is left node
                self.filledSubtrees[i] = currentLevelHash;
                left = currentLevelHash;
                right = 0; // Placeholder for sibling
            } else {
                // is right node
                left = self.filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = keccak256(abi.encodePacked(left, right));
            currentIndex /= 2;
        }

        self.roots.push(currentLevelHash);
        self.nextIndex++;
        return self.nextIndex - 1;
    }

    /**
     * @notice Returns the current root of the Merkle tree.
     */
    function root(Tree storage self) internal view returns (bytes32) {
        return self.roots[self.roots.length - 1];
    }

    /**
     * @notice Checks if a root is known (i.e., it was a historical root).
     * @param _root The root to check.
     * @return True if the root is known, false otherwise.
     */
    function isKnownRoot(Tree storage self, bytes32 _root) internal view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint256 i = self.roots.length;
        while (i > 0) {
            i--;
            if (self.roots[i] == _root) {
                return true;
            }
        }
        return false;
    }
}
