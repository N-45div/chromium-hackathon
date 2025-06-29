import { AgentRuntime } from '@elizaos/core';
import 'dotenv/config'; // Automatically loads .env file
import { ethers } from 'ethers';
import { evmPlugin } from '@elizaos/plugin-evm';
import { LiquidationAgent } from './agents/LiquidationAgent.js';
import { HealthFactorProvider } from './providers/HealthFactorProvider.js';
import { LiquidateAction } from './actions/LiquidateAction.js';
// Minimal ABI to get the CollateralDeposited events
const collManagementAbi = [
    "event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 amount)",
];
async function main() {
    // 1. Configuration from environment variables
    const rpcUrl = process.env.RPC_URL;
    const contractAddress = process.env.CONTRACT_ADDRESS;
    const privateKey = process.env.PRIVATE_KEY;
    const borrowersEnv = process.env.BORROWERS;
    if (!rpcUrl || !contractAddress || !privateKey || !borrowersEnv) {
        throw new Error('Missing required environment variables: RPC_URL, CONTRACT_ADDRESS, PRIVATE_KEY, BORROWERS');
    }
    // 2. Setup provider and runtime
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const runtime = new AgentRuntime({
        plugins: [evmPlugin],
    });
    // 3. Directly register our custom provider and action
    const healthProvider = new HealthFactorProvider({ rpcUrl, contractAddress });
    const liquidateAction = new LiquidateAction({ rpcUrl, contractAddress, privateKey });
    runtime.providers.push(healthProvider);
    runtime.actions.push(liquidateAction);
    // 4. Get the list of borrowers from environment variables for the demo
    const borrowers = borrowersEnv.split(',').map(a => a.trim());
    if (borrowers.length === 0) {
        console.log("No borrowers configured in .env file. The agent will not monitor any positions.");
        return;
    }
    console.log(`Configured to monitor ${borrowers.length} borrowers: ${borrowers.join(', ')}`);
    // 5. Configure and start the agent
    const agentConfig = {
        healthFactorThreshold: 10n ** 18n, // Example: 1.0, assuming 18 decimals
        borrowers,
    };
    const agent = await LiquidationAgent.start(runtime, agentConfig);
    // 6. Run the agent on a persistent loop
    console.log('Starting persistent monitoring loop (checking every 60 seconds)...');
    setInterval(async () => {
        try {
            console.log('\nChecking positions...');
            await agent.checkPositions();
            console.log('Finished check.');
        }
        catch (error) {
            console.error('Error during position check:', error);
        }
    }, 60000); // 60 seconds
}
main().catch(error => {
    console.error('Agent failed to start:', error);
    process.exit(1);
});
