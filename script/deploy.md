## Deployed full cycle

1. Deployed privacyPool and Colletral Token in source chain
2. Deployed privacyPool and borrow Token in target chain
3. Deployed CollManager in souce chain
4. Deployed BorrowManager in target chain
5. Set related router config for souce chain in target chain

   building the mapping ColletralToken==> targetChain(targetChainSelector)
   CollManager ==> BorrowManager(TargetChain)

6. Set related router config for target chain in source chain

   building the mapping borrowToken==> sourceChain(sourceChainSelector)
   borrowManager ==> CollManager(SourceChain)

7. Normal operations
   User deposit colletral token in source chain
   The receipte addres apply borrow in target chain (Now doesn't work in test net)

## Deploy scripts example

1. DeployPrepareContractForSourceChain in sepolia

// privacyPool in sepolia https://sepolia.etherscan.io/address/0x6cb13dce38690d4ab49d17416c1df23cc811d5a5#code
// mockCollateralWETH https://sepolia.etherscan.io/address/0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE#code

```
forge script ./script/DeployContracts.s.sol:DeployPrepareContractForSourceChain -vvv --broadcast --rpc-url <rpc-url>  --verify --verifier etherscan --etherscan-api-key <etherscan-api-ke> --sig "run(uint256)" -- 11155111
```

2. DeployPrepareContractForTargetChai in fuji
   // PrivacyPool https://testnet.snowtrace.io/address/0x64D392194d45727c061684c394035CfF240480D1/contract/43113/code
   // https://repo.sourcify.dev/43113/0x64D392194d45727c061684c394035CfF240480D1 (verify the PrivacyPool contract)
   // mockBorrowUSDC https://testnet.snowtrace.io/address/0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5

```
TargetChain deploy
forge script ./script/DeployContracts.s.sol:DeployPrepareContractForTargetChain -vvv --broadcast --rpc-url <rpc-url>   --verify --verifier etherscan --etherscan-api-key <etherscan-api-ke> --sig "run(uint256)" -- 43113
```

3. DeployCollManagementSender in sepolia
   // https://sepolia.etherscan.io/address/0x74ea849ba30b0a8ea2b749bb662516935331492c#code

```
forge script ./script/DeployContracts.s.sol:DeployCollManagementSender -vvv --broadcast --rpc-url <rpc-url>  --verify --verifier etherscan --etherscan-api-key <etherscan-api-ke> --sig "run(uint256,uint256,address,address,address)" -- 11155111 43113 0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE 0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5 0x6cb13dce38690d4ab49d17416c1df23cc811d5a5
```

4. DeployBorrowManagementReceiver in fuji
   https://testnet.snowtrace.io/address/0xfa12b0c5af2d60a4748f4038163854e8faad26d8

```
forge script ./script/DeployContracts.s.sol:DeployBorrowManagementReceiver -vvv --broadcast --rpc-url <rpc-url>  --verify --verifier etherscan --etherscan-api-key <etherscan-api-ke> --sig "run(uint256,address,address,address)" -- 43113  0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE 0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5 0x64D392194d45727c061684c394035CfF240480D1 --via-ir
```

6. SetRouterForStratoLendNetWorkForSource in sepolia

https://sepolia.etherscan.io/tx/0x8e8e136ca15cca0948188c3b139f019bc09ac99bee0510ae29f1dc035ac9ba27

```

forge script ./script/DeployContracts.s.sol:SetRouterForStratoLendNetWorkForSource -vvv --broadcast --rpc-url <rpc-url>  --sig "run(address,address,address,uint256)" -- 0x74ea849ba30b0a8ea2b749bb662516935331492c 0xfa12b0c5af2d60a4748f4038163854e8faad26d8 0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE 43113

```

7. SetRouterForStratoLendNetWorkForTarget in fuji

https://testnet.snowtrace.io/tx/0xfb8784f742ca69bbae4e7244175990e7470668c1906c9d044683e0a1b037da9c?chainid=43113

```
forge script ./script/DeployContracts.s.sol:SetRouterForStratoLendNetWorkForTarget -vvv --broadcast --rpc-url <rpc-url>  --sig "run(address,address,address,uint256)" -- 0x74ea849ba30b0a8ea2b749bb662516935331492c 0xfa12b0c5af2d60a4748f4038163854e8faad26d8 0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5 11155111

```

8. Depoist in sepolia
   Should check borrowManagement and CollManagement has enought link
   user have the Colletral Token which was supported by the CollManagement

```
forge script ./script/DeployContracts.s.sol:DepositCollateral -vvv --broadcast --rpc-url <rpc-url>  --sig "run(address,address,uint256,uint256,address,address)" -- 0x74ea849ba30b0a8ea2b749bb662516935331492c 0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE  100000000000000000 43113 0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5 0xea2f3b9cdb2B68297441c176F38ac2ec3926e0b8

```

9. BorrowApply in fuji (current not work in test net)

```
forge script ./script/DeployContracts.s.sol:BorrowApply -vvv --broadcast --rpc-url <rpc-url>  --sig "run(address,uint256)" -- 0xfa12b0c5af2d60a4748f4038163854e8faad26d8 10000000000
```

## Deploy address

[privacyPool in sepolia](https://sepolia.etherscan.io/address/0x6cb13dce38690d4ab49d17416c1df23cc811d5a5#code)
[CollateralWETH in sepolia](https://sepolia.etherscan.io/address/0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE#code)
[CollManagement in sepolia](https://sepolia.etherscan.io/address/0x74ea849ba30b0a8ea2b749bb662516935331492c#code)
[privacyPool in fuji](https://testnet.snowtrace.io/address/0x64D392194d45727c061684c394035CfF240480D1/contract/43113/code)
[borrowUsdc in fuji](https://testnet.snowtrace.io/address/0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5)
[BorrowManagement in fuji](https://testnet.snowtrace.io/address/0xfa12b0c5af2d60a4748f4038163854e8faad26d8)

Chink related CCIP address can check [Helper](script/Helper.sol), which include linkAddress, chainSelector, router address in different chains. current support sepolia(source chain)/fuji(target chain)

## Txs

All history txes can check in under this broadcasr directory.
For example

1. deposit in sepolia [deposit](broadcast/DeployContracts.s.sol/11155111/run-1750163569.json), you can find as need.
2. Deposit and enable borrow can CCIP status in there:https://ccip.chain.link/address/0xfa12b0c5af2d60a4748f4038163854e8faad26d8#/side-drawer/msg/0xa6ad659fdaec4d2d6b7c13f68284e8f2b7b74a86f9b867b7b92ede05a01031f0
3. borrowApply in fuji doens't work. https://testnet.snowtrace.io/tx/0xd78f259f144e3a2b70e7376e240d688dd3ca09a79f56bdd6dacf631955f7bb9a?chainid=43113.  
   [tenderly](https://dashboard.tenderly.co/tony007/test/tx/0xd78f259f144e3a2b70e7376e240d688dd3ca09a79f56bdd6dacf631955f7bb9aa)

## Explain

1. For now. all these contract's owner is 0xf101cEFc8AeCE4c5D2672d54FD7392F8255052ed, who can want to mint CollateralWETH in sepolia can inform me.
2. The borrowUsdc's supply by the address 0xf101cEFc8AeCE4c5D2672d54FD7392F8255052ed, if neeed I will mint more usdc as needed in Fuji net

## Problems

1. how to build the relationships between Colletral Token and borrowUSDC token across source and target chain
   Current desgin assume borrowUSDC are same in different chains. Actually they are not equal. Now, just Colletral Token in souce chain and borrow token in target chain
2. Can make privacyPool mutable, which fit for our test.
3. BorrowApply work in chainlink CCIP local test, but can't work by forking test or the test net. One reason current konow is fuji don't support sepolia's chainSelector by using forking(the RPC I used seems can't get the latest block.number, which can't get the latest support info), test net problem should continue to investigate.
4.

## TODO

1. You can based on above introduction, deployed new contracts.
2. Check the necessary features, which can be work in test net or the need data.
   2.1 ColletralRatio check
   More can add
