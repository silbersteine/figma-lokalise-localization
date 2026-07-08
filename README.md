# Figma ↔ Lokalise Localization Skill

A portable **agent skill** that localizes Figma designs through Lokalise at the
design stage. Any AI agent that can read a `SKILL.md` and call the Figma and
Lokalise MCP tools can run it — Claude (claude.ai, Claude Code, API), Cursor,
and other `AGENTS.md`-aware tools.

The skill is a **router**: every run starts at
[`skills/figma-lokalise-localization/SKILL.md`](skills/figma-lokalise-localization/SKILL.md),
loads shared knowledge from `reference.md`, then follows exactly one flow under
`flows/`.

## What it does

| Flow | Intent |
| --- | --- |
| `setup` | One-time config: Lokalise project, languages, key naming, tags (stored in the Figma file itself) |
| `sync` | Push new/changed Figma text to Lokalise as keys (dry-run first) |
| `download` | Generate translated preview copies as new Figma pages |
| `check-stale` | Read-only drift + translation-coverage report |
| `update-source` | Pull reviewed copy from Lokalise back into Figma source |

## Prerequisites (the honest constraint)

Instructions travel anywhere; **execution needs two MCP servers connected** in
the agent's environment:

- **Figma MCP** — the `use_figma` tool (runs JS against the Figma Plugin API),
  plus `get_metadata` / `get_screenshot` / `get_design_context`.
- **Lokalise MCP** — `create_lokalise_keys`, `list_lokalise_keys`,
  `update_lokalise_key`, `bulk_update_lokalise_keys`, and related.

Without those tools the skill can still explain and plan, but cannot read or
write designs/keys. See [`docs/mcp-setup.md`](docs/mcp-setup.md).

No external datastore is required: all config and per-node link state live in the
Figma file's plugin data, so any agent can self-orient from the file alone.

## Install

Drop the skill folder into the agent's skills directory:

```bash
# Claude Code (user-level)
cp -r skills/figma-lokalise-localization ~/.claude/skills/

# Cursor (project-level)
cp -r skills/figma-lokalise-localization .cursor/skills/

# or use the helper
./scripts/install.sh claude   # or: cursor
```

For agents that read `AGENTS.md`, this repo's root [`AGENTS.md`](AGENTS.md)
points them at the skill. For a one-off paste into any chat, use
[`docs/prompt-snippet.md`](docs/prompt-snippet.md).

## Repo layout

```
skills/figma-lokalise-localization/   canonical skill — the single source of truth
  SKILL.md            router + safety model (entry point; has the frontmatter)
  reference.md        storage contract, field mapping, Plugin-API snippets, rules
  known-limitations.md honest list of what the MCP tooling can't do yet
  flows/              one file per flow (setup, sync, download, check-stale, update-source)
AGENTS.md             cross-provider router (agents.md standard)
docs/                 MCP setup, governance, paste-in fallback
scripts/install.sh    copy the skill into an agent's skills dir
```

**Editing rule:** change only files under `skills/…`. Everything else is
scaffolding around that source of truth.

## What deliberately stays out of this repo

- **Session / project artifacts** — key IDs, task IDs, one-off helper scripts
  (`*.mjs`), specific node IDs. Those belong to the *consuming* project, not the
  reusable skill. Enforced by [`.gitignore`](.gitignore).
- **Secrets / API tokens** — never committed; they belong in the agent's MCP
  configuration.
- **Per-file localization config** — lives in Figma plugin data, written by the
  `setup` flow, not in the skill.

## Contributing & versioning

See [`docs/governance.md`](docs/governance.md). Changes are semver-tracked in
[`CHANGELOG.md`](CHANGELOG.md); behavior changes to a flow are called out
separately from docs-only edits.

## License

[MIT](LICENSE) — confirm this fits your org before publishing (see the note in
the LICENSE file).
