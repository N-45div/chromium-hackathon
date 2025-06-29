import { ethers, Contract } from 'ethers';
// We will need the ABI of the CollManagement contract to interact with it.
// For now, we'll use a placeholder.
const COLL_MANAGEMENT_ABI = [
    "function getHealthFactor(address user) external view returns (uint256)"
];
export class HealthFactorProvider {
    config;
    name = HealthFactorProvider.name;
    contract;
    ethProvider;
    constructor(config) {
        this.config = config;
        this.ethProvider = new ethers.JsonRpcProvider(config.rpcUrl);
        this.contract = new Contract(config.contractAddress, COLL_MANAGEMENT_ABI, this.ethProvider);
    }
    /**
     * Generic getter required by the Provider interface.
     */
    async get(...args) {
        // We'll assume the first arg is the user address for getHealthFactor
        if (typeof args[0] === 'string') {
            return this.getHealthFactor(args[0]);
        }
        throw new Error('Invalid arguments for HealthFactorProvider.get');
    }
    /**
     * Fetches the health factor for a given user address.
     * @param userAddress The address of the user to check.
     * @returns A promise that resolves to the user's health factor as a BigInt.
     */
    async getHealthFactor(userAddress) {
        try {
            const healthFactor = await this.contract.getHealthFactor(userAddress);
            console.log(`Health factor for ${userAddress}: ${healthFactor.toString()}`);
            return healthFactor;
        }
        catch (error) {
            console.error(`Failed to get health factor for ${userAddress}:`, error);
            throw error;
        }
    }
    // Required by the abstract Provider class
    async start() {
        console.log('HealthFactorProvider started.');
    }
    async stop() {
        console.log('HealthFactorProvider stopped.');
    }
}
