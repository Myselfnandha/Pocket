---
trigger: model_decision
---

# Codebase Context Auto-Loader

For this workspace:
1. Injected `codebase-context-*` KI provides the index and recent patches at conversation start.
2. Inspect code and directory structures directly via `view_file` and `grep_search`. Read `.agents/codebase_summary.md` for directory overviews.
3. NEVER spawn background Python analyzer scripts. Access persistent KI and summary natively with zero overhead.
