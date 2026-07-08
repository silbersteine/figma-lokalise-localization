# Flow: Download (Lokalise → Figma)

Pull translations from Lokalise and generate translated preview copies of Figma
frames. Defaults to cloning the **selected frame(s)**; clones are placed per the
`previewPlacement` config (default: one page per language). Re-running refreshes
existing clones in place rather than duplicating them.

Writes to the Figma canvas — but only to generated clones and preview pages,
**never to the source frame**.

## When to use

- "Download translations", "generate the German version", "make translated
  previews / page copies", "pull the latest translations into Figma"

## Preflight

Read `reference.md` (§1 storage contract incl. preview-page markers, §3 clone +
fill snippets, §5 placeholders). Load config (§3 "Read root config"); if
`lokaliseProjectId` is missing → `flows/setup.md`. Get the file key.

## Steps

### 1. Resolve scope (default: frame / selection)
- A selected frame → that frame is the source screen.
- Selected nodes → resolve to their enclosing screen frame(s).
- A page (non-default, whole-page) → every screen frame on it.
Collect the source frame ids. If nothing is selected, ask which frame.

### 2. Resolve languages
Default to all `targetLanguages`. If the user named a subset ("the German
version"), use just those. Validate each is in `targetLanguages`; if not, offer
to add it via setup rather than guessing.

### 3. Fetch translations (batched)
For the keys linked under each source frame, fetch from Lokalise with
`list_lokalise_keys` (filter by the screen tag or `filter_keys` = the key names,
`include_translations=1`) so all requested languages come back together. Build a
per-language map `{ key_id → translation_text }`. Note any empty translations —
those nodes will fall back to source text and be counted as "missing".

### 4. Confirm (writes to canvas)
Summarize: languages, source frames, the placement mode and the target pages
that will be created or refreshed, and how many strings are translated vs missing
per language. Get a go-ahead.

### 5. For each (source frame × language)
1. **Clone** with the placement-aware helper (reference §3). It resolves/creates
   the destination page per `previewPlacement`, removes any prior clone for this
   source+language, positions the new clone, sets clone/page plugin data, and
   returns `{ cloneId, pageId, pageName }`.
2. **Fill** the clone's text nodes with the fill snippet below: match each clone
   text node to its translation by `keyId` (carried over from the source on
   clone), substitute `{token}` placeholders from `placeholderSamples` for
   display (§5), load fonts, write text, and stamp `lastPulledAt` /
   `lastPulledLang`. Missing translations leave the inherited source text in
   place.

```javascript
const NS = "lokalise";
const clone = figma.getNodeById(CLONE_ID);
const lang = LANG, now = NOW_ISO;
const map = TRANSLATIONS;          // { key_id: "translated text" } for this lang
const samples = SAMPLES || {};     // placeholderSamples config, or {}
function fill(t){ return t.replace(/\{(\w+)\}/g, (m,k)=> k in samples ? samples[k] : m); }
async function loadFonts(n){
  if (n.fontName === figma.mixed){
    const fonts = n.getRangeAllFontNames(0, n.characters.length);
    await Promise.all(fonts.map(f => figma.loadFontAsync(f)));
  } else { await figma.loadFontAsync(n.fontName); }
}
const texts = clone.findAllWithCriteria({types:["TEXT"]});
let filled = 0, missing = 0;
for (const n of texts){
  const keyId = n.getSharedPluginData(NS,"keyId");
  const t = (keyId && map[keyId] != null) ? map[keyId] : null;
  if (t == null){ missing++; continue; }
  await loadFonts(n);
  n.characters = fill(t);
  n.setSharedPluginData(NS,"lastPulledAt", now);
  n.setSharedPluginData(NS,"lastPulledLang", lang);
  filled++;
}
return JSON.stringify({ filled, missing });
```

### 6. Report
Per language: which page holds the clones (`pageName`), frames generated, and
`filled` / `missing` counts. If anything was missing, point the user at
check-stale or note that translation is still pending in Lokalise. If clones were
refreshed rather than created, say so.

## Notes and caveats

- **Placeholder direction (§5).** Assumes the Figma source node holds the
  template and `placeholderSamples` renders display values. If your workflow is
  the inverse, the fill step changes — confirm before relying on previews.
- **Mixed-font nodes.** `loadFonts` handles multiple fonts, but writing
  `.characters` on a node with mixed inline formatting collapses per-range
  styling. That's acceptable in v1 (inline formatting is deferred, §5); flag it
  if a node depends on inline runs.
- **Text overflow.** Translated strings are often longer than source. Auto-resize
  nodes grow; fixed-width nodes may clip. Previews surface this visually, which is
  the point — note obvious overflow in the report if easy to detect.
- **Source safety.** Everything writes to clones/preview pages. If a resolved
  target ever points at a node without `isPreviewClone`, stop — never write to a
  source node in this flow.

## Example

**Input:** "Generate German and Spanish previews of the selected Home frame."

**Actions:** scope = Home frame; langs = de, es → fetch keys+translations (de
full, es 2 missing) → confirm ("2 pages: 🌐 DE — previews, 🌐 ES — previews") →
for de: clone → fill 12/12; for es: clone → fill 10/12 → report: "de on 🌐 DE —
previews (12 filled). es on 🌐 ES — previews (10 filled, 2 missing:
`home.hero.subhead`, `home.cta.secondary`) — pending in Lokalise."
