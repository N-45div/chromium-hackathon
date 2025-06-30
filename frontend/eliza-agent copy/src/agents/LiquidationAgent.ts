import { Agent, IAgentRuntime, Memory } from '@elizaos/core';
import { v4 as uuidv4 } from 'uuid';
import { HealthFactorProvider, HealthFactorProviderConfig } from '../providers/HealthFactorProvider.js';
import { LiquidateAction, LiquidateActionConfig } from '../actions/LiquidateAction.js';

export interface LiquidationAgentConfig {
  healthFactorThreshold: bigint;
  // In a real scenario, we'd get this from an on-chain event or another provider.
  // For this example, we'll use a static list.
  borrowers: string[];
}

export class LiquidationAgent implements Agent {
  public readonly name = LiquidationAgent.name;
  public readonly bio = 'This agent monitors borrower health factors and liquidates positions that fall below a configured threshold.';
  public readonly createdAt = Date.now();
  public updatedAt = Date.now();

  constructor(private runtime: IAgentRuntime, private config: LiquidationAgentConfig) {}


  public static async start(runtime: IAgentRuntime, config: LiquidationAgentConfig): Promise<LiquidationAgent> {
    console.log('Liquidation agent created.');
    const agent = new LiquidationAgent(runtime, config);
    return agent;
  }

  public async checkPositions(): Promise<void> {
    console.log('Checking borrower positions...');
    const healthProvider = this.runtime.providers.find(p => p.name === HealthFactorProvider.name) as HealthFactorProvider;
    const liquidateAction = this.runtime.actions.find(a => a.name === LiquidateAction.name) as LiquidateAction;

    if (!healthProvider || !liquidateAction) {
      console.error('Required provider or action not found in runtime.');
      return;
    }

    for (const borrowerAddress of this.config.borrowers) {
      try {
        const healthFactor = await healthProvider.getHealthFactor(borrowerAddress);

        if (healthFactor < this.config.healthFactorThreshold) {
          console.log(`Health factor for ${borrowerAddress} is below threshold. Triggering liquidation.`);
          const memory: Memory = {
            id: uuidv4() as `${string}-${string}-${string}-${string}-${string}`,
            agentId: uuidv4() as `${string}-${string}-${string}-${string}-${string}`, // Placeholder
            entityId: uuidv4() as `${string}-${string}-${string}-${string}-${string}`, // Placeholder for entity ID
            roomId: uuidv4() as `${string}-${string}-${string}-${string}-${string}`, // Placeholder for room ID
            content: { userAddress: borrowerAddress },
            createdAt: Date.now(),
          };
          await liquidateAction.handler(this.runtime, memory);
        } else {
          console.log(`Position for ${borrowerAddress} is healthy.`);
        }
      } catch (error) {
        console.error(`Error processing position for ${borrowerAddress}:`, error);
      }
    }
  }


}
