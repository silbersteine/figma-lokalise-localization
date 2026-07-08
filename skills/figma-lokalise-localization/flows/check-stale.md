# Flow: Check stale

Read-only. Report which text is out of sync between Figma and Lokalise, across
two independent axes:

- **Source drift (Figma side):** has the Figma source text changed since it was
  last pushed? (live hash vs `lastPushedContentHash`, reference §9). Rich-text
  keys are a special case — their stored hash is of the HTML source while the
  Figma node holds plain text, so they need the plain-text reconciliation in
  step 4b to avoid a permanent false "drifted".
- **Translation coverage (Lokalise side):** for each linked key, which target
  languages are missing, unverified, or outdated relative to the source?

This flow **never writes** to Figma or Lokalise. It only reads and reports, then
suggests which other flow to run.

## When to use

- "Is this screen up to date?", "check for stale translations", "did the source
  change since last sync?", "what still needs translating?"
- Before a release, to see what sync/download work remains
- Runs on a selection or on whole frames

## Preflight

Read `reference.md` (§1, §3, §9 — and §5 rich text / `context` grammar once
added). Load config (§3 "Read root config"); if `lokaliseProjectId` is missing,
route to `flows/setup.md`. Get the file key.

## Steps

### 1. Resolve scope
Either the user's current selection or one/more frames. Skip preview clones
(`isPreviewClone === "true"`) — they're evaluated by download, not here; note
their count separately if present.

### 2. Collect source nodes (read-only)
Run via `use_figma`. For a frame, pass its id; for a selection, iterate
`figma.currentPage.selection` and collect TEXT descendants.

```javascript
const NS = "lokalise";
const scope = figma.getNodeById(SCOPE_ID);
function contentHash(str){let h=0x811c9dc5;for(let i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,0x01000193);}return (h>>>0).toString(16).padStart(8,"0");}
const texts = scope.findAllWithCriteria({types:["TEXT"]})
  .filter(n=>n.visible && n.characters.trim()!=="" && n.getSharedPluginData(NS,"isPreviewClone")!=="true");
return JSON.stringify(texts.map(n=>({
  id:n.id, name:n.name, characters:n.characters, liveHash:contentHash(n.characters),
  keyName:n.getSharedPluginData(NS,"keyName")||null,
  keyId:n.getSharedPluginData(NS,"keyId")||null,
  lastHash:n.getSharedPluginData(NS,"lastPushedContentHash")||null,
  // "html" once rich sync writes it; null for plain keys and for rich keys
  // pushed manually before that automation exists (fall back to Lokalise context)
  contentKind:n.getSharedPluginData(NS,"lastPushedContentKind")||null
})));
```

