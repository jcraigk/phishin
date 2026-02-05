#!/usr/bin/env node
import * as esbuild from 'esbuild';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');

await esbuild.build({
  entryPoints: [path.join(projectRoot, 'node_modules/@modelcontextprotocol/ext-apps/dist/src/app-with-deps.js')],
  bundle: true,
  format: 'iife',
  globalName: 'McpExtApps',
  outfile: path.join(projectRoot, 'public/mcp-widgets/mcp-apps-sdk.js'),
  minify: true,
  target: ['es2020'],
  platform: 'browser',
});

console.log('MCP Apps SDK bundled successfully');
