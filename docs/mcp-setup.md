# MCP setup

The skill's instructions are portable, but **execution requires two MCP servers**
connected in your agent's environment. This page is a checklist, not a substitute
for each vendor's current docs.

## What the skill calls

**Figma MCP**
- `use_figma` — runs JavaScript against the Figma Plugin API (all reads/writes of
  text, plugin data, and screens go through this).
- `get_metadata`, `get_screenshot`, `get_design_context` — read-only inspection.

**Lokalise MCP**
- `create_lokalise_keys`, `list_lokalise_keys`, `get_lokalise_key`
- `update_lokalise_key`, `bulk_update_lokalise_keys`
- project/language/task tools used by download and update-source.

## Connecting

Exact steps depend on the agent; the shape is the same everywhere:

1. **Authenticate** to Figma and Lokalise (OAuth or API token per each vendor).
2. **Register the MCP servers** with your agent:
   - Claude (claude.ai / desktop): add the Figma and Lokalise connectors.
   - Claude Code / Cursor / other: add each MCP server to the agent's MCP config
     (name, URL/command, auth) so its tools load.
3. **Verify** the tools appear: ask the agent to list available tools, or run a
   read-only call (e.g. `list_lokalise_keys` on a known project, `get_metadata`
   on a file).

## Graceful degradation

If one or both servers are missing, the skill should **plan, not execute**: it can
explain the flow, resolve key names, and draft the dry-run, but it must not claim
to have written anything. `check-stale`, `sync`, `download`, and `update-source`
all need live tools; say so plainly rather than pretending.

## Compatibility

The skill depends on the *shape* of these tools (parameters, return fields). If a
vendor changes a tool, expect to update the affected flow. Track known-good
versions in [`governance.md`](governance.md#compatibility-matrix).
