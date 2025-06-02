# CCMM(Cross-chain Money Markets) (temp name)

## Protocol introduction

### Background

Lending protocols represent a core category within decentralized finance (DeFi), enabling users to significantly enhance their capital efficiency. Currently, leading protocols such as Compound and Aave primarily implement lending and borrowing functionalities on a single blockchain. However, market demand increasingly points towards solutions that allow users to deposit tokens on a source chain and borrow tokens on a different target chain.

Although several cross-chain lending protocols exist, substantial challenges persist. Pike Finance, for instance, suffered an exploit due to vulnerabilities in its smart contract bridge interactions. Kava Lend, while operational, continues to see relatively low transaction volumes. Radiant Capital, meanwhile, predominantly experiences intra-chain lending activities, with cross-chain borrowing metrics remaining comparatively limited.

Integrating lending functionalities with cross-chain bridging introduces heightened security concerns, as bridges frequently become points of vulnerability. Nevertheless, there is undeniable demand from financial institutions and large capital holders aiming to efficiently manage assets across multiple blockchains. Increased reliance on bridges may amplify security risks, yet the flexibility they provide is essential for maximizing capital efficiency across diverse blockchain ecosystems.

Recognizing these challenges and opportunities, our protocol is specifically designed to support financial institutions and significant capital entities in enhancing their asset management capabilities. By leveraging advanced security mechanisms and sophisticated management tools, we ensure robust protection alongside optimized capital utilization. Additionally, our platform provides flexibility tailored specifically for retail users.

### Features

1. Cross-Chain Lending and Borrowing (Priority 1)

   1. Users can deposit collateral on the source chain and select borrowing tokens on the target chain.
   2. Chains supported: Ethereum, BNB, Avalanche.
      Collateral tokens supported: ETH, BNB.
      Borrowing token supported: USDC.

2. Collateral Management (Priority 1)

   1. Efficient management of user collateral and borrowed capital across different chains.
   2. Consistent maintenance of health factors during deposits and redemptions.
   3. Robust liquidation management system.

3. Security Management

   1. Multi-signature approvals for large deposits.
   2. Partnerships with insurance providers.
   3. Whitelist controls for security.
   4. AI-driven monitoring for proactive security.

4. Optimized Capital Management

   0. AI-driven yield optimization and automated liquidation protection (Priority 1).

   1. Dashboard displaying comprehensive lending and borrowing APYs across different supportede chains
      help user find the potential opportunities or riskes

   2. Build automated yield scanner showing real opportunities
      (TO DO)

   3. Hedge fund-targeted functionalities (TODO, more desgin consideration)
      RESTful APIs for seamless integration
      Webhook notifications for real-time alerts
      Risk management endpoints

   4. Professional capital management tools
      Portfolio rebalancing algorithms
      Automated liquidation protection
      Multi-chain position tracking and analytics

5. Privacy (Priority 1)
   User borrowing activities remain private across chains.
   TODO should check these blow points throughly
   ```
   How would zkp be used for privacy? What is the value-prop for ensuring certain things are private?
   ```

### Stack/Architecture

![draft_Architecture](img/Architecture_draft.png)

## Chainlink Services

notices:

1. below should link the related code which applied chainlink services
2. state changed proof in different chains

- [Chainlink Price Feeds](https://docs.chain.link/docs/using-chainlink-reference-contracts)
- [Chainlink VRF V2](https://docs.chain.link/docs/chainlink-vrf)
- [Chainlink Automation](https://docs.chain.link/chainlink-automation/introduction)
- ...

## Sponser Services
