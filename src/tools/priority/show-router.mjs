#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');
const routerPath = path.join(repoRoot, 'tests', 'results', '_agent', 'issue', 'router.json');

function printUsage(code = 0) {
  console.log('Usage: npm run priority:show [--json] [--limit <n>]');
  console.log('       Summarise the cached standing-priority router. Run priority:sync first.');
  process.exit(code);
}

function loadRouter() {
  if (!fs.existsSync(routerPath)) {
    throw new Error(
      `Router snapshot not found at ${routerPath}. Run \"npm run priority:sync\" first.`
    );
  }
  try {
    const raw = fs.readFileSync(routerPath, 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    throw new Error(`Failed to parse router JSON: ${error.message}`);
  }
}

function normaliseLimit(value, fallback) {
  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

(function main() {
  const args = process.argv.slice(2);
  let showJson = false;
  let limit = 10;

  for (let i = 0; i < args.length; i += 1) {
    const token = args[i];
    if (token === '--help' || token === '-h') {
      printUsage(0);
    } else if (token === '--json') {
      showJson = true;
    } else if (token === '--limit') {
      if (i + 1 >= args.length) {
        throw new Error('--limit requires a value');
      }
      limit = normaliseLimit(args[i + 1], limit);
      i += 1;
    } else {
      throw new Error(`Unknown argument: ${token}`);
    }
  }

  const router = loadRouter();
  if (showJson) {
    console.log(JSON.stringify(router, null, 2));
    return;
  }

  const actions = Array.isArray(router.actions) ? router.actions : [];
  console.log('[priority:show] Standing priority router snapshot');
  console.log(`  issue    : #${router.issue ?? 'n/a'}`);
  console.log(`  updated  : ${router.updatedAt ?? 'n/a'}`);
  console.log(`  actions  : ${actions.length}`);

  if (actions.length === 0) {
    return;
  }

  const preview = actions.slice(0, Math.min(limit, actions.length));
  const rows = preview.map((action, index) => {
    const scripts = Array.isArray(action.scripts) ? action.scripts : [];
    return {
      index: String(index + 1).padStart(3, ' '),
      key: action.key ?? '(unknown)',
      priority: Number.isFinite(action.priority) ? action.priority : 'n/a',
      script: scripts[0] ?? '(none)'
    };
  });

  console.log('  preview  :');
  for (const row of rows) {
    console.log(`    ${row.index}. [p=${row.priority}] ${row.key}`);
    console.log(`         -> ${row.script}`);
  }

  if (actions.length > preview.length) {
    console.log(`    … ${actions.length - preview.length} more action(s)`);
  }
})();
