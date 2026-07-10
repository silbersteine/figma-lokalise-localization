# Localize Figma designs through Lokalise

Design teams often need translated UI before engineering picks up strings. This
skill connects your Figma file to Lokalise so copy moves in both directions:
push source text as translation keys, preview translations in Figma, catch drift,
and pull reviewed copy back into the design.

Built for **designers who use Figma** and are early adopters of **MCP** (Model
Context Protocol). You may already use Lokalise, or be exploring it — either
way, this skill keeps design and translation in sync.

Treat this as a template: configure it once per file, then adapt the skill text
to match how your team uses Figma and Lokalise.

---

## Why localize through a TMS?

Ad-hoc translation — everyone running their own AI translator, copying strings
into spreadsheets, or pasting into separate tools — breaks down quickly on real
product work:

| Problem | With a TMS (Lokalise) |
| --- | --- |
| Different translations for the same string across screens | One key, one approved translation, reused everywhere |
| No review workflow | Linguists, legal, and brand review in a shared queue |
| Copy changes in Figma but nobody updates Lokalise (or vice versa) | Drift detection and structured sync flows |
| Engineering handoff is manual and error-prone | Stable keys and locales, ready for your codebase |

**Figma** is where layout and copy live. **Lokalise** is where languages,
reviewers, and translation memory live. **MCP** lets an AI agent call both as
tools instead of you switching apps. **This skill** tells the agent how to run
the workflow safely.

---

## How it works

Config and link state live **in the Figma file itself** (plugin data) — no
external database. Open the file in any supported agent and it can self-orient
from what's stored there.

```mermaid
flowchart LR
  A[Figma source] -->|setup once| B[Config in file]
  A -->|sync| C[Lokalise keys]
  C -->|translate in Lokalise| C
  C -->|download| D[Preview pages in Figma]
  A -->|check-stale| E[Drift report]
  C -->|update-source| A
```

| Flow | What you ask for | What happens |
| --- | --- | --- |
| **setup** | "Set up localization for this file" | Links file → Lokalise project, languages, key naming |
| **sync** | "Push this screen to Lokalise" | Creates/updates keys from Figma text (dry-run first) |
| **download** | "Generate German previews" | Clones frames/pages with translated text — source untouched |
| **check-stale** | "Is this up to date?" | Read-only: source drift + missing/outdated translations |
| **update-source** | "Pull reviewed copy from Lokalise" | Updates Figma source text (confirmed per change) |

**Safety:** `check-stale` is read-only. `sync`, `download`, and `update-source`
always confirm before writing — especially when overwriting source text.

---

## Metadata and design-to-code handoff

Every synced text node carries a **two-sided link**: lightweight state on the
Figma layer, rich context on the Lokalise key. That link is what makes the file
more than a pile of strings — it becomes a structured handoff surface from
design to engineering.

### What's stored on Figma text nodes

On sync, each linked text node gets **shared plugin data** (namespace
`lokalise`) written directly onto the layer:

| Field | Purpose |
| --- | --- |
| `keyName` | Stable key identifier (e.g. `checkout.summary.total_label`) |
| `keyId` | Lokalise key ID — the live link back to the TMS |
| `lastPushedAt` | When this node was last sent to Lokalise |
| `lastPushedContentHash` | Fingerprint of the source text at push time (drift detection) |
| `lastPushedContentKind` | `"html"` for rich text, plain otherwise |
| `lastPulledAt` / `lastPulledLang` | Set when a translation preview is written into a clone |

Screen frames carry rollups (`lastSyncedAt`, `lastSyncedKeyCount`). File-wide
config (project ID, languages, naming convention) lives on the document root.
Nothing external — open the file in Figma and the link state travels with it.

### What's stored in Lokalise (on each key)

When text is pushed, the skill creates or updates a Lokalise key with more than
just the string:

- **`key_name`** — the same stable name on the node; this is what engineering
  imports into code
- **`tags`** — screen, page, purpose (`heading`, `cta`, `nav_item`, `body`),
  component, and more — for filtering and automation in Lokalise
