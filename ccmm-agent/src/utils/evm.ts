import {
  createPublicClient,
  createWalletClient,
  http,
  HttpTransport,
  WalletClient,
} from 'viem';
import { privateKeyToAccount, PrivateKeyAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';

const { EVM_PROVIDER_URL, EVM_PRIVATE_KEY } = process.env;

if (!EVM_PROVIDER_URL || !EVM_PRIVATE_KEY) {
  throw new Error('Missing required environment variables for EVM client initialization.');
}

export const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(EVM_PROVIDER_URL),
});

const account = privateKeyToAccount(EVM_PRIVATE_KEY as `0x${string}`);

export const walletClient: WalletClient<
  HttpTransport,
  typeof sepolia,
  PrivateKeyAccount
> = createWalletClient({
  account,
  chain: sepolia,
  transport: http(EVM_PROVIDER_URL),
});
