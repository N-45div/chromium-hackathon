// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title FunctionsTrigger
 * @notice Monitors borrower health by triggering a Chainlink Function and emits events for liquidation candidates.
 * @dev This contract is called by Chainlink Automation. It does NOT perform liquidations itself.
 */
contract FunctionsTrigger is FunctionsClient, ConfirmedOwner, AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;

    // Event to announce a liquidation candidate
    event LiquidationCandidateFound(address indexed user);

    // State variables to store the latest request data for debugging
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Off-chain script configuration
    string public s_rpcUrl;
    string public s_contractAddress;
    string public s_borrowers;

    // Custom event to log the request ID returned by _sendRequest
    event RequestTriggered(bytes32 indexed requestId);

    // Custom event to trace execution flow
    event UpkeepCheckStarted();

    // Chainlink Functions configuration
    bytes32 private s_donId;
    uint64 private s_subscriptionId;
    uint32 private s_gasLimit;

    /**
     * @param _router The address of the Chainlink Functions router.
     * @param _donId The ID of the DON to use.
     * @param _subscriptionId The ID of the Functions billing subscription.
     * @param _gasLimit The gas limit for the Functions callback.
     */
    constructor(
        address _router,
        bytes32 _donId,
        uint64 _subscriptionId,
        uint32 _gasLimit
    ) FunctionsClient(_router) ConfirmedOwner(msg.sender) {
        s_donId = _donId;
        s_subscriptionId = _subscriptionId;
        s_gasLimit = _gasLimit;
    }

    function setConfig(string memory rpcUrl, string memory contractAddress, string memory borrowers) external onlyOwner {
        s_rpcUrl = rpcUrl;
        s_contractAddress = contractAddress;
        s_borrowers = borrowers;
    }

    /**
     * @notice Triggers the Chainlink Function to check positions.
     * @param source The JavaScript source code of the Function.
     * @param args The arguments to pass to the Function.
     * @return requestId The ID of the Functions request.
     */
    function triggerCheck(
        string calldata source,
        string[] calldata args
    ) public returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        if (args.length > 0) {
            req.setArgs(args);
        }

        requestId = _sendRequest(req.encodeCBOR(), s_subscriptionId, s_gasLimit, s_donId);
        require(requestId != bytes32(0), "Functions Request ID is zero");
        s_lastRequestId = requestId;
        emit RequestTriggered(requestId);
        return requestId;
    }

    /**
     * @notice The callback function that receives the response from the Chainlink Function.
     * @dev This function decodes the list of addresses and emits an event for each liquidation candidate.
     * @param _requestId The ID of the request.
     * @param _response The response from the Function, expected to be an abi-encoded address[].
     * @param _err Any error that occurred.
     */
    function fulfillRequest(
        bytes32 _requestId,
        bytes memory _response,
        bytes memory _err
    ) internal override {
        s_lastResponse = _response;
        s_lastError = _err;

        if (_err.length > 0) {
            // If the Functions request returns an error, we do not proceed.
            return;
        }

        // Decode the response which is expected to be an array of addresses.
        address[] memory candidates = abi.decode(_response, (address[]));

        // Loop through the addresses and emit an event for each candidate.
        for (uint i = 0; i < candidates.length; i++) {
            emit LiquidationCandidateFound(candidates[i]);
        }
    }

    // --- Automation Functions ---

    /**
     * @notice Called by the Chainlink Automation network to check if the upkeep needs to be performed.
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        performData = abi.encode("");
    }

    /**
     * @notice Called by the Chainlink Automation network to perform the upkeep.
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        emit UpkeepCheckStarted();
        string[] memory args = new string[](3);
        args[0] = s_rpcUrl;
        args[1] = s_contractAddress;
        args[2] = s_borrowers;

        this.triggerCheck(
            "(async () => { const { ethers } = await import('ethers'); const [rpcUrl, contractAddress, borrowers] = args; const collManagementAbi = ['function getHealthFactor(address user) external view returns (uint256)']; const provider = new ethers.JsonRpcProvider(rpcUrl); const contract = new ethers.Contract(contractAddress, collManagementAbi, provider); const healthFactorThreshold = ethers.parseEther('1.0'); const borrowerList = borrowers.split(','); const toLiquidate = []; console.log(`Checking health for ${borrowerList.length} borrowers...`); for (const borrowerAddress of borrowerList) { try { const healthFactor = await contract.getHealthFactor(borrowerAddress); console.log(`- ${borrowerAddress}: ${ethers.formatEther(healthFactor)}`); if (healthFactor < healthFactorThreshold) { toLiquidate.push(borrowerAddress); } } catch (error) { const errorMessage = error instanceof Error ? error.message : String(error); console.error(`  > Error checking health for ${borrowerAddress}:`, errorMessage); } } console.log(`Found ${toLiquidate.length} positions to liquidate.`); const encoded = ethers.AbiCoder.defaultAbiCoder().encode(['address[]'], [toLiquidate]); return Buffer.from(encoded.slice(2), 'hex'); })();",
            args
        );
    }
}
