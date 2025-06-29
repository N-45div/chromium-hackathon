import { ethers } from "ethers";
import * as fs from "fs";
import "dotenv/config"; // To load .env file
import FunctionsTriggerArtifact from "../artifacts/contracts/FunctionsTrigger.sol/FunctionsTrigger.json" with { type: "json" };

async function main() {
  // Configuration for Chainlink Functions
  const functionsRouterAddress = "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"; // Sepolia Router
  const donIdStr = "fun-ethereum-sepolia-1"; // Sepolia DON ID
  const donIdBytes = ethers.encodeBytes32String(donIdStr);
  const subscriptionId = 5201; // Your Functions subscription ID
  const gasLimit = 300000; // Gas limit for the callback function

  // Provider and wallet setup
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL!)
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  console.log(`Deploying FunctionsTrigger contract from account: ${wallet.address}...`);

  // Contract factory for deployment
  const functionsTriggerFactory = new ethers.ContractFactory(
    FunctionsTriggerArtifact.abi,
    FunctionsTriggerArtifact.bytecode,
    wallet
  );

  // Deploy the contract with all required arguments
  const functionsTrigger = await functionsTriggerFactory.deploy(
    functionsRouterAddress, // router
    donIdBytes,           // donId
    subscriptionId,       // subscriptionId
    gasLimit              // gasLimit
  );

  await functionsTrigger.waitForDeployment();

  const contractAddress = await functionsTrigger.getAddress();
  console.log(`✅ FunctionsTrigger deployed to: ${contractAddress}`);

  // Log the source code for convenience in setting up the Chainlink Function
  const source = fs.readFileSync("./src/functions/check-positions.ts", "utf8");
  console.log("\nUse this contract address and the source code below to set up your Chainlink Automation trigger.");
  console.log("--------------------------------------------------");
  console.log("Chainlink Function source code:");
  console.log(source);
  console.log("--------------------------------------------------");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

