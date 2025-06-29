# Cross-Chain Contract Deployment Guide

This document outlines the deployment process for the cross-chain lending protocol on the Sepolia (source) and Avalanche Fuji (target) testnets. It includes instructions for deploying the core lending contracts and an optional, modular ZK privacy layer.

## Deployed Contract Addresses

### Sepolia (Source Chain - Chain ID: 11155111)

*   **`CollManagement`**: [`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`](https://sepolia.etherscan.io/address/0xd4aa953485eF4f1A916e42b9350Ab510f0920465)
*   **`PrivacyProxy`**: [`0xB4b8b2ed36407eE96A42954308E023fA9eAe2437`](https://sepolia.etherscan.io/address/0xB4b8b2ed36407eE96A42954308E023fA9eAe2437)
*   **`mockCollateralWETH`**: [`0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`](https://sepolia.etherscan.io/address/0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764)

### Avalanche Fuji (Target Chain - Chain ID: 43113)

*   **`BorrowManagement`**: [`0x8828210BCdC39fB6A6cA01861970825F317F58d6`](https://testnet.snowtrace.io/address/0x8828210BCdC39fB6A6cA01861970825F317F58d6)
*   **`PrivacyPool`**: [`0x042e5B9A43a48f5574E0ee2DD3685CB741E82c96`](https://testnet.snowtrace.io/address/0x042e5B9A43a48f5574E0ee2DD3685CB741E82c96)
*   **`mockBorrowUSDC`**: [`0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1`](https://testnet.snowtrace.io/address/0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1)

---

## Deployment Steps

The deployment process is managed by scripts in `script/DeployContracts.s.sol`. Ensure your `.env` file has `PRIVATE_KEY`, `SEPOLIA_RPC_URL`, and `AVALANCHE_FUJI_RPC_URL` set.

### Step 1: Deploy Prerequisite Mock Tokens

This deploys the mock `WETH` and `USDC` tokens required for the protocol to function.

```bash
# Deploy mockCollateralWETH to Sepolia
forge script script/DeployContracts.s.sol:DeployPrepareContractForSourceChain --rpc-url sepolia --broadcast --sig "run(uint256)" -- 11155111 -vvv

# Deploy mockBorrowUSDC to Fuji
forge script script/DeployContracts.s.sol:DeployPrepareContractForTargetChain --rpc-url fuji --broadcast --sig "run(uint256)" -- 43113 -vvv
```

### Step 3: Deploy Core Contracts

Deploy `CollManagement` to Sepolia and `BorrowManagement` to Fuji. You will need the addresses of the prerequisite contracts deployed in the previous steps.

```bash
# Deploy CollManagement to Sepolia
# Params: <sourceChainID>, <sourceCollateralToken>, <sourceChainPrivacyPool>
forge script script/DeployContracts.s.sol:DeployCollManagementSender --rpc-url sepolia --broadcast --sig "run(uint256,address,address)" -- 11155111 <WETH_ADDRESS> <SEPOLIA_PRIVACY_POOL_ADDRESS> -vvv

# Deploy BorrowManagement to Fuji
# Params: <targetBlockChainID>, <sourceCollateralToken>, <targetBorrowUSDC>, <targetChainPrivacyPool>
forge script script/DeployContracts.s.sol:DeployBorrowManagementReceiver --rpc-url fuji --broadcast --sig "run(uint256,address,address,address)" -- 43113 <WETH_ADDRESS> <USDC_ADDRESS> <FUJI_PRIVACY_POOL_ADDRESS> -vvv
```

### Step 3: Deploying the ZK Privacy Module (Optional)

This step deploys the modular ZK privacy layer. This is only required if you want to enable private deposits and borrows.

**Prerequisites:**
1.  The `CollManagement` contract must already be deployed.
2.  The ZK verifier contracts must be generated. If they don't exist in `src/core/privacy/verifiers/`, run the following command from the `circuits` directory:
    ```bash
    bash ./build-zk.sh
    ```

**Deployment Command:**

```bash
# Deploy the PrivacyProxy and its verifiers
# Params: <collManagementAddress>, <chainID>
forge script script/DeployPrivacy.s.sol:DeployPrivacy --rpc-url sepolia --broadcast --sig "run(address,uint256)" -- <COLL_MGMT_ADDR> 11155111 -vvv
```

This will deploy `DepositVerifier`, `BorrowVerifier`, and the `PrivacyProxy` contract, linking it to the main `CollManagement` contract.

### Step 4: Configure Cross-Chain Communication

Link the deployed `CollManagement` and `BorrowManagement` contracts.

```bash
# Configure CollManagement on Sepolia
# Params: <collManagementAddress>, <borrowManagementAddress>, <mockCollateralWETH>, <targetChainID>
forge script script/DeployContracts.s.sol:SetRouterForStratoLendNetWorkForSource --rpc-url sepolia --broadcast --sig "run(address,address,address,uint256)" -- <COLL_MGMT_ADDR> <BORROW_MGMT_ADDR> <WETH_ADDRESS> 43113 -vvv

# Configure BorrowManagement on Fuji
# Params: <collManagementAddress>, <borrowManagementAddress>, <mockBorrowUSDC>, <sourceChainID>, <targetChainID>
forge script script/DeployContracts.s.sol:SetRouterForStratoLendNetWorkForTarget --rpc-url fuji --broadcast --sig "run(address,address,address,uint256,uint256)" -- <COLL_MGMT_ADDR> <BORROW_MGMT_ADDR> <USDC_ADDRESS> 11155111 43113 -vvv
```

---

## Post-Deployment Setup (Manual)

Before testing, you must:

1.  **Fund Contracts with LINK:** Transfer LINK tokens to the `CollManagement` contract on Sepolia and the `BorrowManagement` contract on Fuji. These are required to pay for CCIP fees.
2.  **Fund `BorrowManagement` with USDC:** Mint or transfer `mockBorrowUSDC` to the `BorrowManagement` contract on Fuji. This provides the liquidity for users to borrow.

---

## Contract Verification

If you need to re-verify the contracts, use the following commands. Ensure your `ETHERSCAN_API_KEY` is set as an environment variable for the Sepolia command.

**Sepolia (CollManagement):**
```bash
forge verify-contract --chain sepolia --verifier etherscan 0xd4aa953485eF4f1A916e42b9350Ab510f0920465 src/core/coll/CollManagement.sol:CollManagement --compiler-version 0.8.30 --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59 0x779877A7B0D9E8603169DdbD7836e478b4624789 0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764)
```

**Avalanche Fuji (BorrowManagement):**
```bash
forge verify-contract --chain fuji --verifier-url https://api.routescan.io/v2/network/testnet/evm/43113/etherscan 0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389 src/core/borrow/BorrowManagement.sol:BorrowManagement --compiler-version 0.8.30 --constructor-args $(cast abi-encode "constructor(address,address,address,address)" 0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1 0xF694E193200268f9a4868e4Aa017A0118C9a8177 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846 0x042e5B9A43a48f5574E0ee2DD3685CB741E82c96)
```

---

## How to Perform a Cross-Chain Transaction

### 1. Deposit Collateral (Sepolia)

A user deposits `mockCollateralWETH` into the `CollManagement` contract on Sepolia.

```bash
# Params: <collManagementAddress>, <mockCollateralWETH>, <collateralAmount>, <recipientOnTargetChain>
forge script script/DeployContracts.s.sol:DepositCollateral --rpc-url sepolia --broadcast --sig "run(address,address,uint256,address)" -- <COLL_MGMT_ADDR> <WETH_ADDRESS> <AMOUNT> <RECIPIENT_ADDR> -vvv
```

### 2. Borrow (Fuji)

The designated recipient from the deposit step can now borrow `mockBorrowUSDC` from the `BorrowManagement` contract on Fuji.

```bash
# This requires a separate user account with its own private key set in the environment
# (e.g., PRIVATE_KEY_RONDOMER_USER)
# Params: <borrowManagementAddress>, <borrowAmount>
forge script script/DeployContracts.s.sol:BorrowApply --rpc-url fuji --broadcast --sig "run(address,uint256)" -- <BORROW_MGMT_ADDR> <AMOUNT> -vvv
```

---

## ABI File Generation

To generate ABI files for frontend integration:

```bash
# CollManagement ABI (Sepolia)
jq '{chainID: 11155111, abi: .abi }' out/CollManagement.sol/CollManagement.json > script/abi/CollManagement_11155111.json

# BorrowManagement ABI (Fuji)
jq '{chainID: 43113, abi: .abi }' out/BorrowManagement.sol/BorrowManagement.json > script/abi/BorrowManagement_43113.json
```

---

## Frontend Integration Guide

This guide explains how to connect a frontend application to our deployed smart contracts. It's written for a developer using a library like Ethers.js or viem.

### High-Level Concept for Frontend

The key thing to understand is that this is a **cross-chain application**. The user performs actions on two different blockchains to complete one full loan cycle.

1.  **Deposit on Sepolia:** The user connects their wallet to the Sepolia network and deposits collateral (`WETH`). In this transaction, they specify which address on the Fuji network is allowed to borrow against this collateral.
2.  **Borrow on Fuji:** The user (or the designated address) connects their wallet to the Avalanche Fuji network to borrow funds (`USDC`).

The frontend application must guide the user through this two-network process, including prompting them to switch networks in their wallet at the appropriate time.

### Prerequisites

Before you start, make sure you have:

1.  **Contract ABIs**: The ABI (Application Binary Interface) JSON files are required to interact with the contracts. They are located in the top-level `/abis` directory:
    - `CollManagement` ABI: `/abis/CollManagement.json`
    - `BorrowManagement` ABI: `/abis/BorrowManagement.json`
2.  **Contract Addresses**: Get these from the "Deployed Contract Addresses" section.
3.  **Web3 Provider**: A connection to the user's wallet (e.g., MetaMask).

### User Flow 1: Depositing Collateral (on Sepolia)

This flow allows a user to deposit `WETH` as collateral on the Sepolia network.

**UX Note:** The UI for this flow should be active only when the user's wallet is connected to Sepolia (Chain ID: `11155111`). If they are on the wrong network, prompt them to switch.

**Step 1: Approve the `CollManagement` Contract**

Before depositing, the user must approve the `CollManagement` contract to transfer their `mockCollateralWETH` tokens. This is a standard ERC20 approval flow.

*   **Contract to call**: `mockCollateralWETH` (`0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`)
*   **Function**: `approve(spender, amount)`
*   **Parameters**:
    *   `spender` (address): The `CollManagement` contract address: `0xd4aa953485eF4f1A916e42b9350Ab510f0920465`.
    *   `amount` (uint256): The amount of WETH the user wishes to deposit (in wei).

**Step 2: Deposit Collateral**

Once the approval transaction is confirmed, call the `deposit` function on the `CollManagement` contract.

*   **Contract to call**: `CollManagement` (`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`)
*   **Function**: `deposit(collateralToken, collateralAmount, recipient)`
*   **Parameters**:
    *   `collateralToken` (address): The `mockCollateralWETH` address: `0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`.
    *   `collateralAmount` (uint256): The amount of WETH to deposit (in wei). Must be less than or equal to the approved amount.
    *   `recipient` (address): **Crucial parameter.** This is the address on the **Avalanche Fuji network** that will be authorized to borrow. It can be the same as the depositor's address or a different one.

### User Flow 2: Borrowing USDC (on Avalanche Fuji)

This flow allows the designated `recipient` to borrow `mockBorrowUSDC` on the Fuji network.

**UX Note:** The UI for this flow should be active only when the user's wallet is connected to Avalanche Fuji (Chain ID: `43113`). The connected wallet address must match the `recipient` address from the deposit step.

**Step 1: Apply to Borrow**

Call the `borrowApply` function on the `BorrowManagement` contract.

*   **Contract to call**: `BorrowManagement` (`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`)
*   **Function**: `borrowApply(borrowAmount)`
*   **Parameters**:
    *   `borrowAmount` (uint256): The amount of `mockBorrowUSDC` the user wants to borrow (in its decimal format). The contract will automatically check if this amount is within the user's credit limit based on their collateral.

### User Flow 3: Private Deposit via ZK (on Sepolia)

This flow allows a user to deposit `WETH` as collateral privately. It breaks the link between the user's deposit address and their future borrowing activity.

**High-Level Concept:**

The user's browser or wallet will perform the following steps off-chain before sending a transaction:
1.  **Generate Secrets:** Create two large random numbers: a `nullifier` and a `secret`.
2.  **Create Commitment:** Hash the secrets together to create a `commitment`. This is what gets stored on-chain. `commitment = hash(nullifier, secret)`.
3.  **Generate ZK Proof:** Use the project's circuits (`deposit.circom`) and a library like `snarkjs` to generate a ZK-SNARK. This proof mathematically proves that the user knows the `nullifier` and `secret` for a given `commitment` without revealing them.

**Prerequisites:**

*   **Contract ABI**: The ABI for the `PrivacyProxy` contract is located in the project's `out/` directory at: `out/core/privacy/PrivacyProxy.sol/PrivacyProxy.json`.

**UX Note:** The UI for this flow should be active only when the user's wallet is connected to Sepolia (Chain ID: `11155111`).

**Step 1: Approve the `PrivacyProxy` Contract**

Before depositing, the user must approve the `PrivacyProxy` contract to transfer their `mockCollateralWETH` tokens.

*   **Contract to call**: `mockCollateralWETH` (`0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`)
*   **Function**: `approve(spender, amount)`
*   **Parameters**:
    *   `spender` (address): The `PrivacyProxy` contract address: `0xB4b8b2ed36407eE96A42954308E023fA9eAe2437`.
    *   `amount` (uint256): The amount of WETH the user wishes to deposit (in wei).

**Step 2: Deposit with Commitment**

Once the approval is confirmed, call the `deposit` function on the `PrivacyProxy` contract.

*   **Contract to call**: `PrivacyProxy` (`0xB4b8b2ed36407eE96A42954308E023fA9eAe2437`)
*   **Function**: `deposit(token, amount, commitment)`
*   **Parameters**:
    *   `token` (address): The `mockCollateralWETH` address: `0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`.
    *   `amount` (uint256): The amount of WETH to deposit.
    *   `commitment` (uint256): The `commitment` hash generated off-chain.

**Note on ZK Proof Verification:** In the current implementation of `PrivacyProxy.sol`, the on-chain `verifyProof` call is commented out for simplicity. A full production frontend would need to generate the proof and pass it as an additional argument to the `deposit` function.
