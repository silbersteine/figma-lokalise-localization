# Governance

How this skill is maintained so teams can adopt it with confidence.

## Single source of truth

The skill is **everything under `skills/figma-lokalise-localization/`**. Edit only
there. `README.md`, `AGENTS.md`, `docs/`, and `scripts/` are scaffolding around
that source — they describe or deliver the skill, they don't redefine it.

Avoid per-provider forks of the instructions. The `SKILL.md` + frontmatter format
is already portable across Claude and `AGENTS.md`-aware agents; a paste-in
fallback lives at [`prompt-snippet.md`](prompt-snippet.md). If a future provider
genuinely needs a different entry file, generate it from the canonical content —
don't hand-maintain a second copy.

## Versioning

Semantic versioning, tracked in [`../CHANGELOG.md`](../CHANGELOG.md). Pre-1.0:

- **minor** — a flow behaves differently, or the storage/reference contract changes
- **patch** — docs, clarity, examples; no change to what an agent does

Cut a GitHub Release per version tag so consumers can pin.

## Review

- `CODEOWNERS` gates changes to `skills/**`.
- The PR template asks whether a change is **behavior vs docs**, and whether it
  touches the **MCP compatibility** surface.

## What must stay out

- **Instance/session data** — key IDs, task IDs, node IDs, one-off helper scripts
  (`*.mjs`), screenshots of a specific project. These belong to the consuming
  project. A useful pattern discovered while localizing a real file goes into the
  skill *as a generalized rule*; the specific numbers do not.
- **Secrets** — tokens live in MCP config, never in the repo.
- **Per-file localization config** — Lokalise project, languages, naming — lives
  in Figma plugin data (written by the `setup` flow), not in the skill.

## Compatibility matrix

Record known-good MCP tool versions here as you validate them, so a broken flow
can be traced to a tool change.

| Skill version | Figma MCP | Lokalise MCP | Notes |
| --- | --- | --- | --- |
| _fill in_ | _fill in_ | _fill in_ | first validated combination |

## Adoption checklist for a new team

1. Connect Figma + Lokalise MCP (see [`mcp-setup.md`](mcp-setup.md)).
2. Install the skill (`scripts/install.sh`) or vendor it via submodule/subtree.
3. Run `setup` on a test Figma file; confirm config lands in plugin data.
4. Try `check-stale` (read-only) before any writing flow.
