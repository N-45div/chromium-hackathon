(async () => {
    const { ethers } = await import('ethers');
    // The main logic of the script
    const [rpcUrl, contractAddress, borrowers] = args;
    if (!rpcUrl || !contractAddress || !borrowers) {
        throw new Error('Required arguments RPC_URL, CONTRACT_ADDRESS, or BORROWERS are not set.');
    }
    const collManagementAbi = ['function getHealthFactor(address user) external view returns (uint256)'];
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const contract = new ethers.Contract(contractAddress, collManagementAbi, provider);
    const healthFactorThreshold = ethers.parseEther('1.0');
    const borrowerList = borrowers.split(',');
    const toLiquidate = [];
    console.log(`Checking health for ${borrowerList.length} borrowers...`);
    for (const borrowerAddress of borrowerList) {
        try {
            const healthFactor = await contract.getHealthFactor(borrowerAddress);
            console.log(`- ${borrowerAddress}: ${ethers.formatEther(healthFactor)}`);
            if (healthFactor < healthFactorThreshold) {
                toLiquidate.push(borrowerAddress);
            }
        }
        catch (error) {
            const errorMessage = error instanceof Error ? error.message : String(error);
            console.error(`  > Error checking health for ${borrowerAddress}:`, errorMessage);
        }
    }
    console.log(`Found ${toLiquidate.length} positions to liquidate.`);
    const encoded = ethers.AbiCoder.defaultAbiCoder().encode(['address[]'], [toLiquidate]);
    return Buffer.from(encoded.slice(2), 'hex');
})();
export {};
