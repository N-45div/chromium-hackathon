
import { 
    ChainId, 
    getCCIPSVMConfig, 
    CHAIN_SELECTORS, 
    FeeTokenType as ConfigFeeTokenType 
} from '../../config';
import {
    executeCCIPScript,
    CCIPMessageConfig,
    fetchTokenDecimals,
    toOnChainAmount,
} from '../../svm/utils';
import { PublicKey } from '@solana/web3.js';

export async function performSvmToEvmTransfer(destinationChain: ChainId, token: string, amount: string, recipient: string): Promise<any> {
    const config = getCCIPSVMConfig(ChainId.SOLANA_DEVNET);
    const connection = config.connection;

    const tokenMintPublicKey = new PublicKey(token);
    const tokenDecimals = await fetchTokenDecimals(connection, tokenMintPublicKey, config.routerProgramId, console);

    // Convert human-readable amount to raw units
    let rawAmountString: string;
    const [integerPart, fractionalPart = ''] = amount.split('.');

    if (fractionalPart.length > tokenDecimals) {
        throw new Error(`Amount has more decimal places (${fractionalPart.length}) than the token supports (${tokenDecimals}).`);
    }

    rawAmountString = integerPart + fractionalPart.padEnd(tokenDecimals, '0');

    const rawAmount = toOnChainAmount(rawAmountString);

    const CCIP_MESSAGE_CONFIG: CCIPMessageConfig = {
        destinationChain: destinationChain,
        destinationChainSelector:
            CHAIN_SELECTORS[destinationChain].toString(),
        evmReceiverAddress: recipient,
        tokenAmounts: [
            {
                tokenMint: tokenMintPublicKey.toString(), 
                amount: rawAmount.toString(), 
            },
        ],
        feeToken: ConfigFeeTokenType.NATIVE, 
        messageData: "", 
        extraArgs: {
            gasLimit: 0, 
            allowOutOfOrderExecution: true, 
        },
    };

    const SCRIPT_CONFIG = {
        computeUnits: 1_400_000, 
        minSolRequired: 0.005, 
        defaultExtraArgs: {
            gasLimit: 0, 
            allowOutOfOrderExecution: true, 
        },
    };

    // We are not using command line options here, so we can pass an empty object.
    const cmdOptions = {};

    const result = await executeCCIPScript({
        scriptName: "token-transfer",
        usageName: "svm:token-transfer",
        messageConfig: CCIP_MESSAGE_CONFIG,
        scriptConfig: SCRIPT_CONFIG,
        cmdOptions: cmdOptions,
    });

    return result;
}
