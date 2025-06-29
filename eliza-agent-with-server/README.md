# Eliza Agent Setup Guide

This guide will walk you through setting up and running the `eliza-agent` locally to monitor user positions and health factors for the cross-chain lending protocol.

**Prerequisites:**

*   **Node.js:** Ensure you have Node.js (version 18 or higher) installed.
*   **Git:** Ensure you have Git installed.

---

**Step 1: Clone the Repository**

First, clone the project repository to your local machine.

```bash
git clone <your-repository-url>
cd eliza-agent
```

---

**Step 2: Install Dependencies**

Install all the necessary Node.js packages using `npm`.

```bash
npm install
```

---

**Step 3: Configure Environment Variables**

The agent requires a `.env` file to store sensitive information and configuration.

1.  **Create the file:** Make a copy of the example file and name it `.env`.

    ```bash
    cp .env.example .env
    ```

2.  **Edit the file:** Open the new `.env` file and fill in the following values:

    *   `RPC_URL`: The HTTP RPC endpoint for the **Sepolia** network. You can get one for free from services like [Infura](https://infura.io) or [Alchemy](https://www.alchemy.com).
    *   `CONTRACT_ADDRESS`: The deployed address of the `CollManagement` contract on Sepolia. You can find this in the `script/deploy.md` file. It should be `0x6605c95b59fC9cC3D4deF033ae9a950996CAAd4c`.
    *   `PRIVATE_KEY`: The private key of the wallet that will be used to read data from the blockchain. This does **not** need to be the deployer or a funded account; any basic wallet will work.
    *   `BORROWERS`: A comma-separated list of borrower addresses on the Fuji network that you want to monitor. For example: `0xccc7465bB0B21a37d01c7f079a23712086b2CA95`

---

**Step 4: Run the Agent**

Start the agent in development mode. This command will compile the TypeScript code and run the agent, watching for any file changes.

```bash
npm run dev
```

If successful, you should see output in your terminal indicating that the agent is running and has started monitoring the specified borrower addresses.

---

**Step 5: Frontend Integration**

The agent exposes an API that the frontend can use to get the health factor for a given user.

*   **API Endpoint:** The agent will start a local server. The main endpoint to fetch data will likely be `http://localhost:3000/health-factor?user=<borrower_address>`. (The exact port and endpoint can be confirmed by inspecting `src/index.ts`).
*   **Frontend Logic:** Your frontend developers will need to make a `GET` request to this endpoint, passing the borrower's address as a query parameter. The frontend can then display the returned health factor to the user.