- **`context`** — machine-readable back-reference to the Figma node
- **`description`** — translator-facing notes
- **`custom_attributes`** — a JSON object with design facts, including:
  - Layer name and full layer path
  - Figma node ID, file key, and deep link URL
  - Parent frame, page name, component name
  - Font family, style, size; text box width and resize mode
  - Placeholder tokens (e.g. `{username}`) extracted from the source string
  - Content hash and push timestamp

See [`skills/figma-lokalise-localization/reference.md`](skills/figma-lokalise-localization/reference.md) for the full mapping.

### Using metadata for design → code handoff

Once keys exist, the pipeline from design to production code gets concrete:

1. **Stable key names** flow from Figma naming conventions → Lokalise → your
   i18n files (`checkout.summary.total_label` in both places)
2. **Figma deep links** on each key let engineers or codegen agents jump from a
   string in Lokalise straight to the exact text layer in the file
3. **Placeholder tokens** tell devs which strings are templates vs literals and
   what variables the UI expects
4. **Typography and layout hints** (font, width, auto-resize) flag strings that
   may truncate or need different treatment per locale
5. **Purpose tags** (`heading`, `cta`, …) help tooling pick the right HTML
   element or component variant in code

A codegen agent, CI export, or Lokalise file download can consume this metadata
without anyone re-entering context by hand.

### Go beyond translation metadata

The default skill focuses on localization, but **`custom_attributes` is an open
schema** — you can push whatever your team needs. Think big and customize the
skill to capture internationalization concerns that matter in your product:

- **Character or line limits** — "German will overflow this 120px button"
- **RTL / bidirectional text** — flag strings that need mirroring or special
  handling in Arabic or Hebrew
- **Plural and gender rules** — mark keys that need `{count}` variants or
  gendered copy in certain locales
- **Truncation risk** — note when a label sits in a fixed-width container
- **Legal / brand sensitivity** — tag copy that requires compliance review
- **Component-to-code mapping** — link a string to a React prop, SwiftUI key, or
  Code Connect component

To add fields, edit the skill's sync mapping (in
[`reference.md`](skills/figma-lokalise-localization/reference.md) for Claude /
Cursor, or [`figma-agent/SKILL.md`](figma-agent/SKILL.md) for Figma native) and
teach the agent when to populate them — from layer names, component properties,
designer annotations, or a checklist you define. The same pattern works for
**extra plugin data on Figma nodes** if you want state that never leaves the
file.

Translation metadata is the starting point. The skill is a template for any
metadata your design-to-code pipeline needs — you just need to describe it in
the skill and let the agent write it on sync.

---

Before any flow runs, you need:

1. A **Figma file** with the screens you want to localize
2. A **Lokalise project** (existing or create one in Lokalise)
3. **Agent access** to Figma and Lokalise — via MCP connectors or in-file tools,
   depending on which package you use (see below)

Connector setup: [`docs/mcp-setup.md`](docs/mcp-setup.md)

---

## Figma native AI skill

Use this if you work **inside Figma's in-product AI agent** (Figma Design or
Figma Make).

### What it does

A **single Markdown file** with everything the agent needs — setup, sync,
download, check-stale, and update-source — folded into one document. Figma's
agent can load one instructions file at a time, not a folder of reference docs.

Runs **inside Figma** using the Plugin API directly. You still need **Lokalise**
connected for key and translation work.

Also supports **plurals** and **rich text** (links, colored spans) on push and
download. See [`docs/governance.md`](docs/governance.md) for how this relates to
the Claude package.

### Download

From GitHub Releases (auto-built from `main`):