### 3. Classify source drift (Figma side) — provisional
- **never synced** — `keyId` null (new; not drift, but surfaced as "not yet in
  Lokalise").
- **drifted** — `keyId` set and `liveHash` ≠ `lastHash` (source changed since push).
- **current** — `keyId` set and `liveHash` = `lastHash`.

This classification is **provisional for rich-text keys**. If `contentKind ===
"html"` (or the key is later found to be rich via its Lokalise `context` in step
4), the hash compare is comparing a plain-text hash against an HTML-text hash and
will read "drifted" even when nothing changed. Do **not** finalize or report
those as drifted here — hold them for step 4b.

### 4. Fetch Lokalise state (batched)
For nodes with a `keyId`, fetch keys with translations. Prefer
`list_lokalise_keys` filtered by the screen tag (or `filter_keys` = the key
names) with translations included, so a whole screen comes back in one/few calls;
fall back to `get_lokalise_key(key_id, include_translations=1)` for specifics.
Read each key's source `modified_at` and its per-language translations
(`translation`, `is_unverified`, `is_reviewed`, `modified_at`).

### 4b. Reconcile rich-text false drift (finalizes step 3)

Rich-text keys store an **HTML** `content_hash`/`lastPushedContentHash` (hash of
e.g. `The future of how<br/><span style="color:#ffc700">together now</span>`),
but the Figma node reports **plain** `characters`. The step-3 hash compare
therefore *always* mismatches for these keys — a false "drifted". Reconcile every
node held from step 3 before it reaches the report.

**Detect rich keys** (prefer the first signal):
- **Figma flag** — `contentKind === "html"` from step 2 (written by rich sync
  once that automation exists).
- **Lokalise `context`** — contains an `html` token, e.g.
  `figma:12:32|html|emphasis:color` (split on `|`). This comes back with the
  step-4 fetch, so it costs no extra call and covers rich keys pushed manually
  before the Figma flag is written.

If neither signal is present, the key is plain — keep the step-3 result as-is.

**For a rich key, replace the hash compare with a plain-text projection compare.**
Project the Lokalise source-language value (the HTML) back down to plain text and
compare it to the node's live `characters`. Use the canonical `htmlToPlain` /
`norm` helpers from reference §3 (single source of truth — don't redefine them
here); this reads only, no Figma or Lokalise write:

```javascript
// htmlToPlain + norm: see reference.md §3 "Project rich HTML source to plain text"
// sourceHTML = source-language (sourceLanguage) translation value from step 4
// livePlain  = node.characters from step 2
const textDrifted = norm(htmlToPlain(sourceHTML)) !== norm(livePlain);
```

Reclassify each rich node:
- **projections equal → not drifted.** The only difference was markup — this is
  the false flag we are filtering out. Report as **current (rich)**.
- **projections differ → genuine text drift.** Report as **drifted (text)**; the
  fix is sync via archive-and-recreate (the key is rich), reference §10.

**Formatting is a separate axis this flow cannot yet verify.** A plain-text match
confirms the *words* agree; it says nothing about whether the emphasis/colour
spans still align, because reconstructing HTML from the node requires
`getStyledTextSegments` (rich-sync automation, not built — see
`known-limitations.md`). So for **every** rich key, report the formatting axis as
**"not verified (rich automation pending)"**. Never let a plain-text match imply
the formatting is confirmed, and never silently fail it either.

### 5. Classify translation coverage (Lokalise side)
For each key, for each `targetLanguages` entry:
- **missing** — translation empty.
- **unverified** — non-empty but `is_unverified` (includes targets auto-flagged
  after a source change).
- **outdated** — translation `modified_at` earlier than the key source
  `modified_at`.
- **ready** — non-empty, reviewed/verified, not older than source.

### 6. Report
Lead with counts, then detail grouped by status. Keep it scannable:

- Source drift: X drifted, Y never-synced, Z current (counts are **after** the
  step-4b reconciliation, so rich keys are not double-counted as drifted).
- Rich keys: report text and formatting separately, e.g. `2 rich — text current,
  formatting not verified`. Only a rich key whose *plain text* actually changed
  belongs in the drifted count.
- Coverage per language: e.g. `de: 10 ready / 2 unverified / 3 missing`.
- Per-node lines only for anything not fully clean (drifted or with gaps), each
  with key name, drift state, and the languages needing work.
- If preview clones were skipped, note the count.

### 7. Suggest next actions (still no writes)
Map findings to flows, without doing them:
- drifted or never-synced nodes → run **sync** (rich keys with real text drift
  go through archive-and-recreate).
- rich keys where only the **formatting** axis is in question → there is no clean
  fix yet; flag that rich sync/download automation is pending rather than
  offering a plain sync that would flatten the markup.
- missing/outdated target languages → run **download** once translated, or flag
  that translation work is pending in Lokalise.
- Don't offer to fix things silently — this flow's contract is read-only.

## Example

**Input:** "Is the Home screen up to date?"

**Actions:** collect 12 source nodes → 1 drifted, 11 current, 0 never-synced →
`list_lokalise_keys` by tag `home` with translations → coverage: `de` all ready,
`es` 2 unverified, `th` 5 missing.

**Report:** "Home: 1 node drifted (`home.hero.headline`) — run sync. Coverage —
de: 12 ready. es: 10 ready, 2 unverified. th: 7 ready, 5 missing. Nothing was
changed." Then: run sync for the drifted headline; th still needs translation in
Lokalise before download will fill it.

**Rich-text case:** `home.hero.heading` has `context = figma:12:32|html|
emphasis:color`, so step 3 provisionally flags it drifted (plain hash vs stored
HTML hash). Step 4b projects the Lokalise HTML source to plain text
(`… together now.`), which matches the node's `characters` → reclassified
**current (rich); formatting not verified**, and it drops out of the drifted
count instead of nagging on every run. Had the plain projection differed (e.g.
node still says "…now." but source now reads "…now. Updated"), it would stay
**drifted (text)** and route to sync.
