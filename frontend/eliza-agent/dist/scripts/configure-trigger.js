import { ethers } from "ethers";
import FunctionsTriggerArtifact from "../artifacts/contracts/FunctionsTrigger.sol/FunctionsTrigger.json" with { type: "json" };
import "dotenv/config";
async function main() {
    // =================================================================================================================
    // ============================================== START CONFIGURATION ==============================================
    // =================================================================================================================
    // The address of the newly deployed FunctionsTrigger contract.
    const triggerContractAddress = "0xAD67298b07951994c21092652f4EEa23386388a6";
    // The address of the CollManagement contract that the off-chain script will query.
    const collManagementAddress = "0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389";
    // A comma-separated list of borrower addresses to monitor.
    // IMPORTANT: Replace with the actual borrower addresses you want to check.
    const borrowers = "0x76ACa6a6B825683408d28B71ed11d5463fA1496F";
    // =============================================== END CONFIGURATION ===============================================
    // =================================================================================================================
    // Ensure environment variables are set
    if (!process.env.RPC_URL || !process.env.PRIVATE_KEY) {
        throw new Error("Please set RPC_URL and PRIVATE_KEY in your .env file");
    }
    // Script logic
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    const triggerContract = new ethers.Contract(triggerContractAddress, FunctionsTriggerArtifact.abi, wallet);
    console.log(`Connecting to FunctionsTrigger at ${triggerContractAddress}...`);
    console.log("Setting on-chain configuration for the off-chain script...");
    const tx = await triggerContract.setConfig(process.env.RPC_URL, // The off-chain script needs an RPC URL to connect to the blockchain
    collManagementAddress, borrowers);
    console.log(`Transaction sent: ${tx.hash}. Waiting for confirmation...`);
    await tx.wait(1);
    console.log("✅ Configuration set successfully!");
    // Optional: Verify the config was set
    console.log("\n--- Verifying Stored Configuration ---");
    const [storedRpcUrl, storedContractAddress, storedBorrowers] = await Promise.all([
        triggerContract.s_rpcUrl(),
        triggerContract.s_contractAddress(),
        triggerContract.s_borrowers(),
    ]);
    console.log(`RPC URL: ${storedRpcUrl}`);
    console.log(`CollManagement Address: ${storedContractAddress}`);
    console.log(`Borrowers: ${storedBorrowers}`);
    console.log("------------------------------------");
}
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
