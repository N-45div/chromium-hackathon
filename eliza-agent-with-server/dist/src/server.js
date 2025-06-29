import { AgentRuntime } from '@elizaos/core';
import 'dotenv/config';
import { ethers } from 'ethers';
import express from 'express';
import cors from 'cors';
import { evmPlugin } from '@elizaos/plugin-evm';
import { LiquidationAgent } from './agents/LiquidationAgent.js';
import { HealthFactorProvider } from './providers/HealthFactorProvider.js';
import { LiquidateAction } from './actions/LiquidateAction.js';
const app = express();
const router = express.Router();
const port = 3001;
app.use(cors());
app.use(express.json());
let agent;
async function initializeAgent() {
    const rpcUrl = process.env.RPC_URL;
    const contractAddress = process.env.CONTRACT_ADDRESS;
    const privateKey = process.env.PRIVATE_KEY;
    const borrowersEnv = process.env.BORROWERS;
    if (!rpcUrl || !contractAddress || !privateKey || !borrowersEnv) {
        throw new Error('Missing required environment variables');
    }
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const runtime = new AgentRuntime({
        plugins: [evmPlugin],
    });
    const healthProvider = new HealthFactorProvider({ rpcUrl, contractAddress });
    const liquidateAction = new LiquidateAction({ rpcUrl, contractAddress, privateKey });
    runtime.providers.push(healthProvider);
    runtime.actions.push(liquidateAction);
    const borrowers = borrowersEnv.split(',').map(a => a.trim());
    const agentConfig = {
        healthFactorThreshold: 10n ** 18n,
        borrowers,
    };
    agent = await LiquidationAgent.start(runtime, agentConfig);
    console.log('Liquidation agent initialized and ready.');
}
// Wrapper for async route handlers to catch errors
const asyncHandler = (fn) => (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
};
const checkPositionsHandler = async (req, res) => {
    if (!agent) {
        res.status(503).json({ error: 'Agent not initialized yet.' });
        return;
    }
    await agent.checkPositions();
    res.status(200).json({ message: 'Position check triggered successfully.' });
};
router.post('/check-positions', asyncHandler(checkPositionsHandler));
app.use('/', router);
initializeAgent().then(() => {
    app.listen(port, () => {
        console.log(`Server listening at http://localhost:${port}`);
    });
}).catch(error => {
    console.error('Failed to initialize liquidation agent:', error);
    process.exit(1);
});
