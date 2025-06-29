#!/bin/bash

# This script compiles the circuits, performs the trusted setup for Groth16, and generates the verifier contracts.

# Exit on error
set -e

# 1. Compile the circuits

echo "Compiling deposit.circom..."
circom deposit.circom --r1cs --wasm --sym -o .

echo "Compiling borrow.circom..."
circom borrow.circom --r1cs --wasm --sym -o .

# 2. Perform the Powers of Tau trusted setup (Phase 1)
# This is a generic setup and can be reused for many circuits.

echo "Starting Powers of Tau ceremony..."
snarkjs powersoftau new bn128 14 pot14_0000.ptau -v
snarkjs powersoftau contribute pot14_0000.ptau pot14_0001.ptau --name="First contribution" -v -e="some random text"
snarkjs powersoftau prepare phase2 pot14_0001.ptau pot14_final.ptau -v
echo "Powers of Tau ceremony complete."

# 3. Perform the circuit-specific trusted setup (Phase 2)

# For Deposit circuit
echo "Performing setup for deposit circuit..."
snarkjs groth16 setup deposit.r1cs pot14_final.ptau deposit_0000.zkey
snarkjs zkey contribute deposit_0000.zkey deposit_final.zkey --name="Deposit circuit contribution" -v -e="some more random text"
snarkjs zkey export verificationkey deposit_final.zkey deposit_verification_key.json

# For Borrow circuit
echo "Performing setup for borrow circuit..."
snarkjs groth16 setup borrow.r1cs pot14_final.ptau borrow_0000.zkey
snarkjs zkey contribute borrow_0000.zkey borrow_final.zkey --name="Borrow circuit contribution" -v -e="even more random text"
snarkjs zkey export verificationkey borrow_final.zkey borrow_verification_key.json

# 4. Generate the verifier contracts

echo "Generating verifier contracts..."
snarkjs zkey export solidityverifier deposit_final.zkey ../src/core/privacy/DepositVerifier.sol
snarkjs zkey export solidityverifier borrow_final.zkey ../src/core/privacy/BorrowVerifier.sol

# Clean up temporary files
rm pot14_0000.ptau pot14_0001.ptau deposit_0000.zkey borrow_0000.zkey

echo "ZK build process complete. Verifier contracts are in src/core/privacy/"
