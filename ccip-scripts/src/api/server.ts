import express, { Request, Response } from 'express';
import cors from 'cors';
import { performSvmToEvmTransfer } from './transfer';
import { ChainId } from '../../config';

const app = express();
const port = 3001;

// Middleware to parse JSON bodies
app.use(express.json());
app.use(cors());

app.post('/api/svm-to-evm-transfer', async (req: Request, res: Response) => {
    const { destinationChain, token, amount, recipient } = req.body;

    if (!destinationChain || !token || !amount || !recipient) {
        return res.status(400).json({ error: 'Missing required parameters' });
    }

    try {
        // The destinationChain from the request should be a key of the ChainId enum.
        const destinationChainId = ChainId[destinationChain as keyof typeof ChainId];
        if (destinationChainId === undefined) {
            return res.status(400).json({ error: 'Invalid destination chain' });
        }

        const transferResult = await performSvmToEvmTransfer(destinationChainId, token, amount, recipient);

        res.status(200).json({
            message: 'SVM to EVM transfer initiated successfully',
            ...transferResult,
        });
    } catch (error) {
        console.error('Error performing SVM to EVM transfer:', error);
        res.status(500).json({ error: 'Failed to initiate transfer' });
    }
});


// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});