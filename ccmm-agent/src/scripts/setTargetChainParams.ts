import { createWalletClient, http, publicActions } from 'viem';
import { sepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import * as dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env') });

// ABI for the CollManagement contract
const collManagementAbi = {
    "abi": [
        {
            "type": "function",
            "name": "setTargetChainParams",
            "inputs": [
                {
                    "name": "_collateralToken",
                    "type": "address",
                    "internalType": "address"
                },
                {
                    "name": "_chainSelector",
                    "type": "uint64",
                    "internalType": "uint64"
                },
                {
                    "name": "_borrowManagementContract",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        }
    ]
};

const main = async () => {
    const privateKey = process.env.EVM_PRIVATE_KEY;
    if (!privateKey) {
        throw new Error('EVM_PRIVATE_KEY not found in .env file');
    }

    const account = privateKeyToAccount(privateKey as `0x${string}`);

    const walletClient = createWalletClient({
        account,
        chain: sepolia,
        transport: http(process.env.EVM_PROVIDER_URL)
    }).extend(publicActions);

    const collManagementAddress = '0xd4aa953485eF4f1A916e42b9350Ab510f0920465';

    const txHash = await walletClient.writeContract({
        address: collManagementAddress,
        abi: collManagementAbi.abi,
        functionName: 'setTargetChainParams',
        args: [
            '0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764', // _collateralToken
            '14767482510784806043', // _chainSelector
            '0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389'  // _borrowManagementContract
        ],
        account: walletClient.account
    });

    console.log(`Transaction sent with hash: ${txHash}`);

    const receipt = await walletClient.waitForTransactionReceipt({ hash: txHash });

    console.log('Transaction confirmed. Receipt:', receipt);
};

main().catch(console.error);
