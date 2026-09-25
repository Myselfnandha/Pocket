# 🛡️ ZeroGravity OS: Anti-Patterns Matrix & Known Gotchas

This document serves as the **Persistent Anti-Patterns Matrix** for OpenHuman and ZeroGravity OS.
Before taking any architectural, coding, or tooling action, the agent must sweep this matrix (Stage 1) to immunize itself against known failure modes.

---

## 📊 Anti-Patterns & Invariant Prevention Matrix

| ID | ⚠️ Mistake / Anti-Pattern | 🔍 Root Cause & Triggers | 🛡️ Invariant Prevention Strategy |
| :--- | :--- | :--- | :--- |
| **AP-001** | **Unchecked npx execution polluting JSON-RPC stdout with colored notices and ANSI escape sequences** | npx in modern npm writes colored notices to stdout when not silenced, breaking JSON-RPC parsing (invalid character '\x1b') | Always wrap Node-based MCP servers using mcp-npx with NO_COLOR=1, npm_config_loglevel=silent, and --silent flag |
| **AP-002** | **Sentry MCP server falling back to interactive OAuth device code flow and hanging** | @sentry/mcp-server defaults to interactive device code login if --access-token or SENTRY_ACCESS_TOKEN is omitted | Pass --access-token ${SENTRY_AUTH_TOKEN} explicitly in CLI arguments and provide environment fallback |
| **AP-003** | **Codebase indexer scanning self-extracting archive payload and inflating codebase database to 40MB+** | Scanning binary payloads or packed archive files in analyze.py treats binary blobs as source text | Exclude *.tar.gz, *.tar.xz, install.sh, and dist/ in codebase indexing routines |
| **AP-004** | **Leaving MCP servers running permanently in background consuming CPU and RAM** | Static mcp_config.json with default background servers creates memory bloat and port collisions | Zero-Default profile: start with empty mcpServers ({}), enable dynamically on-demand, and auto-close upon task completion |
| **AP-005** | **Agent looping over view_file sequentially to understand an entire folder codebase** | Sequential view_file calls waste context tokens and cause high latency | Execute analyze.py --check --auto-heal --inject-ki and read the consolidated codebase_summary.md in a single read |
| **AP-006** | **Refactoring code outside the user's requested scope** | Agent interprets adjacent code as needing improvement or unsolicited optimization. | Blast Radius Lock: Declare edit scope upfront; only edit within declared scope; flag out-of-scope issues as follow-up recommendations. |
| **AP-007** | **Claiming success without running verification commands** | Token-pressure or speed bias leads agent to skip test runs and pattern-match 'this looks right' or use speculative language. | Evidence Gate: Always run tests or re-read files, report actual terminal output, never say 'should work'. |
| **AP-008** | **Editing files based on stale cached memory instead of current on-disk state** | Files read early in long sessions get modified externally or by background tasks while agent remembers old lines. | Freshness Gate: Re-read target file if >5 tool calls since last read; run git status before multi-file edits. |
| **AP-009** | **Using invented library functions that don't exist in installed packages** | LLM hallucination on fast-moving libraries or niche frameworks where training memory contains plausible APIs. | Hallucination Guard: Verify every unfamiliar API symbol via tool inspection, REPL check, or docs before using. |

---

## 🛠️ Platform & Tooling Gotchas

### 1. Skylos SAST on Meta-Directories
- **Gotcha**: Scanning directories containing 1,450+ offline skill scripts causes slow traversal.
- **Rule**: Pass `--exclude .agents --exclude .agent --exclude venv` when running whole-project audits.

### 2. PEP 668 & Linux System Python Isolation
- **Gotcha**: Modern Linux distros (Arch, Debian 12+, Ubuntu 24+) block system-wide `pip install`.
- **Rule**: Provision isolated virtual environments under `~/.local/share/<tool>/venv` and symlink CLI entrypoints to `~/.local/bin/`.

### 3. NPM Remote Package Authorization (`EALLOWREMOTE`)
- **Gotcha**: npm v12+ defaults `allow-remote="none"`, failing to install git-based tarball dependencies.
- **Rule**: Configure `npm config set allow-remote all` during environment setup.

---

## 🔄 The 2-Way Immunization Protocol
1. **Pre-Action Check**: Before executing a tool call or creating a component, verify against this matrix.
2. **Post-Failure Distillation**: When a mistake, test failure, or user correction occurs:
   - Identify the exact root cause.
   - Formulate an Invariant Prevention Strategy.
   - Append to this matrix and `anti_patterns.json` via `zg learn add`.
