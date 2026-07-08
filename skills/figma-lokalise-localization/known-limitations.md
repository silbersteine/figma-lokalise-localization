# Known limitations (Lokalise MCP)

Constraints of the connected Lokalise MCP servers that shape how the flows work.
These are tool-surface gaps, not Lokalise API gaps — the REST API supports more
than the MCP currently exposes. Revisit this file if the servers add tools.

## 1. No delete-key tool

Neither server exposes a delete-key operation. The only delete available is
`delete_lokalise_screenshot`. There is no `delete_lokalise_key` and no bulk key
delete.

- **Impact:** stale keys can't be hard-deleted from the skill.
- **Workaround:** archive instead of delete (`update_lokalise_key` with
  `is_archived: true`), using the archive-and-recreate recipe in `reference.md`
  §10.
- **Residue:** archived keys accumulate and can only be purged from the Lokalise
  UI or via a delete tool the MCP doesn't have. Treat cleanup as a manual,
  out-of-band task for now.

## 2. No update-translation-text tool

`update_lokalise_key` and `bulk_update_lokalise_keys` patch key **metadata only**
(key_name, description, tags, context, char_limit, platforms, custom_attributes,
is_archived, is_hidden, is_plural, plural_name, filenames). None of them accept a
`translations` field, so an existing key's **source or target text cannot be
edited in place** through the keys API.

Translation *content* can only be written by:
- `create_lokalise_keys` — seeds translations at creation time only, or
- `upload_file` — imports translation content via the FSS upload flow.

`upload_file` is not used in this project (per project decision). That leaves
archive-and-recreate as the path for source-text changes — see reference.md §10.

- **Impact:** the sync flow cannot update a drifted key's text in place; it must
  archive the old key and create a replacement, which churns the `key_id`.

## Per-flow impact

- **setup** — unaffected (writes Figma plugin data only).
- **sync** — new keys: unaffected. Drifted keys (source text changed): use
  archive-and-recreate (reference §10); `key_id` changes, node state is rewritten.
- **check-stale** — unaffected (read-only).
- **download** — unaffected (reads translations, writes Figma).
- **update-source** — writes Figma source text; on the Lokalise side it only
  needs to mark source reviewed, which is metadata — unaffected.

## If these tools appear later

Watch for `delete_lokalise_key` and any translation-update tool. If added:
- sync's drift path can switch from archive-and-recreate to an in-place source
  update (stable `key_id`, no archived residue);
- a cleanup step can hard-delete archived keys.
