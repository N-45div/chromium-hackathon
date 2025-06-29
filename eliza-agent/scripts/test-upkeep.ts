import { ethers } from "ethers";
import "dotenv/config";
import FunctionsTriggerArtifact from "../artifacts/contracts/FunctionsTrigger.sol/FunctionsTrigger.json" with { type: "json" };

async function main() {
  const contractAddress = '0x80d5B6980f27529c2926bEc166d69fA19609b336';

  // Using a local Hardhat node that is forking Sepolia
  const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545/');

  // Use a signer from the Hardhat node (the first one is usually available)
  const signer = await provider.getSigner();

  const functionsTrigger = new ethers.Contract(
    contractAddress,
    FunctionsTriggerArtifact.abi,
    signer
  );

  console.log(`Calling performUpkeep on contract: ${contractAddress}...`);

  try {
    // Get the current fee data from the network
    const feeData = await provider.getFeeData();

    const tx = await functionsTrigger.performUpkeep("0x", {
      maxFeePerGas: feeData.maxFeePerGas,
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
    });
    console.log("Transaction sent, waiting for receipt...");
    const receipt = await tx.wait();
    console.log("✅ Transaction successful!");
    console.log("Receipt:", receipt);

    // Check for our custom events
    let upkeepStarted = false;
    let triggeredRequestId = null;

    for (const log of receipt.logs || []) {
        try {
            const parsedLog = functionsTrigger.interface.parseLog(log as any);
            if (parsedLog?.name === 'UpkeepCheckStarted') {
                upkeepStarted = true;
            }
            if (parsedLog?.name === 'RequestTriggered') {
                triggeredRequestId = parsedLog.args.requestId;
            }
        } catch (e) {
            // Not a log from our contract, ignore
        }
    }

    console.log("\n--- Execution Trace ---");
    console.log(`- UpkeepCheckStarted event found: ${upkeepStarted}`);
    console.log(`- RequestTriggered event found: ${!!triggeredRequestId}`);
    if (triggeredRequestId) {
        console.log(`- Request ID: ${triggeredRequestId}`);
    }
    console.log("-----------------------\n");

    if (upkeepStarted && !triggeredRequestId) {
        console.log("🚨 DIAGNOSIS: `performUpkeep` was called, but the `RequestTriggered` event was NOT emitted.");
        console.log("This confirms the problem is inside the `triggerCheck` function, likely within the inherited `_sendRequest` call.");
    } else if (triggeredRequestId === '0x0000000000000000000000000000000000000000000000000000000000000000') {
        console.log("🚨 DIAGNOSIS: The request ID is zero. The Chainlink Functions Router is not processing the request.");
        console.log("This is likely due to a service pause or issue on the Chainlink side. Please check their official channels.");
    }

  } catch (error) {
    console.error("\n❌ Transaction failed!");
    console.error(error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
