import { v4 as uuidv4 } from 'uuid';
import { HealthFactorProvider } from '../providers/HealthFactorProvider.js';
import { LiquidateAction } from '../actions/LiquidateAction.js';
export class LiquidationAgent {
    runtime;
    config;
    name = LiquidationAgent.name;
    bio = 'This agent monitors borrower health factors and liquidates positions that fall below a configured threshold.';
    createdAt = Date.now();
    updatedAt = Date.now();
    constructor(runtime, config) {
        this.runtime = runtime;
        this.config = config;
    }
    static async start(runtime, config) {
        console.log('Liquidation agent created.');
        const agent = new LiquidationAgent(runtime, config);
        return agent;
    }
    async checkPositions() {
        console.log('Checking borrower positions...');
        const healthProvider = this.runtime.providers.find(p => p.name === HealthFactorProvider.name);
        const liquidateAction = this.runtime.actions.find(a => a.name === LiquidateAction.name);
        if (!healthProvider || !liquidateAction) {
            console.error('Required provider or action not found in runtime.');
            return;
        }
        for (const borrowerAddress of this.config.borrowers) {
            try {
                const healthFactor = await healthProvider.getHealthFactor(borrowerAddress);
                if (healthFactor < this.config.healthFactorThreshold) {
                    console.log(`Health factor for ${borrowerAddress} is below threshold. Triggering liquidation.`);
                    const memory = {
                        id: uuidv4(),
                        agentId: uuidv4(), // Placeholder
                        entityId: uuidv4(), // Placeholder for entity ID
                        roomId: uuidv4(), // Placeholder for room ID
                        content: { userAddress: borrowerAddress },
                        createdAt: Date.now(),
                    };
                    await liquidateAction.handler(this.runtime, memory);
                }
                else {
                    console.log(`Position for ${borrowerAddress} is healthy.`);
                }
            }
            catch (error) {
                console.error(`Error processing position for ${borrowerAddress}:`, error);
            }
        }
    }
}
