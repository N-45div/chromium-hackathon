# AI Liquidation Monitor Agent
import os
import json
import time
from web3 import Web3
from eth_account import Account
from dotenv import load_dotenv

# --- CONFIGURATION ---
load_dotenv()

SOURCE_CHAIN_RPC_URL = os.getenv("SOURCE_CHAIN_RPC_URL")
LIQUIDATOR_PRIVATE_KEY = os.getenv("LIQUIDATOR_PRIVATE_KEY")
COLL_MANAGEMENT_CONTRACT_ADDRESS = os.getenv("COLL_MANAGEMENT_CONTRACT_ADDRESS")

# Check for required environment variables
if not all([SOURCE_CHAIN_RPC_URL, LIQUIDATOR_PRIVATE_KEY, COLL_MANAGEMENT_CONTRACT_ADDRESS]):
    raise ValueError("One or more required environment variables are missing.")

# --- LOAD CONTRACT ABI ---
def load_abi(filepath):
    with open(filepath, 'r') as f:
        artifact = json.load(f)
    return artifact['abi']

# --- CORE LOGIC ---
def get_liquidatable_positions(contract):
    """Queries the contract for all depositors and checks their health factor."""
    print("Fetching all depositor positions...")
    liquidatable_accounts = []
    all_depositors = contract.functions.getDepositors().call()

    if not all_depositors:
        print("No depositors found.")
        return []

    print(f"Found {len(all_depositors)} depositors. Checking each position...")
    for account in all_depositors:
        is_underwater = contract.functions.isLiquidatable(account).call()
        if is_underwater:
            print(f"Account {account} is under-collateralized and can be liquidated.")
            liquidatable_accounts.append(account)
    
    return liquidatable_accounts

def liquidate_position(w3, contract, private_key, account_to_liquidate):
    """Triggers the liquidation for a specific account."""
    try:
        print(f"Attempting to liquidate {account_to_liquidate}...")
        liquidator_account = Account.from_key(private_key)
        
        # Get the collateral token address from the contract
        collateral_token = contract.functions.supportedCollateralToken().call()

        # Build the transaction
        tx = contract.functions.liquidateCollateral(
            collateral_token,
            account_to_liquidate
        ).build_transaction({
            'from': liquidator_account.address,
            'nonce': w3.eth.get_transaction_count(liquidator_account.address),
            'gas': 2000000, # You may need to adjust this
            'gasPrice': w3.eth.gas_price
        })

        # Sign the transaction
        signed_tx = w3.eth.account.sign_transaction(tx, private_key=private_key)

        # Send the transaction
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        print(f"Liquidation transaction sent. Waiting for receipt... Tx Hash: {tx_hash.hex()}")

        # Wait for the transaction to be mined
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        print(f"Liquidation successful! Tx Receipt: {tx_receipt}")
        
        return tx_hash.hex()
    except Exception as e:
        print(f"Error liquidating position for {account_to_liquidate}: {e}")
        return None

def main():
    """Main monitoring loop for the liquidation agent."""
    print("Initializing AI Liquidation Monitor Agent...")

    # 1. Connect to the blockchain
    web3 = Web3(Web3.HTTPProvider(SOURCE_CHAIN_RPC_URL))
    if not web3.is_connected():
        raise ConnectionError("Failed to connect to the Ethereum node.")
    print(f"Successfully connected to chain ID: {web3.eth.chain_id}")

    # 2. Load ABI and instantiate contract
    abi_path = "../out/CollManagement.sol/CollManagement.json"
    coll_management_abi = load_abi(abi_path)
    coll_management_contract = web3.eth.contract(
        address=COLL_MANAGEMENT_CONTRACT_ADDRESS,
        abi=coll_management_abi
    )
    print(f"Contract loaded at address: {coll_management_contract.address}")

    # 3. Main monitoring loop
    while True:
        try:
            positions = get_liquidatable_positions(coll_management_contract)
            if positions:
                for account in positions:
                    tx_hash = liquidate_position(web3, coll_management_contract, LIQUIDATOR_PRIVATE_KEY, account)
                    if tx_hash:
                        print(f"Liquidation successful for account {account}. Tx Hash: {tx_hash}")
            else:
                print("No positions to liquidate.")
            
            # Wait for 60 seconds before the next check
            time.sleep(60)

        except Exception as e:
            print(f"An error occurred: {e}")
            # Wait longer before retrying if an error occurs
            time.sleep(300)

if __name__ == "__main__":
    main()
