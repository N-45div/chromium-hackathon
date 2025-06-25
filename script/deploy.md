# Cross-Chain Contract Deployment Guide

This document outlines the deployment process for the cross-chain lending protocol on the Sepolia (source) and Avalanche Fuji (target) testnets.

## Deployed Contract Addresses

### Sepolia (Source Chain - Chain ID: 11155111)

*   **`CollManagement`**: [`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`](https://sepolia.etherscan.io/address/0xd4aa953485eF4f1A916e42b9350Ab510f0920465)
*   **`PrivacyPool`**: [`0xc2e58a9455Dfe1252826d1ef5284FAb097cE3E37`](https://sepolia.etherscan.io/address/0xc2e58a9455Dfe1252826d1ef5284FAb097cE3E37)
*   **`mockCollateralWETH`**: [`0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`](https://sepolia.etherscan.io/address/0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764)

### Avalanche Fuji (Target Chain - Chain ID: 43113)

*   **`BorrowManagement`**: [`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`](https://testnet.snowtrace.io/address/0xd4aa953485eF4f1A916e42b9350Ab510f0920465)
*   **`PrivacyPool`**: [`0x054a8677aEe0343939463ac06A4d2104D3687A786`](https://testnet.snowtrace.io/address/0x054a8677aEe0343939463ac06A4d2104D3687A786)
*   **`mockBorrowUSDC`**: [`0x5425890298a76a5fDE71C00E1554ebb843aB41d2`](https://testnet.snowtrace.io/address/0x5425890298a76a5fDE71C00E1554ebb843aB41d2)

---

## Deployment Steps

The deployment process is managed by scripts in `script/DeployContracts.s.sol`. Ensure your `.env` file has `PRIVATE_KEY`, `SEPOLIA_RPC_URL`, and `AVALANCHE_FUJI_RPC_URL` set.

### Step 1: Deploy Prerequisite Contracts on Sepolia

This deploys `mockCollateralWETH` and `PrivacyPool` on the source chain.

```bash
# Deploys mockCollateralWETH and PrivacyPool to Sepolia
forge script script/DeployContracts.s.sol:DeployPrepareContractForSourceChain --rpc-url sepolia --broadcast --sig "run(uint256)" -- 11155111 -vvv
```

### Step 2: Deploy Prerequisite Contracts on Fuji

This deploys `mockBorrowUSDC` and `PrivacyPool` on the target chain.

```bash
# Deploys mockBorrowUSDC and PrivacyPool to Fuji
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
