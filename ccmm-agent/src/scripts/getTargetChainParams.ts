import { createPublicClient, http } from 'viem';
import { sepolia } from 'viem/chains';
import * as dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env') });

const collManagementAbi = [
    {
        "type": "function",
        "name": "targetChainParams",
        "inputs": [
            {
                "name": "_collateralToken",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "chainSelector",
                "type": "uint64",
                "internalType": "uint64"
            },
            {
                "name": "borrowManagementContract",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    }
] as const;

const main = async () => {
    const publicClient = createPublicClient({
        chain: sepolia,
        transport: http(process.env.EVM_PROVIDER_URL)
    });

    const collManagementAddress = '0xd4aa953485eF4f1A916e42b9350Ab510f0920465';
    const collateralToken = '0x4FE11290797DC5Cc82F20B950C263B0A2aCb1764';

    const [chainSelector, borrowManagementContract] = await publicClient.readContract({
        address: collManagementAddress,
        abi: collManagementAbi,
        functionName: 'targetChainParams',
        args: [collateralToken]
    });

    console.log('Successfully read target chain parameters:');
    console.log(`  Chain Selector: ${chainSelector}`);
    console.log(`  Borrow Management Contract: ${borrowManagementContract}`);

    // Verification
    const expectedChainSelector = 14767482510784806043n;
    const expectedBorrowManagementContract = '0xae4E4BDdE6Eb2F040aB9d34EA74086b3a8311389';

    if (chainSelector === expectedChainSelector && borrowManagementContract.toLowerCase() === expectedBorrowManagementContract.toLowerCase()) {
        console.log('\nVerification successful! The contract state is correct.');
    } else {
        console.error('\nVerification failed! The contract state does not match the expected values.');
        console.error(`  Expected Chain Selector: ${expectedChainSelector}, Got: ${chainSelector}`);
        console.error(`  Expected Borrow Management Contract: ${expectedBorrowManagementContract}, Got: ${borrowManagementContract}`);
    }
};

main().catch(console.error);