**[SKILL.md](https://github.com/silbersteine/figma-lokalise-localization/releases/latest/download/SKILL.md)**

Or clone this repo and use [`figma-agent/SKILL.md`](figma-agent/SKILL.md)
directly.

### Upload to Figma

1. Open Figma Design (or Make) and open the **AI chat** sidebar
2. Click the prompt box → **Skills** → **Add skill**
3. Drag in `SKILL.md` or click **Upload a file**
4. Review the name (`figma-lokalise-localization`) and description → **Add**
5. Invoke with `/figma-lokalise-localization` or describe your task in natural
   language

[Figma's custom skills guide →](https://help.figma.com/hc/en-us/articles/40283639496599-Custom-skills-for-the-Figma-agent-and-Figma-Make)

### Typical commands

**First time on a file**

```
/figma-lokalise-localization Set up localization for this file —
Lokalise project [name or ID], source English, targets de, fr, es
```

**After editing copy in Figma**

```
Push the selected screen to Lokalise — show me a dry run first
```

**Preview translations**

```
Download translations for German and French on this screen
```

**Before a review or handoff**

```
Check if this screen is stale — any drift or missing translations?
```

**Copy was reviewed in Lokalise**

```
Update the Figma source from Lokalise for the selected frame
```

---

## Claude package

Use this if you work in **Claude** (claude.ai, Claude Desktop, Claude Code) or
**Cursor** with MCP connectors.

### What it does

The **canonical multi-file skill** under `skills/figma-lokalise-localization/`:
a router plus reference docs and one file per flow. Designed for agents that can
read multiple files and call MCP tools.

Figma access goes through the **Figma MCP** (`use_figma`). Lokalise access goes
through the **Lokalise MCP**. This is the **source of truth** for behavior and
safety.

### Download

From GitHub Releases:

**[figma-lokalise-localization.zip](https://github.com/silbersteine/figma-lokalise-localization/releases/latest/download/figma-lokalise-localization.zip)**

Or clone this repo — no zip needed if the project includes it.

### Install

**Claude.ai / Claude Desktop (~2 minutes)**

1. Download the zip (link above)
2. **Settings → Capabilities → Skills → Upload skill** — upload the zip as-is
3. Connect the **Figma** and **Lokalise** MCP connectors
   ([`docs/mcp-setup.md`](docs/mcp-setup.md))

**Claude Code (user-level)**

```bash
cp -r skills/figma-lokalise-localization ~/.claude/skills/
```

**Cursor (project-level)**

```bash
cp -r skills/figma-lokalise-localization .cursor/skills/
```

For other agents that read `AGENTS.md`, the repo root file already points at the
skill.

### Typical commands

Natural language is enough — the skill routes from your intent:

| You say | Flow |
| --- | --- |
| "Configure Lokalise for this Figma file" | setup |
| "Create keys from this frame" / "Sync to Lokalise" | sync |
| "Make translated preview pages for Japanese" | download |
| "Did the source change since last sync?" | check-stale |
| "The copy was reviewed in Lokalise — update Figma" | update-source |

**Example session**

```
Here's my Figma file: https://figma.com/design/ABC123/...
Set up localization — project is "Mobile App UI", English source, German and French targets.

[after design edits]
Sync the Checkout screen to Lokalise. Show dry run before writing.

Generate German preview pages for Checkout.

Check stale on the whole file before we ship to translators.
```

If MCP isn't connected, the skill plans the work and tells you what's missing —
it won't claim to have written anything.

---

## Which one should I use?

| | **Figma native skill** | **Claude package** |
| --- | --- | --- |
| **Where you work** | Inside Figma's AI chat | Claude or Cursor |
| **Install** | Upload single `SKILL.md` | Upload zip or copy skill folder |
| **Figma access** | Plugin API in-file | Figma MCP |
| **Lokalise access** | Lokalise tool/API | Lokalise MCP |
| **Rich text / plurals** | Supported | Canonical catching up — see [CHANGELOG](CHANGELOG.md) |
| **Best for** | Designers who live in Figma | Teams on Claude/Cursor with MCP |

Both use the **same storage contract** in the Figma file — config written by one
path is visible to the other.

---

## Make it yours

This skill is a starting point, not a prescription. Every design team works
differently — component libraries, naming conventions, review rituals, which
frames count as "screens," how you use variants and auto-layout, whether copy
lives in components or loose text layers. The skill is meant to bend to *your*
workflow, not the other way around.

### What you can customize without touching code

When you run **setup**, you define defaults that every later flow respects:

- **Key naming** — e.g. `{screen}.{component}.{element}` vs your own pattern
- **Tags and platforms** — match how your org segments keys in Lokalise
- **Target languages** — only the locales you actually ship
- **Preview placement** — where translated clones land (one page per language,
  side by side, etc.)
- **Shared chrome** — nav, footers, and repeated UI that should map to one key
  across screens

Those choices live in the Figma file. Re-run setup anytime your conventions
evolve. For the full picture of what gets written onto nodes and into Lokalise,
see [Metadata and design-to-code handoff](#metadata-and-design-to-code-handoff)
above.

### Adapt the skill instructions

The skill files are plain Markdown — readable, editable, versionable:

| If you use… | Customize by… |
| --- | --- |
| **Figma native agent** | Edit [`figma-agent/SKILL.md`](figma-agent/SKILL.md) before upload — add your design-system rules, crit checklist, or Lokalise tagging policy |
| **Claude / Cursor** | Edit files under [`skills/figma-lokalise-localization/`](skills/figma-lokalise-localization/) — especially `reference.md` (naming, mapping) and individual flows under `flows/` |

Examples of adaptations teams often make:

- **Stricter key naming** — enforce your component naming from the design system
- **Extra metadata on push** — char limits, RTL flags, truncation notes, or any
  i18n consideration your engineers and translators need (see
  [Metadata and design-to-code handoff](#metadata-and-design-to-code-handoff))
- **Different preview layout** — match how your team reviews localized UI (e.g.
  always clone next to source)
- **Rich text and plurals** — the Figma-native skill already handles links,
  color spans, and plural forms; port or extend those patterns in the Claude
  package if you need them there too
- **Team-specific safety gates** — e.g. always require dry-run on sync, or limit
  `update-source` to certain frames

Fork the repo, maintain your own copy, or keep a private `SKILL.md` your team
uploads to Figma — whatever fits your governance.

### Lean on Figma the way you already do

The skill reads and writes **text nodes** through the Plugin API. It works best
when your file structure matches how you already design:

- Mark real screens as frames the agent can scope to
- Use consistent layer and component names — they feed key naming
- If you rely on **components and variants**, align naming so keys stay stable
  when variants change
- If you use **styled text** (links, color emphasis), the Figma-native skill
  preserves that on push and download — adjust the rich-text rules in the skill
  if your team uses a different subset

You don't need to redesign your file for the skill. Tune the skill (and setup
defaults) to match the Figma habits you already have.

### Share back (optional)

If you land on a pattern that would help other design teams — a clearer naming
convention, a safer confirmation step, better handling for a Figma feature —
consider opening a PR or describing it in an issue. The canonical skill and the
Figma-native version are maintained as siblings; useful ideas from either side
can flow across. See [`docs/governance.md`](docs/governance.md).

---

## Other agents

The skill is plain Markdown, so anything that can read files and call
Figma/Lokalise tools can run it — not just Claude or Figma's agent.

Paste-in fallback for agents without skill upload:
[`docs/prompt-snippet.md`](docs/prompt-snippet.md)

---

## For maintainers

| Doc | Purpose |
| --- | --- |
| [`docs/governance.md`](docs/governance.md) | Versioning, how the two skill files stay in sync |
| [`docs/mcp-setup.md`](docs/mcp-setup.md) | MCP connector checklist |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |
| [`AGENTS.md`](AGENTS.md) | Cross-provider router for coding agents |

**Repo layout**

```
skills/figma-lokalise-localization/   canonical skill (source of truth)
figma-agent/SKILL.md                  standalone version for Figma's native AI agent
docs/                                 setup, governance, paste-in fallback
```

**What deliberately stays out of this repo**

- **Session / project artifacts** — key IDs, task IDs, one-off helper scripts,
  specific node IDs. Those belong to the consuming project, not the reusable
  skill.
- **Secrets / API tokens** — never committed; they belong in the agent's MCP
  configuration.
- **Per-file localization config** — lives in Figma plugin data, written by the
  `setup` flow, not in the skill.

## License

[MIT](LICENSE) — confirm this fits your org before publishing (see the note in
the LICENSE file).
