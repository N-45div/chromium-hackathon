import { ethers } from "ethers";
import "dotenv/config";
// Minimal ABI to get the CollateralDeposited events
const collManagementAbi = [
    "event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount)",
];
async function main() {
    // Ensure environment variables are set
    if (!process.env.RPC_URL) {
        throw new Error("Please set RPC_URL in your .env file");
    }
    // The address of the deployed CollManagement contract.
    const collManagementAddress = "0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389";
    // Script logic
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const contract = new ethers.Contract(collManagementAddress, collManagementAbi, provider);
    console.log(`Fetching CollateralDeposited events from ${collManagementAddress}...`);
    const filter = contract.filters.CollateralDeposited();
    const latestBlock = await provider.getBlockNumber();
    const chunkSize = 499; // Use 499 to be safe with the 500 block range limit
    let allEvents = [];
    console.log(`Scanning from block 0 to ${latestBlock} in chunks of ${chunkSize}...`);
    for (let i = 0; i <= latestBlock; i += chunkSize) {
        const fromBlock = i;
        const toBlock = Math.min(i + chunkSize - 1, latestBlock);
        try {
            const events = await contract.queryFilter(filter, fromBlock, toBlock);
            allEvents = allEvents.concat(events);
            console.log(`  - Scanned blocks ${fromBlock} to ${toBlock}: Found ${events.length} events.`);
        }
        catch (error) {
            console.log(`  - Scanned blocks ${fromBlock} to ${toBlock}: Failed. Error: ${error.message}`);
        }
    }
    // Extract unique depositor addresses from the events
    const depositorSet = new Set();
    allEvents.forEach((event) => {
        if ('args' in event && event.args) {
            depositorSet.add(event.args.user);
        }
    });
    const depositors = Array.from(depositorSet);
    if (depositors.length === 0) {
        console.log("\nNo depositors found in the contract's event history.");
        console.log("You will need to make some deposits before the agent can monitor borrowers.");
    }
    else {
        console.log("\nFound the following unique depositors:");
        depositors.forEach((depositor, index) => {
            console.log(`  [${index}]: ${depositor}`);
        });
        console.log("\nThis list will be used by the agent to check for liquidations.");
    }
}
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
