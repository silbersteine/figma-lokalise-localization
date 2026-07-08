# Figma ↔ Lokalise Localization Skill

A Claude **Skill** that localizes Figma designs through Lokalise at the design
stage — push new copy to Lokalise as keys, generate translated preview pages,
catch stale/drifted text, and pull reviewed translations back into Figma.

## Get started (2 minutes, no code)

1. **Download the skill:**
   [figma-lokalise-localization.zip](../../releases/latest/download/figma-lokalise-localization.zip)
   — always matches the latest version on `main`.
2. In Claude (claude.ai or Claude Desktop), go to **Settings → Capabilities →
   Skills → Upload skill** and upload the zip as-is.
3. Connect the **Figma** and **Lokalise** MCP connectors — the skill needs
   both to actually read/write your file. See
   [`docs/mcp-setup.md`](docs/mcp-setup.md) if you're not sure how.

That's it. Open a Figma file, tell Claude what you want (e.g. "set up
localization for this file"), and it takes it from there.

## What it does

| Flow | Intent |
| --- | --- |
| `setup` | One-time config: Lokalise project, languages, key naming, tags (stored in the Figma file itself) |
| `sync` | Push new/changed Figma text to Lokalise as keys (dry-run first) |
| `download` | Generate translated preview copies as new Figma pages |
| `check-stale` | Read-only drift + translation-coverage report |
| `update-source` | Pull reviewed copy from Lokalise back into Figma source |

No external datastore is required: all config and per-node link state live in
the Figma file's plugin data, so the skill can self-orient from the file alone.

## Other agents

The skill is plain `SKILL.md` + Markdown, so anything that can read files and
call the Figma/Lokalise MCP tools can run it — Claude Code, Cursor, and other
`AGENTS.md`-aware agents, not just claude.ai.

```bash
# Claude Code (user-level)
cp -r skills/figma-lokalise-localization ~/.claude/skills/

# Cursor (project-level)
cp -r skills/figma-lokalise-localization .cursor/skills/
```

For agents that read `AGENTS.md`, this repo's root [`AGENTS.md`](AGENTS.md)
points them at the skill. For a one-off paste into any chat that can't load
skills or files at all, use [`docs/prompt-snippet.md`](docs/prompt-snippet.md).

## Repo layout

```
skills/figma-lokalise-localization/   canonical skill — the single source of truth
  SKILL.md            router + safety model (entry point; has the frontmatter)
  reference.md        storage contract, field mapping, Plugin-API snippets, rules
  known-limitations.md honest list of what the MCP tooling can't do yet
  flows/              one file per flow (setup, sync, download, check-stale, update-source)
AGENTS.md             cross-provider router (agents.md standard)
docs/                 MCP setup, governance, paste-in fallback
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
