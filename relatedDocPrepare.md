Below materials will add for the future document or the slides

1. Privacy level
   https://github.com/N-45div/chromium-hackathon/issues/11#issuecomment-2954107900

### Front-end integrated with smart contract work flow(v1)

## SouceChain

1.  User select which chain and which collateralToken they want to deposit

    1. For now we only support Ethereum Sepolia(11155111) as source chain, but you can supply more chain as other options
    2. User can also select which collateralToken token they want to deposit, but for now, just used our deployed weth contract. [mock weth contract](<(https://sepolia.etherscan.io/address/0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE#code)>)
    3. you can based on the chainID by using abi file, get the collmanagement or borrowerManagement along with their functions

2.  call depositCollateral function in abi file

    1. before calling depositCollateral, you should prepare below params, which can find in script/abi/CollManagement_11155111.json file.

       1. [collateralToken](<((https://sepolia.etherscan.io/address/0xb8F551189a9E15988C05EA29d4e3Cf8e39eD6BFE#code)%3E)%3E>) have known,
       2. amount: which is the collateralToken token use want to supply. (should confime user approve collmanager using theri weth token)
       3. targetChainId: can using supportCollInfo function by checking abi file. so when user select which collateralToken, you can get the related config info, which inlcudes the targetChainId.
       4. borrowToken: same as targetChainId, when you call supportCollInfo, can get the [borrowToken](https://testnet.snowtrace.io/address/0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5) address.
       5. recipientAddress, if user want to use normal mode, they should supply the address who will borrow in target chain.
       6. proofA related privacy mode. now don't implement in test net.
       7. commitmentHash same as proofA

       ```
       "components": [
                {
                   "name": "collateralToken",
                   "type": "address",
                   "internalType": "address"
                },
                {
                   "name": "amount",
                   "type": "uint256",
                   "internalType": "uint256"
                },
                {
                   "name": "targetChainId",
                   "type": "uint256",
                   "internalType": "uint256"
                },
                {
                   "name": "borrowToken",
                   "type": "address",
                   "internalType": "address"
                },
                {
                   "name": "recipientAddress",
                   "type": "address",
                   "internalType": "address"
                },
                {
                   "name": "proofA",
                   "type": "bytes",
                   "internalType": "bytes"
                },
                {
                   "name": "commitmentHash",
                   "type": "bytes32",
                   "internalType": "bytes32"
                }
             ]
       ```

    2. after success calling

       2.1 collateralBalances can get user's collateral balance

       2.2 also should show the ccip messsage status. for now no add, later will add. either by emit or return messageId.

       2.3 crossBalances can show user's other chain's borrow info. which input user's address and targetchainID, can get target borrow info as below

```
   struct TargetChainBorowInfo {
      address borrowToken;
      address recipientAddress; // zero address means no specify
      uint256 syncBorrowBalance;
   }
```

## TargetChain

3.  how to check the avaiable borrow info in target chain

    3.1 when deposit token in source chain success, user can swith to the target chain. get the related info. so you can call funcitons in this file:script/abi/BorrowManagement_43113.json

    3.2 availableBorrowTokenBalance funciton, when input the receiptAddress(the address pointed by user when user deposit in source chain), can get all related borrow info. user want to know.

        ```
                 struct AvaiableBorrowBalance {
                 address collateralToken;
                 address borrowToken; // fixed to USDC for now
                 address initiator; // the user who enable borrow
                 uint256 sourceChainId;
                 uint256 pendingAmount; // the amount that is pending to be borrowed, each time borrow must ensure pendingAmount == 0.
                 uint256 borrowedAmount;
                 BorrowStatus status;
                 bytes proof;
                 uint64 updatedAt; // timestamp of the last update

              }
           ```

           For BorrowStatus's meaning can check below

           ```
                    enum BorrowStatus {
                 NONE,
                 INITIAL,
                 BORROW_PENDING_TARGET,
                 BORROW_CONFIRMED_SOURCE,
                 BORROW_CONFIRMED_TARGET,
                 REPAY_PENDING_TARGET,
                 REPAY_CONFIRMED_SOURCE,
                 REPAY_CONFIRMED_TARGET

              }
        ```

4.  user borrow usdc in source chain

    4.1 call borrowApply(one param), which assum user borrow [usdc](https://testnet.snowtrace.io/address/0x8c30c02cbdd4264f458a2083d3cc188c0fd0c3f5), also you can check availableBorrowTokenBalance do some check. or just call, if no exist info, will revert

    4.2 the status after calling borrowApply. this involved with CCIP. can check bleow points.

    1. before the confirm from souce chain, you can also query availableBorrowTokenBalance, get the update info. such as pendingAmount, BorrowStatus,updatedAt, which shows the status before calling CCIP.

    2. also there involved with CCIP messagID, same as source chain, should show the ccip messsage status. for now no add, later will add. either by emit or return messageId.

    3. if CCIP call borrowApplyConfirm in source chain success. crossBalances info will also updated, you can check it by calling source chain.

    4. then CCIP call back to the target chain. if success, CCIP message will show the success status, and call borrowApprovedAndTransfer, finally transfer the borrow token to the receiptAddress.

    5. Finally, you can show user's borrowedToken balance have increasd by calling borrowedToken's balance. (I will supply borrowedToken abi later).

    you can adjust above flow based on your understanding.

Other flow, such as ColletralRatio, reapy... now not work in test net.
