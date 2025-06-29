# Eliza OS AI Agent Integration Plan

This document outlines the strategy and steps for developing and integrating an AI-powered agent using Eliza OS to manage liquidation and yield optimization for the CCMM protocol.

## 1. High-Level Objective

The primary goal is to replace the decommissioned custom Python agent with a production-grade Eliza OS agent. This agent will monitor the health of borrow positions on-chain and autonomously trigger liquidations when necessary to ensure protocol solvency.

## 2. Core Components

Based on the project's `progress.txt`, the standard `plugin-evm` is insufficient for our specific needs. We will develop two custom components:

1.  **`HealthFactorProvider`**: A custom data provider that connects to our deployed smart contracts and reads the health factor of individual user positions.
2.  **`LiquidateAction`**: A custom action that, when triggered, formats and executes a `liquidate` transaction on our `CollManagement.sol` contract.

## 3. Technology Stack

- **Runtime**: Eliza OS
- **Language**: TypeScript
- **Core Plugin**: `@elizaos/plugin-evm`
- **Testing**: Hardhat/Foundry for on-chain simulation, Vitest/Jest for off-chain agent logic.

## 4. Detailed Implementation Plan

### Step 4.1: Setup Eliza OS Project

- **Action:** Initialize a new TypeScript project.
- **Action:** Install `@elizaos/core`, `@elizaos/plugin-evm`, `ethers`, and other necessary dependencies.
- **Action:** Configure `tsconfig.json` and `package.json` for an ES Module project, referencing the lessons learned from the previous migration (`"type": "module"`, `"moduleResolution": "NodeNext"`).

### Step 4.2: Implement `HealthFactorProvider`

- **File:** `src/providers/HealthFactorProvider.ts`
- **Logic:**
    - It will extend the base `Provider` class from `@elizaos/core`.
    - It will require the `CollManagement` contract address and ABI during initialization.
    - It will expose a method, e.g., `getHealthFactor(userAddress: string)`, which uses an `ethers` contract instance to call the relevant view function on `CollManagement.sol` that returns a user's health factor.
    - It must handle data formatting to return a clean, usable number (e.g., a `BigNumber` or `float`).

### Step 4.3: Implement `LiquidateAction`

- **File:** `src/actions/LiquidateAction.ts`
- **Logic:**
    - It will extend the base `Action` class from `@elizaos/core`.
    - It will require the `CollManagement` contract address, ABI, and a configured `ethers` signer (wallet) during initialization.
    - It will expose a method, e.g., `liquidateUser(userAddress: string, debt: BigNumber)`, that builds and sends a transaction to the `liquidate` function on the `CollManagement.sol` contract.
    - It must include robust error handling for transaction failures (e.g., insufficient gas, reverted transactions).

### Step 4.4: Create the Agent Logic

- **File:** `src/agents/LiquidationAgent.ts`
- **Logic:**
    - This file will define the main agent loop.
    - The agent will periodically fetch a list of all active borrowers.
    - For each borrower, it will use the `HealthFactorProvider` to get their current health factor.
    - It will implement the core risk logic: `if (healthFactor < threshold) { ... }`.
    - If the threshold is breached, it will trigger the `LiquidateAction` to execute the on-chain liquidation.
    - It will implement the `static async start(runtime)` pattern required by Eliza OS services.

### Step 4.5: Configuration and Entrypoint

- **File:** `src/index.ts` (or `main.ts`)
- **Action:** Set up the Eliza OS runtime.
- **Action:** Instantiate and register the `plugin-evm`.
- **Action:** Instantiate and register our custom `HealthFactorProvider` and `LiquidateAction`.
- **Action:** Start the `LiquidationAgent`.
- **Action:** Manage environment variables securely (e.g., `PRIVATE_KEY`, `RPC_URL`, `CONTRACT_ADDRESS`).

## 5. Testing Strategy

1.  **Unit Tests:**
    - Test the `HealthFactorProvider`'s data parsing against mock return values.
    - Test the `LiquidateAction`'s transaction payload construction.
2.  **Integration Tests:**
    - Spin up a local Hardhat/Foundry node with our contracts deployed.
    - Run the full agent against this local node.
    - Create a test script that programmatically puts a user position into a state of under-collateralization.
    - **Verify:** The agent correctly identifies the unhealthy position and successfully calls the `liquidate` function on the local node.

## 6. Next Steps

1.  Create the new project directory and initialize the project.
2.  Begin implementation of the `HealthFactorProvider` as the first component.
