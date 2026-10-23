# ZeroGravity OS

Autonomous supercoding engine. Rules & skills load on-demand.
- Built-ins: /build-feature, /plan, /harness, /review, /ship, /skill, /mcp, /effort-<level>, /learn, /grill-me.
- Memory: .agents/memory/ (patterns.json, decisions, gotchas).
- Local Memory: .agents-local/memory/ (project-specific patterns; same format).
- Skills: .agents/skills-registry/ (load on-demand via view_file or /skill <name>).
- Gate: Never edit outside declared scope. Verify APIs before using. No success claims without evidence. Select optimal tool before every action.
- On first file edit: read .agents/memory/patterns.json and .agents-local/memory/patterns.json (if exists).
