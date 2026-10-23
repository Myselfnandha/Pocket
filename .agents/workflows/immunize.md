---
description: "Check known anti-patterns and record lessons learned from bugs."
---

# /immunize — Mistake Immunization & Memory Protocol

$ARGUMENTS

## Purpose
Prevent recurring mistakes by checking known patterns before coding, and recording new rules when bugs are resolved.

## Operating Protocol

### 1. Pre-Action Check (Sweep Before Coding)
Before taking unfamiliar architectural actions:
1. Inspect `.agents/memory/patterns.json` for known anti-patterns and strategies.
2. Inspect `.agents-local/memory/patterns.json` (if exists) for project-specific traps.
3. Inspect `.agents/memory/gotchas.md` for platform and tool quirks.
4. Inspect `.agents/memory/decisions.md` to uphold past architectural commitments.

### 2. Post-Fix Learning (Auto-Distillation)
When a bug, test failure, or correction occurs:
1. **Identify Root Cause**: Determine exactly why the error occurred.
2. **Formulate Rule**: Write a single clear one-sentence rule.
3. **Persist Directly**:
   - Project-specific traps -> append to `.agents-local/memory/patterns.json`
   - Universal agent behavior -> append to `.agents/memory/patterns.json`
   - Platform gotchas -> append to `gotchas.md`
   - Architecture decisions -> append to `decisions.md`
4. Use format: `{"id": "P-NNN", "type": "anti"|"strategy", "category": "...", "rule": "..."}`.
5. Add `"universal": true` flag if the pattern applies across all projects.
6. Use native `replace_file_content` to write directly. Zero subprocess scripts.
