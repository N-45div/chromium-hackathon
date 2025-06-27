import { type Project, type ProjectAgent } from '@elizaos/core';
import liquidationPlugin from './plugin.js';
import character from './character.json' with { type: 'json' };
export const projectAgent: ProjectAgent = {
  character,
  plugins: [liquidationPlugin],
};
const project: Project = {
  agents: [projectAgent],
};


export default project;
