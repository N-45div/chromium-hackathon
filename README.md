# StratoLend Network

## 🌟 Overview

StratoLend Network is an institutional-grade cross-chain lending protocol that enables users to deposit collateral on one blockchain and borrow assets on another. Built for the Chainlink Hackathon, our solution addresses the $50B+ fragmented liquidity problem in DeFi while providing professional-grade infrastructure for institutional capital management.

## 🎯 Problem Statement

### **Problem 1: Fragmented Liquidity Across Chains**
The crypto industry suffers from "fragmented liquidity" - one of the largest problems across web3. Even with Aave Portal, the absence of robust cross-chain connectivity constrains liquidity as DeFi protocols are critically reliant on liquidity.

### **Problem 2: Institutional DeFi Adoption Barriers**
The limited growth of institutional DeFi is often explained by the lack of KYC and AML capabilities, with several blue-chip DeFi protocols attempting to enable these without significant success. Retail apps are problematic for institutions as they are not designed to handle institutional volumes.

### **Problem 3: Security Vulnerabilities in Cross-Chain Operations**
Common security issues in DeFi include rug pulls and impermanent loss, with smart contract exploits leading to liquidity crises and regulatory breaches, compounded by cascading liquidations during market downturns.

### **Problem 4: Lack of Professional Capital Management Tools**
The continued rapid growth in digital asset operations emphasizes the importance of secure, scalable solutions that empower institutions to confidently navigate DeFi space. Current platforms lack professional-grade portfolio management.

## 💡 Our Solution

**StratoLend's Core Innovation**: Native cross-chain lending infrastructure that doesn't fragment liquidity across different protocols, purpose-built for institutional-scale operations with enhanced security, API integration, and professional tools.

## ✨ Key Features

### 🔗 Cross-Chain Lending and Borrowing
- Deposit collateral on source chain, borrow on target chain
- **Supported Chains**: Ethereum, BNB Chain, Avalanche
- **Collateral Tokens**: ETH, BNB
- **Borrowing Token**: USDC

### 🛡️ Enhanced Security Management
- Multi-signature approvals for large deposits
- Insurance partnerships for additional protection
- Whitelist controls for institutional security
- AI-driven monitoring for proactive threat detection

### 🤖 AI-Powered Capital Management
- AI-driven yield optimization algorithms
- Automated liquidation protection using ElizaOS agents
- Real-time portfolio rebalancing
- Multi-chain position tracking and analytics

### 🔒 Privacy Features
- Private borrowing activities across chains
- Zero-knowledge proof integration (roadmap)

## 🔧 Chainlink Integration

Our protocol leverages multiple Chainlink services for robust cross-chain operations:

