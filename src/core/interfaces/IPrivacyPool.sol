// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPrivacyPool
 * @author Sektorial12
 * @notice Interface for the PrivacyPool contract, which manages ZK-based private deposits and borrow authorizations.
 */
interface IPrivacyPool {
    /**
     * @notice Emitted when a new private deposit is made.
     * @param commitment The hash (commitment) of the deposit note.
     * @param collateralToken The token used for collateral.
     * @param amount The amount of collateral deposited.
     * @param leafIndex The index of the new leaf in the Merkle tree.
     */
    event Deposit(bytes32 indexed commitment, address indexed collateralToken, uint256 amount, uint256 leafIndex);

    /**
     * @notice Emitted when a borrow is authorized for a private deposit.
     * @param nullifierHash The nullifier hash to prevent double-spending.
     * @param commitment The commitment being spent.
     * @param recipient The address authorized to borrow on the target chain.
     * @param amount The amount authorized to be borrowed.
     */
    event BorrowAuthorized(
        bytes32 indexed nullifierHash, bytes32 indexed commitment, address indexed recipient, uint256 amount
    );

    /**
     * @notice Accepts a private deposit, verifies the proof, and adds the commitment to a Merkle tree.
     * @dev This function should be called by the main CollManagement contract.
     * @param commitment The user's generated commitment, `hash(secret)`.
     * @param proof The ZK proof (Proof A) verifying the commitment's construction.
     * @param collateralToken The collateral asset being deposited.
     * @param amount The amount of the collateral asset.
     */
    function deposit(bytes32 commitment, bytes calldata proof, address collateralToken, uint256 amount) external;

    /**
     * @notice Authorizes a borrow against a private deposit by verifying a ZK proof and nullifying the commitment.
     * @dev This triggers a CCIP message to the target chain to enable the borrow.
     * @param commitment The commitment corresponding to the initial deposit.
     * @param nullifierHash The hash of the secret, used to prevent replay attacks.
     * @param recipient The address on the target chain that is authorized to receive the borrowed funds.
     * @param borrowAmount The amount of the borrowToken to be authorized.
     * @param borrowToken The token to be borrowed on the target chain.
     * @param targetChainSelector The CCIP destination chain selector for the borrow.
     * @param proof The ZK proof (Proof B) proving knowledge of the secret for the given commitment.
     */
    function authorizeBorrow(
        bytes32 commitment,
        bytes32 nullifierHash,
        address recipient,
        uint256 borrowAmount,
        address borrowToken,
        uint64 targetChainSelector, // CCIP Target Chain Selector
        bytes calldata proof
    ) external returns (bool success);
}
