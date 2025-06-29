## Frontend Integration

The frontend enables users to deposit WETH collateral and borrow USDC via three components: `DepositForm`, `BorrowInterface`, and `AvailableBorrowing`, interacting with `BorrowManagement.sol` (Fuji) and `CollManagement.sol` (Sepolia).

### Components

#### DepositForm (`deposit-form.tsx`)
- **Purpose**: Deposits WETH collateral on Sepolia via `CollManagement.sol`.
- **Functionality**:
  - UI to select WETH, input amount, and specify Fuji recipient.
  - Approves WETH and calls `depositCollateral`.
  - Shows wallet balance and transaction preview (amount, recipient, fee).
  - Validates Sepolia chain and logs errors (e.g., insufficient allowance).

#### BorrowInterface (`borrow-interface.tsx`)
- **Purpose**: Borrows USDC via `borrowApply` in `BorrowManagement.sol`.
- **Functionality**:
  - UI to select USDC, input amount (e.g., 2500 USDC), and borrow.
  - Shows available borrow (~8152.93 USDC for 5 WETH).
  - Displays health factor and liquidation price.
  - Logs transaction details and errors.

#### AvailableBorrowing (`available-borrowing.tsx`)
- **Purpose**: Displays borrow balance and collateral details.
- **Functionality**:
  - Queries `availableBorrowTokenBalance` for status.
  - Fetches collateral data from `CollManagement.sol`.
  - Calculates available USDC (1.5x collateral-to-debt ratio).
  - Logs balance info.

### Integration Details
- **Contracts**:
  - `BorrowManagement.sol` (Fuji): Manages USDC borrowing.
  - `CollManagement.sol` (Sepolia): Handles WETH deposits.
- **Dependencies**:
  - `ethers.js`.
  - UI: `@/components/ui` (Card, Button, Input, Select, Label, Alert), `@/hooks/use-toast`.
  - ABIs: `BorrowManagement.json`, `CollManagement.json`, `ERC20.json`.
- **Configuration**:
  - Chain IDs: Fuji (`43113`), Sepolia (`11155111`).
  - WETH: `0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764`.
  - USDC: `0x9A133558fF7349f7721f3dD2b0E193e55ae9A3F1`.

### Setup
1. **Install Dependencies**:
   ```bash
   npm install ethers
   ```
2. **Run Frontend**:
   - Deploy UI, connect wallet, and:
     - In `DepositForm`, select WETH, enter amount, specify recipient, approve, deposit.
     - In `BorrowInterface`, select USDC, enter amount (e.g., 2500), click "Borrow USDC".
   - Check console for transaction hashes and logs.

### Challenges Met
- **Struct Mismatch**: `AvaiableBorrowBalance` typo in `BorrowManagement.sol` caused parsing errors; mitigated with safe field access.
- **Chain Validation**: Ensuring Sepolia for deposits and Fuji for borrowing required robust chain checks.
- **Error Handling**: Managed `NOBorrowInfo` errors due to uninitialized borrow status, improved with detailed console logging.
- **Cross-Chain Latency**: CCIP message delays between Sepolia and Fuji impacted borrow confirmation; addressed with user feedback via toasts.