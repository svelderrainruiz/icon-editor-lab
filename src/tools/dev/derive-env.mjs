#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');

const ENV_PREFIXES = [
  'LOCALCI_',
  'ICON_EDITOR_',
  'ICONEDITOR_',
  'LABVIEW_',
  'LABVIEWCLI_',
  'LV_',
  'VIPM_',
  'MIP_',
  'COMPAREVI_',
  'GCLI_',
  'DEV_MODE_'
];

const ENV_EXACT = new Set([
  'CI',
  'GITHUB_ACTIONS',
  'GITHUB_JOB',
  'GITHUB_REF',
  'GITHUB_SHA',
  'GITHUB_RUN_NUMBER',
  'GITHUB_RUN_ATTEMPT',
  'GITHUB_REPOSITORY',
  'GITHUB_WORKFLOW',
  'LABVIEW_PATH',
  'LABVIEWCLI_PATH'
]);

function runGit(args) {
  try {
    const result = spawnSync('git', args, {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    });
    if (result.status !== 0) {
      return null;
    }
    return result.stdout.trim();
  } catch {
    return null;
  }
}

function resolveCommand(command) {
  const exe = process.platform === 'win32' ? 'where' : 'which';
  try {
    const result = spawnSync(exe, [command], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    });
    if (result.status !== 0) {
      return null;
    }
    const line = result.stdout.split(/\r?\n/).find((entry) => entry.trim());
    return line ? line.trim() : null;
  } catch {
    return null;
  }
}

function collectEnvSnapshot() {
  const env = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (!value) continue;
    if (ENV_EXACT.has(key)) {
      env[key] = value;
      continue;
    }
    if (ENV_PREFIXES.some((prefix) => key.startsWith(prefix))) {
      env[key] = value;
    }
  }
  return env;
}

function detectNpmVersion() {
  const fromEnv = process.env.npm_version;
  if (fromEnv) {
    return fromEnv;
  }
  try {
    const probe = spawnSync('npm', ['-v'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    if (probe.status === 0) {
      return probe.stdout.trim();
    }
  } catch {
    /* noop */
  }
  return null;
}

function readPackageVersion() {
  const pkgPath = path.join(repoRoot, 'package.json');
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    return pkg.version ?? null;
  } catch {
    return null;
  }
}

const snapshot = {
  schema: 'icon-editor/derived-env@v1',
  generatedAt: new Date().toISOString(),
  repo: {
    root: repoRoot,
    branch: runGit(['rev-parse', '--abbrev-ref', 'HEAD']),
    commit: runGit(['rev-parse', 'HEAD']),
    describe: runGit(['describe', '--tags', '--always'])
  },
  runtime: {
    node: process.version,
    npm: detectNpmVersion(),
    platform: process.platform,
    arch: process.arch,
    release: os.release(),
    packageVersion: readPackageVersion()
  },
  tools: {
    git: resolveCommand('git'),
    pwsh: resolveCommand('pwsh'),
    gcli: resolveCommand('g-cli'),
    labviewcli: resolveCommand('labviewcli')
  },
  env: collectEnvSnapshot()
};

console.log(JSON.stringify(snapshot, null, 2));
