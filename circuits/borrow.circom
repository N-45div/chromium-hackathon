pragma circom 2.0.0;

// Required circomlib circuits
include "../node_modules/circomlib/circuits/smt/smtverifier.circom";
include "../node_modules/circomlib/circuits/mimcsponge.circom";
include "../node_modules/circomlib/circuits/pedersen.circom";
include "../node_modules/circomlib/circuits/comparators.circom";



// This circuit verifies a private borrow operation.
// It proves that the user knows a secret corresponding to a commitment in the Merkle tree,
// and generates a unique nullifier to prevent double-spending, without revealing the user's identity.
template Borrow(levels) {
    // --- Public Inputs ---
    signal input merkleRoot;      // The root of the Merkle tree of commitments.
    signal input nullifierHash;   // A unique hash to prevent double-spending: H(H(secret)).
    signal input recipient;       // The address of the recipient on the target chain.
    signal input borrowAmount;    // The amount to borrow.

    // --- Private Inputs ---
    signal input secret;                  // The user's private secret.
    signal input merklePathElements[levels]; // The path elements for the Merkle proof.
    signal input merklePathIndices[levels];  // The path indices (0 for left, 1 for right).

    // --- ZK Logic ---

    // 1. Calculate the user's commitment from their secret: commitment = H(secret).
    // We use MiMC sponge for SNARK-friendly hashing, which matches the SMTVerifier.
    component commitment_hasher = MiMCSponge(1, 220, 1);
    commitment_hasher.ins[0] <== secret;
    commitment_hasher.k <== 0;
    signal calculated_commitment <== commitment_hasher.outs[0];

    // 2. Verify that the calculated commitment exists in the Merkle tree.
    // 2. Verify that the calculated commitment exists in the Merkle tree using the SMTVerifier.
    // The SMTVerifier requires the old leaf value, the new leaf value, the root, the proof path, and whether the old leaf existed.
    // For a simple existence proof, we set oldLeafValue=0, newLeafValue=calculated_commitment, and must prove existence.
        component merkleProofChecker = SMTVerifier(levels);
    merkleProofChecker.enabled <== 1; // Enable the verifier
    merkleProofChecker.root <== merkleRoot; // The public root we are proving against
    merkleProofChecker.siblings <== merklePathElements; // The Merkle path elements
    merkleProofChecker.oldKey <== 0; // Not used in this simple inclusion proof
    merkleProofChecker.oldValue <== 0; // We are proving inclusion of a new leaf, so old value is 0
    merkleProofChecker.isOld0 <== 1; // We assert the old value was 0
    merkleProofChecker.key <== calculated_commitment; // The leaf we are proving is in the tree
    merkleProofChecker.value <== 1; // The value associated with the leaf (can be 1 for existence)
    merkleProofChecker.fnc <== 0; // Specify function 0 for an inclusion proof

    // 3. Calculate the nullifier hash from the commitment: nullifier = H(commitment).
    // This ensures that for each commitment, only one nullifier can be generated.
    component nullifier_hasher = MiMCSponge(1, 220, 1);
    nullifier_hasher.ins[0] <== calculated_commitment;
    nullifier_hasher.k <== 0;
    signal calculated_nullifier <== nullifier_hasher.outs[0];

    // 4. Constrain the calculated nullifier to match the public nullifierHash.
    // This proves the user correctly generated the nullifier for their commitment.
    nullifierHash === calculated_nullifier;

    // 5. Optional: Add application-specific constraints.
    // For example, ensure the borrowAmount is not zero.
    component isBorrowAmountZero = IsZero();
    isBorrowAmountZero.in <== borrowAmount;
    isBorrowAmountZero.out === 0; // Asserts borrowAmount is NOT zero.
}

// Instantiate the main component with a Merkle tree of 20 levels.
// IMPORTANT: This value must match the one used in the PrivacyPool.sol smart contract.
component main { public [merkleRoot, nullifierHash, recipient, borrowAmount] } = Borrow(20);