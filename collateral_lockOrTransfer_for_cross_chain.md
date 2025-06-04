# Cross-Chain Lending Protocol Analysis

## User's Question

Pike Finance, Kava Lend, and Radiant Capital are cross-chain lending and borrowing protocols. Explain their flows related to deposits and borrowing, based on two models:

1. **Model 1 (Token Transfer):** User deposits collateral on the source chain, and the protocol transfers the token to the target chain, allowing borrowing directly there.
2. **Model 2 (Informational):** User deposits collateral on the source chain, and the target chain is informed of how much the user can borrow without physically transferring tokens.

Which model do Pike Finance, Kava Lend, and Radiant Capital apply? Analyze the differences.

---

## Explanation of Design Models

### Model 1: Token Transfer

-   **Process:**

    1. Collateral deposited on the source chain.
    2. Tokens are physically bridged to the target chain.
    3. Borrowing occurs directly against these transferred tokens.

-   **Pros:**

    -   Simplified liquidation (collateral and debt on the same chain).
    -   Less reliance on cross-chain oracles.

-   **Cons:**

    -   Higher bridge security risks.
    -   Increased fees and latency due to bridging.

### Model 2: Informational (Virtual Collateral)

-   **Process:**

    1. Collateral remains on the source chain.
    2. Target chain receives information about the collateral deposit.
    3. Borrowing is executed based on virtual collateral representation.

-   **Pros:**

    -   Reduced bridging risks.
    -   Lower costs and quicker operations.

-   **Cons:**

    -   Complex liquidation mechanics.
    -   Higher dependence on secure messaging and oracle accuracy.

---

## Protocol Analysis

### Pike Finance

-   **Model Used:** Model 2 (Informational)
-   **Mechanics:** Relied on Circle’s CCTP for cross-chain messaging.
-   **Pros:** Low bridging overhead.
-   **Cons:** Vulnerable to messaging exploits (notably exploited in April 2024).

### Kava Lend

-   **Model Used:** Model 2 (Informational)
-   **Mechanics:** Uses IBC protocol within the Cosmos ecosystem.
-   **Pros:** Efficient cross-chain management within Cosmos.
-   **Cons:** Complex liquidation and lower market adoption.

### Radiant Capital

-   **Model Used:** Model 2 (Informational)
-   **Mechanics:** Uses LayerZero for cross-chain communication.
-   **Pros:** Efficient and lower risk.
-   **Cons:** Complex cross-chain liquidation, limited cross-chain borrowing adoption.

---

## Comparative Analysis

| Aspect                   | Model 1 (Token Transfer) | Model 2 (Informational) |
| ------------------------ | ------------------------ | ----------------------- |
| Bridge Risk              | High                     | Low                     |
| Liquidation Simplicity   | High                     | Low                     |
| Fees & Cost              | High                     | Low                     |
| Transaction Latency      | High                     | Low                     |
| Oracle Dependency        | Moderate                 | High                    |
| Scalability & Efficiency | Lower                    | Higher                  |
| Security Risk            | Higher                   | Messaging dependent     |

---

## Conclusion

-   Pike, Kava, and Radiant adopt **Model 2** primarily due to efficiency, lower costs, and reduced direct bridge risk.
-   Effective use of Model 2 requires secure messaging, robust oracle integration, and sophisticated liquidation systems to mitigate vulnerabilities.
