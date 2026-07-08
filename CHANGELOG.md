# Changelog

All notable changes to the skill are recorded here. This tracks **pattern-level**
changes to the reusable skill — not project/session instance data (key IDs,
tasks, node IDs, one-off scripts), which never belongs in this repo.

Format follows [Keep a Changelog](https://keepachangelog.com/); versions follow
[Semantic Versioning](https://semver.org/). Pre-1.0: minor = behavior change,
patch = docs/clarity.

## [Unreleased]

### Added
- **Rich-text drift handling.** `check-stale` gained step 4b: rich (HTML) keys
  are reconciled by comparing plain-text projections instead of hashes, removing
  the permanent false "drifted" for formatted text. The formatting axis is
  reported as not-yet-verifiable rather than silently passed.
- `reference.md` §3: canonical `htmlToPlain` / `norm` helpers (single source of
  truth) for projecting Lokalise HTML source down to plain text.
- `reference.md` §9: plain-vs-rich **content-kind hash policy** — hashing is only
  valid within one encoding; rich keys use projection-based drift detection.
- New text-node field `lastPushedContentKind` (`"html"` | `""`) so agents can
  detect rich keys Figma-side without a Lokalise round-trip; written by the §3
  node-state snippet.

### Known limitations (unchanged, tracked in `known-limitations.md`)
- Rich-text **sync** (Figma segments → HTML + context) and **download** (parse
  context → reapply links via range APIs) are not automated yet.
- In-place translation-text edits and key deletion are not available via MCP;
  source changes use archive-and-recreate.

## [0.1.0] - initial
- Router `SKILL.md` + `reference.md` + five flows (setup, sync, download,
  check-stale, update-source) + `known-limitations.md`.
- Config and per-node link state stored in Figma plugin data.
