import 'dotenv/config';
import { AgentRuntime } from '@elizaos/core';
import { AgentServer } from '@elizaos/server';
import { projectAgent } from '../index.js';

/**
 * This script is for local development and allows loading the agent
 * with a local plugin that is not published to npm.
 * It programmatically constructs and starts the agent using AgentServer.
 */
async function main() {
  console.log('Initializing agent runtime...');
  const runtime = new AgentRuntime(projectAgent);

  console.log('Initializing agent server...');
  const server = new AgentServer();

  console.log('Registering agent with server...');
  server.registerAgent(runtime);

  const port = Number(process.env.PORT) || 3000;
  console.log(`Starting server on port ${port}...`);

  await server.start(port);

  console.log(`Agent server started successfully on port ${port}`);
}

main().catch((err) => {
  console.error('Failed to start agent:', err);
  process.exit(1);
});
