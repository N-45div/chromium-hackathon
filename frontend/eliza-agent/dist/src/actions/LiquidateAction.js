import { ethers, Contract, Wallet } from 'ethers';
// Placeholder ABI for the CollManagement contract's liquidate function.
const COLL_MANAGEMENT_ABI = [
    "function liquidate(address user) external"
];
export class LiquidateAction {
    config;
    name = LiquidateAction.name;
    description = 'Liquidates an undercollateralized user position on the CCMM protocol.';
    contract;
    wallet;
    constructor(config) {
        this.config = config;
        const provider = new ethers.JsonRpcProvider(config.rpcUrl);
        this.wallet = new Wallet(config.privateKey, provider);
        this.contract = new Contract(config.contractAddress, COLL_MANAGEMENT_ABI, this.wallet);
    }
    /**
     * Validates the input payload for the liquidation action.
     * @param runtime The agent runtime.
     * @param memory The memory object containing the userAddress.
     */
    async validate(runtime, memory) {
        const content = memory.content;
        if (typeof content === 'string') {
            throw new Error('Invalid content type in memory: expected object, got string');
        }
        const userAddress = content.userAddress;
        if (!userAddress || typeof userAddress !== 'string' || !ethers.isAddress(userAddress)) {
            throw new Error('Invalid or missing userAddress in memory.');
        }
        return true;
    }
    /**
     * Executes the liquidation transaction for a given user address.
     * @param runtime The agent runtime.
     * @param memory The memory object containing the userAddress.
     * @returns A promise that resolves to the transaction receipt.
     */
    async handler(runtime, memory) {
        const content = memory.content;
        if (typeof content === 'string') {
            throw new Error('Invalid content type in memory: expected object, got string');
        }
        const userAddress = content.userAddress;
        try {
            console.log(`Attempting to liquidate user: ${userAddress}`);
            const tx = await this.contract.liquidate(userAddress);
            const receipt = await tx.wait();
            console.log(`Successfully liquidated user ${userAddress}. Transaction hash: ${receipt.hash}`);
            return receipt;
        }
        catch (error) {
            console.error(`Failed to liquidate user ${userAddress}:`, error);
            throw error;
        }
    }
}
