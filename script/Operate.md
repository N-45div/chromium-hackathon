8. DepositCollateral in sepolia
   check list
   8.1. coll_management have enough link token (1 link )

```
https://sepolia.etherscan.io/address/0x74ea849ba30b0a8ea2b749bb662516935331492c#code
1)address sender_collManagement
// mockCollateralWETH https://sepolia.etherscan.io/address/0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE#code
2)address mockCollateralWETH,
<!-- 0.1 ether -->
3. uint256 collateralAmount,
<!-- 43113 -->
uint256 targetChainId,
// mockBorrowUSDC https://testnet.snowtrace.io/address/0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5
address mockBorrowUSDC,
<!-- 0xea2f3b9cdb2B68297441c176F38ac2ec3926e0b8 -->
address recipient_by_depositor
```

```
forge script ./script/DeployContracts.s.sol:DepositCollateral -vvv --broadcast --rpc-url https://eth-sepolia.g.alchemy.com/v2/yRf7suvkiMCkGHzjsyImEXZ0d7Z6RP8Z  --sig "run(address,address,uint256,uint256,address,address)" -- 0x74ea849ba30b0a8ea2b749bb662516935331492c 0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE  100000000000000000 43113 0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5 0xea2f3b9cdb2B68297441c176F38ac2ec3926e0b8

```

tx: https://sepolia.etherscan.io/tx/0x1a085552534057f138b8f4ef8be4b098128377979772f56b3bf3946c1e1ea2fb
CCIP CHECK :https://ccip.chain.link/#/side-drawer/msg/0xa6ad659fdaec4d2d6b7c13f68284e8f2b7b74a86f9b867b7b92ede05a01031f0

FUJI WORK. USER(0xea2f3b9cdb2B68297441c176F38ac2ec3926e0b8) CAN BORROW
https://testnet.snowtrace.io/address/0xfa12B0c5Af2D60a4748F4038163854E8FaAd26d8/contract/43113/readContract?chainid=43113

9. Check list
1. user have native tokne in fuji (avax)
1. borrowManagement have link token(pay fees)

Now 1000 USDC in borrowAmount(decimals?)

run(address receiver_borrowManagement, uint256 borrowAmount)

```
forge script ./script/DeployContracts.s.sol:BorrowApply -vvv --broadcast --rpc-url https://avax-fuji.g.alchemy.com/v2/yRf7suvkiMCkGHzjsyImEXZ0d7Z6RP8Z  --sig "run(address,uint256)" -- 0xfa12b0c5af2d60a4748f4038163854e8faad26d8 10000000000

```

not work can chekc blow
https://dashboard.tenderly.co/tony007/test/tx/0xd78f259f144e3a2b70e7376e240d688dd3ca09a79f56bdd6dacf631955f7bb9a
