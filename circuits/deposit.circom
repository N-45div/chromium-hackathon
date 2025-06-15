pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/mimcsponge.circom";

// Computes the Pedersen hash of a secret.
// The commitment is H(secret).
// This circuit is used to generate a proof that a user knows the secret to a given commitment.
template Deposit() {
    // Public input
    signal input commitment;

    // Private input
    signal input secret;

    // Hash the secret using MiMC sponge to generate the commitment.
    component hasher = MiMCSponge(1, 220, 1);
    hasher.ins[0] <== secret;
    hasher.k <== 0;

    // Constrain the public commitment to be equal to the output of the hash.
    commitment === hasher.outs[0];
}

component main { public [commitment] } = Deposit();