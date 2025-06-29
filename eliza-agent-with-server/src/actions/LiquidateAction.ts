import { Action, IAgentRuntime, Memory } from '@elizaos/core';
import { ethers, Contract, Wallet } from 'ethers';

// Placeholder ABI for the CollManagement contract's liquidate function.
const COLL_MANAGEMENT_ABI = [
  "function liquidate(address user) external"
];

export interface LiquidateActionConfig {
  rpcUrl: string;
  contractAddress: string;
  privateKey: string; // The private key of the account that will pay for gas.
}

export class LiquidateAction implements Action {
  public readonly name = LiquidateAction.name;
  public readonly description = 'Liquidates an undercollateralized user position on the CCMM protocol.';
  private contract: Contract;
  private wallet: Wallet;

  constructor(private config: LiquidateActionConfig) {
    const provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.wallet = new Wallet(config.privateKey, provider);
    this.contract = new Contract(config.contractAddress, COLL_MANAGEMENT_ABI, this.wallet);
  }

  /**
   * Validates the input payload for the liquidation action.
   * @param runtime The agent runtime.
   * @param memory The memory object containing the userAddress.
   */
  async validate(runtime: IAgentRuntime, memory: Memory): Promise<boolean> {
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
  async handler(runtime: IAgentRuntime, memory: Memory): Promise<any> {
    const content = memory.content;
    if (typeof content === 'string') {
      throw new Error('Invalid content type in memory: expected object, got string');
    }
    const userAddress = content.userAddress as string;
    try {
      console.log(`Attempting to liquidate user: ${userAddress}`);
      const tx = await this.contract.liquidate(userAddress);
      const receipt = await tx.wait();
      console.log(`Successfully liquidated user ${userAddress}. Transaction hash: ${receipt.hash}`);
      return receipt;
    } catch (error) {
      console.error(`Failed to liquidate user ${userAddress}:`, error);
      throw error;
    }
  }
}
