import { ethers } from "ethers";
import "dotenv/config";

async function main() {
  // Configuration
  const registryAddress = "0xe5697f3d7314234b45a23c88b4454d4a42a154a4"; // Sepolia Functions Billing Registry
  const subscriptionId = 5201; // Your subscription ID
  const consumerAddress = "0xa103Fcf0DF8F2195a76C28270a06E422aDDb5a38"; // The address of the newly deployed consumer contract address

  // Minimal ABI for the addConsumer function
  const registryAbi = [
    "function addConsumer(uint64 subscriptionId, address consumer) external",
  ];

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL!);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  // Create contract instance
  const registry = new ethers.Contract(registryAddress, registryAbi, wallet);

  console.log(`Adding consumer: ${consumerAddress} to subscription: ${subscriptionId}...`);

  // Call the addConsumer function
  const tx = await registry.addConsumer(subscriptionId, consumerAddress);

  console.log(`Transaction sent! Hash: ${tx.hash}`);
  await tx.wait();
  console.log("✅ Consumer added successfully!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
