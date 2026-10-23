#!/usr/bin/env node

/**
 * enforce-patterns.mjs — Mechanical enforcement of patterns from patterns.json
 * 
 * Hooks into PreToolUse for run_command, write_to_file, replace_file_content,
 * and multi_replace_file_content. Enforces rules that can be checked without
 * model context — zero tokens, 100% enforcement.
 * 
 * Exit 0 = allow, Exit 1 = block (with stderr message explaining why).
 */

import process from 'node:process';
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname, basename } from 'node:path';

// ─── Shell commands that duplicate native tool primitives ───────────────────
// P-012/P-014: "Never use generic shell when a primitive exists"
const SHELL_ANTI_PATTERNS = [
  {
    id: 'shell-grep',
    pattern: /(?:^|[;&|]\s*)(?:grep|egrep|fgrep|rg)\s+/,
    message: 'Use grep_search tool instead of shell grep/rg. Saves tokens and context.',
    except: /(?:git\s+grep|grep.*\|\s*wc|--count|npm|pip|cargo|flutter|apt|brew|dpkg)/
  },
  {
    id: 'shell-cat',
    pattern: /(?:^|[;&|]\s*)cat\s+(?!\/dev\/|<<)/,
    message: 'Use view_file tool instead of cat. Native tool is faster and token-efficient.',
    except: /(?:\|\s*(?:grep|wc|head|tail|sort|awk|sed|jq|python)|<<|\/dev\/)/
  },
  {
    id: 'shell-find-files',
    pattern: /(?:^|[;&|]\s*)find\s+.*-name\s+/,
    message: 'Use grep_search or list_dir instead of find. Native tools are faster.',
    except: /(?:-exec|-delete|xargs|\|\s*(?:wc|sort|head)|__pycache__|node_modules|\.git)/
  },
  {
    id: 'shell-sed-edit',
    pattern: /(?:^|[;&|]\s*)sed\s+-i/,
    message: 'Use replace_file_content instead of sed -i. Native tool is atomic and safer.',
    except: /(?:\.bak|--in-place)/
  }
];

// ─── Config files that should never be fully overwritten ────────────────────
// P-020: "Never overwrite user customizations in config files; merge or append"
const PROTECTED_CONFIGS = [
  '.gitignore',
  '.env',
  '.env.local',
  'mcp_config.json',
  'tsconfig.json',
  'pubspec.yaml',
  'Cargo.toml',
  'pyproject.toml',
  '.eslintrc',
  '.prettierrc'
];

// ─── Dependency install without verification ────────────────────────────────
// P-019: "Never add dependencies without checking if already installed"
const UNVERIFIED_INSTALL = [
  {
    id: 'npm-install-no-check',
    pattern: /(?:^|[;&|]\s*)npm\s+install\s+(?!-[gD])/,
    message: 'Check package.json before npm install to avoid adding already-installed deps.'
  },
  {
    id: 'pip-install-no-check',
    pattern: /(?:^|[;&|]\s*)pip3?\s+install\s+(?!-r\s|-e\s|--upgrade\s+pip)/,
    message: 'Check requirements.txt before pip install to avoid adding already-installed deps.'
  }
];

// ─────────────────────────────────────────────────────────────────────────────

function readStdin() {
  return new Promise((resolve, reject) => {
    let input = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', chunk => {
      input += chunk;
      if (input.length > 1024 * 1024) reject(new Error('payload exceeds 1 MiB'));
    });
    process.stdin.on('end', () => resolve(input));
    process.stdin.on('error', reject);
  });
}

function getArgs(payload) {
  return payload?.tool_args ?? payload?.toolArgs ?? payload?.arguments ?? {};
}

function getToolName(payload) {
  return (payload?.tool_name ?? payload?.toolName ?? payload?.tool ?? '').toLowerCase();
}

function firstString(...values) {
  for (const v of values) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
}

function extractCommand(payload) {
  const args = getArgs(payload);
  return firstString(args.CommandLine, args.commandLine, args.command, args.cmd);
}

function extractTargetFile(payload) {
  const args = getArgs(payload);
  return firstString(args.TargetFile, args.targetFile, args.target_file, args.AbsolutePath);
}

function checkRunCommand(payload) {
  const command = extractCommand(payload);
  if (!command) return null;

  // Check shell anti-patterns (P-012, P-014)
  for (const rule of SHELL_ANTI_PATTERNS) {
    if (rule.pattern.test(command) && (!rule.except || !rule.except.test(command))) {
      return { blocked: true, id: rule.id, message: rule.message };
    }
  }

  // Check unverified installs (P-019) — warn only, don't block
  for (const rule of UNVERIFIED_INSTALL) {
    if (rule.pattern.test(command)) {
      console.error(`⚠ AG Pattern Warning (${rule.id}): ${rule.message}`);
      // Don't block — just warn. The install might be intentional.
    }
  }

  return null;
}

function checkWriteFile(payload) {
  const targetFile = extractTargetFile(payload);
  if (!targetFile) return null;

  const args = getArgs(payload);
  const isOverwrite = args.Overwrite === true || args.overwrite === true;
  const fileName = basename(targetFile);

  // P-020: Don't overwrite config files
  if (isOverwrite && PROTECTED_CONFIGS.some(cfg => fileName === cfg || targetFile.endsWith(`/${cfg}`))) {
    return {
      blocked: true,
      id: 'config-overwrite',
      message: `Overwriting ${fileName} will destroy user customizations. Use replace_file_content to merge changes instead.`
    };
  }

  return null;
}

async function main() {
  let raw;
  try {
    raw = await readStdin();
  } catch (error) {
    console.error(`AG Pattern hook warning: ${error.message}`);
    return 0;
  }

  let payload;
  try {
    payload = JSON.parse(raw || '{}');
  } catch {
    console.error('AG Pattern hook: invalid JSON; allowing call.');
    return 0;
  }

  const tool = getToolName(payload);

  let result = null;

  if (tool === 'run_command') {
    result = checkRunCommand(payload);
  } else if (tool === 'write_to_file') {
    result = checkWriteFile(payload);
  }

  if (result?.blocked) {
    console.error(`BLOCKED by AG Pattern (${result.id}): ${result.message}`);
    return 1;
  }

  return 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exitCode = await main();
}
