// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/core/privacy/PrivacyProxy.sol";
import "../src/core/privacy/verifiers/DepositVerifier.sol";
import "../src/core/privacy/verifiers/BorrowVerifier.sol";
import "./Helper.sol";

/**
 * @title DeployPrivacy
 * @author StratoLend
 * @notice This script deploys the modular ZK privacy components.
 * It deploys the verifiers and the PrivacyProxy, linking them to the existing CollManagement contract.
 */
contract DeployPrivacy is Script, Helper {
    function run(address collManagementAddress, uint256 blockChainID) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Verifiers
        DepositVerifier depositVerifier = new DepositVerifier();
        console.log("DepositVerifier deployed to:", address(depositVerifier));

        BorrowVerifier borrowVerifier = new BorrowVerifier();
        console.log("BorrowVerifier deployed to:", address(borrowVerifier));

        // 2. Deploy PrivacyProxy
        // The Merkle tree levels must match the circuits (20).
        uint32 merkleTreeLevels = 20;
        PrivacyProxy privacyProxy = new PrivacyProxy(
            merkleTreeLevels,
            collManagementAddress,
            address(depositVerifier),
            address(borrowVerifier)
        );
        console.log("PrivacyProxy deployed to:", address(privacyProxy));

        console.log(
            "ZK Privacy contracts deployed on ",
            networks[blockChainID]
        );

        vm.stopBroadcast();
    }
}
