## Frontend Integration with Eliza Liquidation Agent

The frontend enables users to deposit WETH collateral and borrow USDC via three components: `DepositForm`, `BorrowInterface`, and `AvailableBorrowing`, interacting with `BorrowManagement.sol` (Fuji) and `CollManagement.sol` (Sepolia). Eliza, a liquidation agent powered by ElizaOS, monitors borrower health factors and provides liquidation data via a local API.

### Components

#### DepositForm (`deposit-form.tsx`)
- **Purpose**: Deposits WETH on Sepolia via `CollManagement.sol`.
- **Functionality**:
  - UI to select WETH, input amount, specify Fuji recipient.
  - Approves WETH, calls `depositCollateral`.
  - Displays wallet balance, transaction preview (~$12.50 fee).
  - Validates Sepolia chain, logs errors (e.g., insufficient allowance).

#### BorrowInterface (`borrow-interface.tsx`)
- **Purpose**: Borrows USDC via `borrowApply` in `BorrowManagement.sol`.
- **Functionality**:
  - UI to select USDC, input amount (e.g., 2500 USDC), borrow.
  - Shows available borrow (~8152.93 USDC for 5 WETH).
  - Fetches health factor from Eliza's API (`http://localhost:3001/health-factor?user=<borrower_address>`), displays liquidation price and liquidation data.
  - Logs transaction details, errors.

#### AvailableBorrowing (`available-borrowing.tsx`)
- **Purpose**: Displays borrow balance, collateral details.
- **Functionality**:
  - Queries `availableBorrowTokenBalance` for status.
  - Fetches collateral data from `CollManagement.sol`.
  - Calculates available USDC (1.5x collateral-to-debt ratio).
  - Logs balance info.

### Integration Details
- **Contracts**:
  - `BorrowManagement.sol` (Fuji, `0x8828210BCdC39fB6A6cA01861970825F317F58d6`): Manages USDC borrowing.
  - `CollManagement.sol` (Sepolia, `0xd4aa953485eF4f1A916e42b9350Ab510f0920465`): Handles WETH deposits.
- **Eliza Liquidation Agent**:
  - Powered by ElizaOS, monitors borrower health factors using `HealthFactorProvider` and triggers liquidations via `LiquidateAction`.
  - API endpoints:
    - `POST /check-positions`: Triggers position checks for borrowers.
    - `GET /health-factor?user=<borrower_address>`: Returns health factor (e.g., `{"healthFactor": "2.45"}`).
  - Configured via `.env` (Sepolia RPC, contract address, private key, borrowers).
- **Dependencies**:
  - `ethers.js`.
  - UI: `@/components/ui` (Card, Button, Input, Select, Label, Alert), `@/hooks/use-toast`.
  - ABIs: `BorrowManagement.json`, `CollManagement.json`, `ERC20.json`.
- **Configuration**:
  - Chain IDs: Fuji (`43113`), Sepolia (`11155111`).
  - Environment variables in `.env`:
    - `RPC_URL`: Sepolia RPC URL (`https://ethereum-sepolia-rpc.publicnode.com`).
    - `CONTRACT_ADDRESS`: `CollManagement.sol` address (`0xd4aa953485eF4f1A916e42b9350Ab510f0920465`).
    - `PRIVATE_KEY`: Liquidation agent private key (secure in production).
    - `BORROWERS`: Comma-separated borrower addresses (e.g., `0x76ACa6a6B825683408d28B71ed11d5463fA1496F`).
  - Eliza API: Runs on `http://localhost:3001` (confirm port in `server.js`).

### Setup
1. **Install Dependencies**:
   ```bash
   npm install
   ```
2. **Configure Environment**:
   - Use provided `.env` with `RPC_URL`, `CONTRACT_ADDRESS`, `PRIVATE_KEY`, `BORROWERS`.
   - Start Eliza agent:
     ```bash
     npm run start:server
     ```
3. **Run Frontend**:
   - Deploy UI, connect wallet:
     - In `DepositForm`, select WETH, enter amount, specify recipient, approve, deposit.
     - In `BorrowInterface`, select USDC, enter amount (e.g., 2500), click "Borrow USDC".
   - Check console for transaction hashes, health factor logs.

### Challenges Met
- **Struct Mismatch**: `AvaiableBorrowBalance` typo caused parsing errors; mitigated with safe field access.
- **Chain Validation**: Ensured Sepolia for deposits, Fuji for borrowing with robust checks.
- **Error Handling**: Managed `NOBorrowInfo` errors due to uninitialized borrow status via logging.
- **Cross-Chain Latency**: CCIP delays between Sepolia/Fuji impacted borrowing; addressed with toasts.
- **Eliza Integration**: Fixed 404/500 errors for `/health-factor` by adding endpoint and handling `BigInt` serialization.