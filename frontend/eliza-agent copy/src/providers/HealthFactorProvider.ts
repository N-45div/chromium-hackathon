import { Provider } from '@elizaos/core';
import { ethers, Contract } from 'ethers';

// We will need the ABI of the CollManagement contract to interact with it.
// For now, we'll use a placeholder.
const COLL_MANAGEMENT_ABI = [
  "function getHealthFactor(address user) external view returns (uint256)"
];

export interface HealthFactorProviderConfig {
  rpcUrl: string;
  contractAddress: string;
}

export class HealthFactorProvider implements Provider {
  public readonly name = HealthFactorProvider.name;
  private contract: Contract;
  private ethProvider: ethers.JsonRpcProvider;

  constructor(private config: HealthFactorProviderConfig) {
    this.ethProvider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.contract = new Contract(config.contractAddress, COLL_MANAGEMENT_ABI, this.ethProvider);
  }

  /**
   * Generic getter required by the Provider interface.
   */
  async get<T>(...args: any[]): Promise<T> {
    // We'll assume the first arg is the user address for getHealthFactor
    if (typeof args[0] === 'string') {
      return this.getHealthFactor(args[0]) as Promise<T>;
    }
    throw new Error('Invalid arguments for HealthFactorProvider.get');
  }

  /**
   * Fetches the health factor for a given user address.
   * @param userAddress The address of the user to check.
   * @returns A promise that resolves to the user's health factor as a BigInt.
   */
  async getHealthFactor(userAddress: string): Promise<bigint> {
    try {
      const healthFactor = await this.contract.getHealthFactor(userAddress);
      console.log(`Health factor for ${userAddress}: ${healthFactor.toString()}`);
      return healthFactor;
    } catch (error) {
      console.error(`Failed to get health factor for ${userAddress}:`, error);
      throw error;
    }
  }

  // Required by the abstract Provider class
  public async start(): Promise<void> {
    console.log('HealthFactorProvider started.');
  }

  public async stop(): Promise<void> {
    console.log('HealthFactorProvider stopped.');
  }
}
