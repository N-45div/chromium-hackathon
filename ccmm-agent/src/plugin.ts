import {
  type IAgentRuntime,
  type Memory,
  type Provider,
  type Action,
  type Plugin,
  logger,
  Service,
  type State,
} from '@elizaos/core';
import { getAddress, getAbiItem } from 'viem';
import { publicClient, walletClient } from './utils/evm.js';
import { AAVE_POOL_ABI, AAVE_POOL_ADDRESS } from './aave.js';
import CollManagement from '../../out/CollManagement.sol/CollManagement.json' with { type: 'json' };

const COLL_MANAGEMENT_ADDRESS =
  '0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389';
const COLL_MANAGEMENT_ABI = CollManagement.abi;

// --- Provider ---
const HealthFactorProvider: Provider = {
  name: 'HealthFactorProvider',
  description: 'Scans Aave V3 on Sepolia for users with a health factor below 1.',

  get: async (
    _runtime: IAgentRuntime,
    _memory: Memory,
    _state: State,
  ): Promise<Memory[]> => {
    if (!publicClient) {
      throw new Error('publicClient is not available');
    }

    const toBlock = await publicClient.getBlockNumber();
    const fromBlock = toBlock - 100n;

    const logs = await publicClient.getLogs({
      address: AAVE_POOL_ADDRESS,
      event: getAbiItem({
        abi: AAVE_POOL_ABI,
        name: 'Supply',
      }),
      fromBlock,
      toBlock,
    });

    const uniqueUsers = [...new Set(logs.map((log: any) => log.args.user))];
    const liquidatableUsers: Memory[] = [];

    for (const user of uniqueUsers) {
      if (!user) continue;
      try {
        const healthFactor = await publicClient.readContract({
          address: COLL_MANAGEMENT_ADDRESS,
          abi: COLL_MANAGEMENT_ABI,
          functionName: 'getHealthFactor',
          args: [getAddress(user)],
        });

        if (healthFactor < 1n * 10n ** 18n) {
          const [collateralAssets, debtAssets] =
            await publicClient.readContract({
              address: COLL_MANAGEMENT_ADDRESS,
              abi: COLL_MANAGEMENT_ABI,
              functionName: 'getUserAssets',
              args: [getAddress(user)],
            });

          if (debtAssets.length > 0 && collateralAssets.length > 0) {
            const debtAsset = debtAssets[0];
            const collateralAsset = collateralAssets[0];

            const totalDebt = await publicClient.readContract({
              address: COLL_MANAGEMENT_ADDRESS,
              abi: COLL_MANAGEMENT_ABI,
              functionName: 'userDebt',
              args: [getAddress(user), getAddress(debtAsset)],
            });

            const debtToCover = totalDebt / 2n;

            if (debtToCover > 0) {
              const memory = {
                content: `User ${user} has a cross-chain health factor of ${healthFactor}.`,
                values: {
                  user,
                  healthFactor: healthFactor.toString(),
                  collateralAsset,
                  debtAsset,
                  debtToCover: debtToCover.toString(),
                },
              };
              liquidatableUsers.push(memory as unknown as Memory);
            }
          }
        }
      } catch (e) {
        logger.error('error getting user account data', e);
      }
    }
    return liquidatableUsers;
  },
};

// --- Actions ---
const DepositCollateralAction: Action = {
  name: 'DepositCollateralAction',
  description: 'Deposits collateral to the CollManagement contract.',

  validate: async (_runtime: IAgentRuntime, message: Memory): Promise<boolean> => {
    const { collateralToken, amount, recipient } = (message as any).values;
    const isValid = !!collateralToken && !!amount && !!recipient;
    logger.info(`[DepositCollateralAction] Validating deposit job. Is valid: ${isValid}`);
    return isValid;
  },

  handler: async (_runtime: IAgentRuntime, memory: Memory): Promise<void> => {
    if (!walletClient || !walletClient.account) {
      throw new Error(
        'walletClient is not available, check if EVM_PRIVATE_KEY is set',
      );
    }
    const { collateralToken, amount, recipient } = (memory as any).values;
    logger.info(
      `depositing ${amount} of ${collateralToken} for recipient ${recipient}`,
    );

    const tx = await walletClient.writeContract({
      address: COLL_MANAGEMENT_ADDRESS as `0x${string}`,
      abi: COLL_MANAGEMENT_ABI,
      functionName: 'depositCollateral',
      args: [
        getAddress(collateralToken as string),
        BigInt(amount as string),
        getAddress(recipient as string),
      ],
      value: 1n * 10n ** 18n, // 1 ETH for gas fees
    });

    logger.info('deposit collateral tx hash', tx);
  },
};
const LiquidateAction: Action = {
  name: 'LiquidateAction',
  description: 'Liquidates positions that are below the health factor threshold.',

  validate: async (_runtime: IAgentRuntime, message: Memory): Promise<boolean> => {
    const { user, collateralAsset, debtAsset, debtToCover } = (message as any).values;
    const isValid = !!user && !!collateralAsset && !!debtAsset && !!debtToCover;
    logger.info(`[LiquidateAction] Validating liquidation job for user ${user}. Is valid: ${isValid}`);
    return isValid;
  },

  handler: async (_runtime: IAgentRuntime, memory: Memory): Promise<void> => {
    if (!walletClient || !walletClient.account) {
      throw new Error(
        'walletClient is not available, check if EVM_PRIVATE_KEY is set',
      );
    }
    const { user, collateralAsset, debtAsset, debtToCover } = (memory as any).values;
    logger.info(
      `liquidating user ${user} with debt ${debtToCover} of ${debtAsset}`,
    );

    const tx = await walletClient.writeContract({
      address: COLL_MANAGEMENT_ADDRESS as `0x${string}`,
      abi: COLL_MANAGEMENT_ABI,
      functionName: 'liquidationCall',
      args: [
        getAddress(collateralAsset as string),
        getAddress(debtAsset as string),
        getAddress(user as string),
        BigInt(debtToCover as string),
        false,
      ],
    });

    logger.info('liquidation tx hash', tx);
  },
};

// --- Service for periodic checks ---
class LiquidationService extends Service {
  static serviceType = 'liquidation-service';
  capabilityDescription = 'Periodically checks for liquidatable positions on Aave V3 and executes liquidations.';
  private intervalId: NodeJS.Timeout | null = null;

  constructor(runtime: IAgentRuntime) {
    super(runtime);
  }

  async start() {
    logger.info('*** Starting Liquidation Service ***');
    this.intervalId = setInterval(async () => {
      logger.info('[LiquidationService] Running scheduled health factor check...');
      try {
        const memories = await HealthFactorProvider.get(this.runtime, {} as Memory, {} as State);
        if (Array.isArray(memories) && memories.length > 0) {
          logger.info(`[LiquidationService] Provider found ${memories.length} memories to process.`);
          for (const memory of memories) {
            if (await LiquidateAction.validate(this.runtime, memory)) {
              await LiquidateAction.handler(this.runtime, memory);
            }
          }
        }
      } catch (error) {
        logger.error('[LiquidationService] Error during scheduled check:', error);
      }
    }, 60 * 1000); // Every 60 seconds
  }

  async stop() {
    logger.info('*** Stopping Liquidation Service ***');
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }
}

// --- Plugin ---
const plugin: Plugin = {
  name: 'ccmm-liquidation-plugin',
  description: 'A plugin to monitor and liquidate Aave V3 positions.',
  providers: [HealthFactorProvider],
  actions: [DepositCollateralAction, LiquidateAction],
  services: [LiquidationService],
};

export default plugin;