- **[Chainlink CCIP](https://docs.chain.link/ccip/api-reference/evm/v1.6.0/)**: Secure cross-chain messaging between collateral and borrowing chains
- **[Chainlink Price Feeds](https://docs.chain.link/docs/using-chainlink-reference-contracts)**: Real-time asset pricing for accurate collateral valuation

**Chainlink CCIP** : 
 
1. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/core/coll/CollManagement.sol#L436

2. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/core/borrow/BorrowManagement.sol#L223

3. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/core/borrow/BorrowManagement.sol#L446

4. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/core/coll/CollManagement.sol#L264

5. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/core/coll/CollManagement.sol#L413

**Chainlink Price Feeds** : 

1. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/core/coll/CollManagement.sol#L540

2. https://github.com/N-45div/chromium-hackathon/blob/stratoLend/src/chainlink/PriceFeedConsumer.sol

**Solana CCIP Integration** : 

**SVM to EVM token transfer (BnM tokens from Solana devnet to Ethereum Sepolia)**

1. https://github.com/N-45div/chromium-hackathon/blob/solana/ccip-scripts/src/api/transfer.ts

## 🏗️ Architecture

### Smart Contracts

#### CollManagement Contract (Sepolia)
Manages user collateral and initiates cross-chain borrowing requests.

#### CollManagement Contract (Sepolia)
**Contract Address**: [0xd4aa953485eF4f1A916e42b9350Ab510f0920465](https://sepolia.etherscan.io/address/0xd4aa953485eF4f1A916e42b9350Ab510f0920465)

**Main Functions:**
- `depositCollateral(amount)`: Deposit collateral tokens
- `userCollateral(user)`: Query user's collateral balance

#### BorrowManagement Contract (Avalanche)
**Contract Address**: [0x8828210BCdC39fB6A6cA01861970825F317F58d6](https://testnet.snowtrace.io/address/0x8828210BCdC39fB6A6cA01861970825F317F58d6)

Executes borrowing on target chain and receives cross-chain loan requests.

**Main Functions:**
- `borrowApply(borrowAmount)`: Apply for loan with specified amount
- `ccipReceive(message)`: Receive cross-chain borrow requests
- `userBorrowed(user)`: Query user's borrowed amount

### Cross-Chain Data Structure

```solidity
struct BorrowInfo {
    address user;                // User address
    address token;               // Collateral/loan token
    uint256 amount;              // Amount
    uint64 sourceChainSelector;  // Source chain ID
    uint64 targetChainSelector;  // Target chain ID
}
```

## 🖥️ Frontend Integration

The frontend enables users to deposit WETH collateral and borrow USDC via three main components:

### Components

#### DepositForm (`deposit-form.tsx`)
- **Purpose**: Deposits WETH collateral on Sepolia via `CollManagement.sol`
- **Features**: WETH selection, amount input, Fuji recipient specification, transaction preview

#### BorrowInterface (`borrow-interface.tsx`)
- **Purpose**: Borrows USDC via `borrowApply` in `BorrowManagement.sol` implemented on Avalanche
- **Contract**: [BorrowManagement](https://testnet.snowtrace.io/address/0x8828210BCdC39fB6A6cA01861970825F317F58d6)
- **Features**: USDC borrowing, health factor display, liquidation price calculation

#### AvailableBorrowing (`available-borrowing.tsx`)
- **Purpose**: Displays borrow balance and collateral details
- **Features**: Real-time balance queries, collateral data fetching, available USDC calculation

### Technical Stack
- **Frontend**: React, TypeScript, ethers.js
- **Chains**: Sepolia (Collateral), Avalanche Fuji (Borrowing)
- **Tokens**: WETH (`0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`), USDC (`0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1`)

## 🚀 Getting Started

### Prerequisites
- Node.js (v16+)
- MetaMask or compatible Web3 wallet
- Testnet ETH for Sepolia and AVAX for Fuji

### Installation

**ElizaOS Agent Setup Guide** -> https://github.com/N-45div/chromium-hackathon/blob/stratoLend/eliza-agent/README.md

1. **Clone the repository**
   ```bash
   git clone https://github.com/N-45div/chromium-hackathon.git
   cd chromium-hackathon
   ```

2. **Install dependencies**
   ```bash
   cd frontend
   npm install
   ```

3. **Run the frontend**
   ```bash
   npm run dev
   ```

### Usage

#### Step 1: Approve the CollManagement Contract
**Contract to call**: mockCollateralWETH (`0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`)
- **Function**: `approve(spender, amount)`
- **Parameters**:
  - `spender (address)`: The CollManagement contract address: `0xd4aa953485eF4f1A916e42b9350Ab510f0920465`
  - `amount (uint256)`: The amount of WETH the user wishes to deposit (in wei)

#### Step 2: Deposit Collateral
**Contract to call**: CollManagement (`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`)
- **Function**: `deposit(collateralToken, collateralAmount, recipient)`
- **Parameters**:
  - `collateralToken (address)`: The mockCollateralWETH address: `0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`
  - `collateralAmount (uint256)`: The amount of WETH to deposit (in wei). Must be less than or equal to the approved amount
  - `recipient (address)`: **Crucial parameter** - This is the address on the Avalanche Fuji network that will be authorized to borrow. It can be the same as the depositor's address or a different one

#### Step 3: Switch to Avalanche Fuji
Switch your MetaMask to Avalanche Fuji testnet to proceed with borrowing.

#### Step 4: Borrow USDC
Use BorrowInterface to borrow USDC against your collateral via the `borrowApply` function.

#### Step 5: Monitor Position
View your borrowing status and health factor in real-time.

## 🔐 Security Features

- **Multi-signature controls** for large operations
- **AI-powered monitoring** using ElizaOS agents
- **Insurance partnerships** for additional protection
- **Robust liquidation management** system
- **Cross-chain security** through enhanced CCIP integration

## 🛣️ Roadmap

### Phase 1 (Current)
- ✅ Cross-chain lending MVP
- ✅ Chainlink integration
- ✅ Basic frontend interface
- ✅ AI liquidation protection

### Phase 2 (Q2 2025)
- 🔄 Multi-chain expansion (Polygon, Arbitrum)
- 🔄 Advanced yield optimization
- 🔄 Professional API suite
- 🔄 Insurance integration

### Phase 3 (Q3 2025)
- 🔄 Zero-knowledge privacy features
- 🔄 Institutional KYC/AML
- 🔄 Advanced risk management
- 🔄 Governance token launch

## 📊 Market Impact

- **Target Market**: $50B+ fragmented DeFi liquidity
- **Primary Users**: Institutional investors, hedge funds, high-net-worth individuals
- **Competitive Advantage**: First institutional-grade cross-chain lending solution

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built for the Chainlink Hackathon 2025**

*Empowering institutional DeFi through secure, cross-chain infrastructure.*
