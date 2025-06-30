## Frontend Integration with Eliza Liquidation Agent

The frontend enables WETH collateral deposits (public or private via ZK-SNARKs) and USDC borrowing via `DepositForm`, `BorrowInterface`, and `AvailableBorrowing`, interacting with `BorrowManagement.sol` (Fuji), `CollManagement.sol` (Sepolia), and `PrivacyProxy.sol` (Sepolia). Eliza, powered by ElizaOS, monitors health factors and provides liquidation data via a local API.

### Components

#### DepositForm (`deposit-form.tsx`)
- **Purpose**: Deposits WETH on Sepolia via `CollManagement.sol` (public) or `PrivacyProxy.sol` (private).
- **Functionality**:
  - UI for WETH selection, amount, Fuji recipient, and deposit type (public/private).
  - **Public**: Approves WETH, calls `depositCollateral`.
  - **Private**: Generates ZK commitment (`keccak256(nullifier, secret)`), approves WETH for `PrivacyProxy.sol`, calls `deposit`. Stores commitment in Merkle tree, forwards to `CollManagement.sol`.
  - Shows balance, dynamic fee (Chainlink ETH/USD, gas price).
  - Validates Sepolia (11155111), logs errors (e.g., low balance).
  - Note: ZK proof verification is disabled in `PrivacyProxy.sol`; production needs `snarkjs` with `deposit.circom`.

#### BorrowInterface (`borrow-interface.tsx`)
- **Purpose**: Borrows USDC via `BorrowManagement.sol`.
- **Functionality**:
  - UI for USDC amount (e.g., 2500), borrow action.
  - Displays available borrow (~8152.93 USDC for 5 WETH).
  - Fetches health factor from Eliza API (`/health-factor?user=<address>`).
  - Logs transactions, errors.

#### AvailableBorrowing (`available-borrowing.tsx`)
- **Purpose**: Shows borrow balance, collateral.
- **Functionality**:
  - Queries `availableBorrowTokenBalance`, `CollManagement.sol` data.
  - Calculates USDC borrow limit (1.5x collateral-to-debt).
  - Logs balance.

### Integration Details
- **Contracts**:
  - `BorrowManagement.sol` (Fuji, `0x8828210BCdC39fB6A6cA01861970825F317F58d6`): USDC borrowing.
  - `CollManagement.sol` (Sepolia, `0xd4aa953485eF4f1A916e42b9350Ab510f0920465`): WETH deposits.
  - `PrivacyProxy.sol` (Sepolia, `0xB4b8b2ed36407eE96A42954308E023fA9eAe2437`): Private ZK deposits.
- **Eliza Liquidation Agent**:
  - Monitors health factors via `HealthFactorProvider`, triggers liquidations with `LiquidateAction`.
  - API:
    - `POST /check-positions`: Checks borrower positions.
    - `GET /health-factor?user=<address>`: Returns health factor (e.g., `{"healthFactor": "2.45"}`).
  - Configured via `.env`.
- **Dependencies**:
  - `ethers.js`.
  - UI: `@/components/ui`, `@/hooks/use-toast`.
  - ABIs: `BorrowManagement.json`, `CollManagement.json`, `PrivacyProxy.json`, `ERC20.json`.
- **Configuration**:
  - Chain IDs: Fuji (`43113`), Sepolia (`11155111`).
  - `.env`:
    - `RPC_URL`: `https://ethereum-sepolia-rpc.publicnode.com`.
    - `CONTRACT_ADDRESS`: `0xd4aa953485eF4f1A916e42b9350Ab510f0920465`.
    - `PRIVATE_KEY`: Agent key (secure).
    - `BORROWERS`: Addresses (e.g., `0x76ACa6a6B825683408d28B71ed11d5463fA1496F`).
  - API: `http://localhost:3001`.
  - Chainlink ETH/USD: `0x694AA1769357215DE4FAC081bf1f309aDC325306`.

### Setup
1. **Install**:
   ```bash
   npm install ethers express cors @elizaos/core @elizaos/plugin-evm
   ```
2. **Configure**:
   - Set `.env` with `RPC_URL`, `CONTRACT_ADDRESS`, `PRIVATE_KEY`, `BORROWERS`.
   - Start Eliza:
     ```bash
     npm run start:server
     ```
3. **Run Frontend**:
   - Connect wallet, use `DepositForm` (select WETH, amount, recipient, public/private), `BorrowInterface` (USDC borrow).
   - Check console for transaction hashes, health factors.

### Challenges Met
- Fixed `AvaiableBorrowBalance` typo for parsing.
- Ensured Sepolia/Fuji chain validation.
- Handled `NOBorrowInfo` errors with logging.
- Mitigated CCIP delays with toasts.
- Resolved Eliza API 404/500 errors for `/health-factor`.
- Added ZK private deposits via `PrivacyProxy.sol` with commitment generation.
- Implemented dynamic fees using Chainlink and gas price estimation.