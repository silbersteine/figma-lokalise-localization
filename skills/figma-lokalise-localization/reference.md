# Reference: Figma ↔ Lokalise mapping and storage

Shared knowledge for every flow. Read the section you need; the whole file is
safe to load. Sections:

1. Storage contract (where config and state live)
2. Config schema (what setup writes)
3. Canonical Plugin-API snippets (the JS the flows run via `use_figma`)
4. Key-naming logic
5. Placeholders (v1)
6. Lokalise key metadata mapping (the field-by-field schema)
7. Node-purpose controlled vocabulary
8. Tag composition
9. Content hash and drift definition
10. Updating or removing keys (archive-and-recreate)

---

## 1. Storage contract

All config and state live **in the Figma file** as plugin data, so any flow can
self-orient with no external store. We use **shared** plugin data (namespace
`lokalise`) at every level. Shared plugin data is readable by any caller that
knows the namespace, which matters here because writes/reads go through the
`use_figma` MCP and may not share a stable plugin identity across sessions — so
prefer `setSharedPluginData`/`getSharedPluginData` over the private
`setPluginData` variants everywhere, even where an earlier draft used the
private form.

Namespace: `lokalise`

**Root** (`figma.root`) — file-wide config:

| Key | Kind | Example |
| --- | --- | --- |
| `lokaliseProjectId` | config | `1679154569613666d69116.09144328` |
| `sourceLanguage` | config | `en` |
| `targetLanguages` | config | `["de","es","th"]` |
| `defaultPlatforms` | config | `["web"]` |
| `defaultTags` | config | `["figma"]` |
| `keyNamingConvention` | config | `{screen}.{component}.{element}` |
| `previewPlacement` | config | `new_page_per_language` |
| `placeholderSamples` | config (optional) | `{"username":"Eric"}` |

**Frame** (screen-level) — config overrides + derived state:

| Key | Kind | Meaning |
| --- | --- | --- |
| `isScreen` | config | `"true"` marks this frame as a syncable screen |
| `screenName` | config | Explicit name if layer-hierarchy inference is wrong |
| any root config key | config | Frame-level override of a file-wide default |
| `lastSyncedAt` | state | Rollup: max of child nodes' `lastPushedAt` |
| `lastSyncedKeyCount` | state | Rollup: count of linked text nodes in this frame |

**Text node** — state only (nodes record fact, never policy):

| Key | Set during | Meaning |
| --- | --- | --- |
| `keyName` / `keyId` | sync | Link to the Lokalise key |
| `lastPushedAt` | sync | When this node was last sent to Lokalise |
| `lastPushedContentHash` | sync | Hash of characters at push time (drift detection) |
| `lastPushedContentKind` | sync | `"html"` when the pushed source is rich HTML, else `""`/absent (plain). Lets check-stale detect rich keys without a Lokalise round-trip — see §9. |
| `lastPulledAt` | download | When a translation was last written into this node |
| `lastPulledLang` | download | Which language that pull was |

**Preview clone (frame + node)** — set on `frame.clone()` output:

| Key | Frame clone | Node clone |
| --- | --- | --- |
| `isScreen` | overwrite → `"false"` | — |
| `isPreviewClone` | set `"true"` | — |
| `sourceFrameId` | set = source frame node id | — |
| `sourceNodeId` | — | set = source node id (back-reference) |
| `previewLang` | set (e.g. `"de"`) | set (e.g. `"de"`) |
| `generatedAt` | set = clone timestamp | — |
| `screenName` | clear or suffix (avoid duplicate claim) | — |
| `lastSyncedAt`, `lastSyncedKeyCount` | clear (`""`) | — |
| `keyName` / `keyId` | — | copied from source (still points at same key) |
| `lastPushedAt`, `lastPushedContentHash` | — | clear (not applicable to a clone) |
| `lastPulledAt` | — | set when translation written |
| inherited config override | keep | — |

**Preview page** — set on pages that hold generated clones (so download can
find-or-create them per `previewPlacement`):

| Key | Kind | Meaning |
| --- | --- | --- |
| `isPreviewPage` | state | `"true"` marks a generated preview page |
| `previewLang` | state | language the page holds; `"*"` for a single mixed page |

---

## 2. Config schema (what setup writes)

Setup collects and writes the root config above. Notes:

- `lokaliseProjectId`, `sourceLanguage`, `targetLanguages` are required.
- `defaultPlatforms` must be a subset of `ios | android | web | other`
  (Lokalise's allowed platform values).
- `keyNamingConvention` is a template string; the interpreter is §4.
- `previewPlacement` controls where download puts generated clones. Values:
  `new_page_per_language` (default — one page per target language),
  `previews_page` (one shared "Translations" page for all languages), or
  `alongside_source` (clones on the source's own page, offset below it). A
  download run may override it for that run only.
- `placeholderSamples` is optional — absent means preview substitution is simply
  skipped, not an error.
- Before the first sync, call `get_lokalise_project` once and record whether
  `settings.per_platform_key_names` is enabled — it changes whether `key_name`
  is a string or a per-platform object when creating keys.

---

## 3. Canonical Plugin-API snippets

Run these via `use_figma` (they have the `figma` global). They are the shared
implementations — flows should reuse them rather than reinventing. Each returns
JSON so the flow can parse the result.

**Read root config**
```javascript
const NS = "lokalise";
const keys = ["lokaliseProjectId","sourceLanguage","targetLanguages",
  "defaultPlatforms","defaultTags","keyNamingConvention","previewPlacement",
  "placeholderSamples"];
const cfg = {};
for (const k of keys) {
  const v = figma.root.getSharedPluginData(NS, k);
  cfg[k] = v === "" ? null : v;
}
// JSON-typed values are stored as JSON strings; parse on read.
for (const k of ["targetLanguages","defaultPlatforms","defaultTags",
                 "placeholderSamples"]) {
  if (cfg[k]) { try { cfg[k] = JSON.parse(cfg[k]); } catch(e){} }
}
return JSON.stringify(cfg);
```

**Effective config for a frame** (frame override beats root)
```javascript
const NS = "lokalise";
const frame = figma.getNodeById(FRAME_ID);
function eff(key){
  const f = frame.getSharedPluginData(NS, key);
  if (f !== "") return f;
  return figma.root.getSharedPluginData(NS, key);
}
```

**List syncable text nodes under a frame**
```javascript
const frame = figma.getNodeById(FRAME_ID);
const texts = frame.findAllWithCriteria({ types: ["TEXT"] })
  .filter(n => n.visible && n.characters.trim() !== "");
return JSON.stringify(texts.map(n => ({
  id: n.id, name: n.name, characters: n.characters,
  fontName: n.fontName, fontSize: n.fontSize,
  width: Math.round(n.width), autoResize: n.textAutoResize
})));
```

**Content hash** (FNV-1a, 32-bit, hex — deterministic, no async crypto needed)
```javascript
function contentHash(str){
  let h = 0x811c9dc5;
  for (let i=0;i<str.length;i++){
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8,"0");
}
```
The hash input is the node's `characters` string (the template text, including
`{placeholder}` tokens — see §5). Drift = live hash ≠ stored
`lastPushedContentHash`. **Exception:** rich (HTML) keys store an HTML hash while
the node reports plain text, so a plain-vs-HTML hash compare is invalid for them
— compare plain-text projections instead (next snippet; policy in §9).

**Project rich HTML source to plain text** (pure string helper — no `figma`
global, so it runs in either the `use_figma` layer or the flow's own reasoning
layer). Use it to compare a Lokalise HTML source value against a node's plain
`characters` without the encoding causing a false mismatch.
```javascript
function htmlToPlain(s){
  return String(s)
    .replace(/<br\s*\/?>/gi, "\n")             // <br/> → newline
    .replace(/<[^>]+>/g, "")                    // drop all other tags (spans, etc.)
    .replace(/&nbsp;/gi, " ").replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<").replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"').replace(/&#39;|&apos;/gi, "'");
}
// normalize line-ending + trailing-space noise, but not interior text
const norm = s => String(s).replace(/\r\n/g,"\n").replace(/[ \t]+$/gm,"").trim();
// equal ⇒ words match (only markup differed); different ⇒ genuine text drift
// const textDrifted = norm(htmlToPlain(sourceHTML)) !== norm(livePlain);
```
This projects HTML → plain only (it does **not** reconstruct formatting). The
formatting axis needs `getStyledTextSegments` and is not verifiable until rich
sync/download automation exists (see `known-limitations.md`).

**Write node state after a push**
```javascript
const NS = "lokalise";
const n = figma.getNodeById(NODE_ID);
n.setSharedPluginData(NS, "keyName", KEY_NAME);
n.setSharedPluginData(NS, "keyId", String(KEY_ID));
n.setSharedPluginData(NS, "lastPushedAt", NOW_ISO);
n.setSharedPluginData(NS, "lastPushedContentHash", HASH);
// "html" when the pushed source was rich HTML, else "" (plain). Drives the
// rich-key detection in check-stale §4b without a Lokalise round-trip.
n.setSharedPluginData(NS, "lastPushedContentKind", CONTENT_KIND || "");
```

**Recompute frame rollups** (after a sync pass)
```javascript
const NS = "lokalise";
const frame = figma.getNodeById(FRAME_ID);
const linked = frame.findAllWithCriteria({ types:["TEXT"] })
  .filter(n => n.getSharedPluginData(NS,"keyId") !== "");
const times = linked.map(n => n.getSharedPluginData(NS,"lastPushedAt"))
  .filter(Boolean).sort();
frame.setSharedPluginData(NS,"lastSyncedKeyCount", String(linked.length));
frame.setSharedPluginData(NS,"lastSyncedAt", times.length ? times[times.length-1] : "");
```

**Clone a frame for a preview language** (placement-aware, idempotent; never
touches the source). Honors `previewPlacement` config and, on re-run, replaces
the existing clone for that source+language instead of stacking duplicates.
```javascript
const NS = "lokalise";
const src = figma.getNodeById(FRAME_ID);
const lang = LANG;
const placement = figma.root.getSharedPluginData(NS,"previewPlacement") || "new_page_per_language";

// 1. Resolve destination page
function previewPage(l){
  return figma.root.children.find(p => p.type==="PAGE" &&
    p.getSharedPluginData(NS,"isPreviewPage")==="true" &&
    p.getSharedPluginData(NS,"previewLang")===l);
}
let dest;
if (placement==="alongside_source"){
  dest = src.parent;                     // same page as source
} else if (placement==="previews_page"){
  dest = previewPage("*");
  if(!dest){ dest=figma.createPage(); dest.name="🌐 Translations";
    dest.setSharedPluginData(NS,"isPreviewPage","true");
    dest.setSharedPluginData(NS,"previewLang","*"); }
} else {                                  // new_page_per_language (default)
  dest = previewPage(lang);
  if(!dest){ dest=figma.createPage(); dest.name="🌐 "+lang.toUpperCase()+" — previews";
    dest.setSharedPluginData(NS,"isPreviewPage","true");
    dest.setSharedPluginData(NS,"previewLang",lang); }
}

// 2. Idempotency: drop any existing clone for this source+lang on dest
for (const child of [...dest.children]){
  if (child.getSharedPluginData(NS,"sourceFrameId")===src.id &&
      child.getSharedPluginData(NS,"previewLang")===lang) child.remove();
}

// 3. Clone, move to dest, position without overlap
const clone = src.clone();
clone.name = src.name + " [" + lang + "]";
if (dest !== src.parent) dest.appendChild(clone);
if (placement==="alongside_source"){
  clone.x = src.x; clone.y = src.y + src.height + 200;
} else {
  const others = dest.children.filter(c => c!==clone && "height" in c);
  const bottom = others.reduce((m,c)=>Math.max(m, c.y + c.height), 0);
  clone.x = 0; clone.y = others.length ? bottom + 200 : 0;
}

// 4. Clone-frame plugin data
clone.setSharedPluginData(NS,"isScreen","false");
clone.setSharedPluginData(NS,"isPreviewClone","true");
clone.setSharedPluginData(NS,"sourceFrameId", src.id);
clone.setSharedPluginData(NS,"previewLang", lang);
clone.setSharedPluginData(NS,"generatedAt", NOW_ISO);
clone.setSharedPluginData(NS,"screenName","");
clone.setSharedPluginData(NS,"lastSyncedAt","");
clone.setSharedPluginData(NS,"lastSyncedKeyCount","");

// 5. Remap node-level plugin data on the clone's text nodes
const srcTexts = src.findAllWithCriteria({types:["TEXT"]});
const clTexts  = clone.findAllWithCriteria({types:["TEXT"]});
for (let i=0;i<clTexts.length;i++){
  const c = clTexts[i], s = srcTexts[i];
  c.setSharedPluginData(NS,"sourceNodeId", s.id);
  c.setSharedPluginData(NS,"previewLang", lang);
  c.setSharedPluginData(NS,"lastPushedAt","");
  c.setSharedPluginData(NS,"lastPushedContentHash","");
}
return JSON.stringify({ cloneId: clone.id, pageId: dest.id, pageName: dest.name });
```
Notes: `findAllWithCriteria` returns source and clone text nodes in the same
order, so index alignment is reliable for remapping. Creating a page with
`figma.createPage()` does not switch the user's view; the returned `pageName`
lets the flow tell the user where the clones landed.

**Set text safely** (load the font first, or `setCharacters` throws)
```javascript
async function setText(node, value){
  await figma.loadFontAsync(node.fontName);
  node.characters = value;
}
```

---

## 4. Key-naming logic

The pattern *string* is config (`keyNamingConvention`, default
`{screen}.{component}.{element}`). This section is the *interpreter*.

Resolve each segment from the node's ancestry:
- `{screen}` — the frame's `screenName` override if set, else a slugified form
  of the enclosing screen frame's name (the frame with `isScreen="true"`).
- `{component}` — the nearest enclosing component/instance name, else the
  immediate container frame/group name.
- `{element}` — the text node's own layer name, slugified.

Slugify: lowercase, spaces/`/`→`_`, strip characters outside `[a-z0-9_]`,
collapse repeats. Example: layer path `Home > Header > Container > CONFIG2026`
with a CTA element → `home.hero.cta_primary` when names map cleanly; otherwise
fall back to the literal slugified segments (`home.container.config2026`).

Collisions: if two nodes resolve to the same key name, they are either the same
string (shared key — see §8 shared_key) or a genuine clash. Only treat them as a
shared key when the text content matches; otherwise disambiguate the `{element}`
segment and warn the user.

---

## 5. Placeholders (v1)

**v1 scope: `{token}` placeholders only. Inline formatting (bold runs,
hyperlinks) is deferred to a later version.**

Assumption to confirm with the user: the Figma text node holds the **template**
as its authored source (e.g. `Hello {username}`), and that template is the
source of truth pushed to Lokalise. Sample values in `placeholderSamples` config
(e.g. `{"username":"Eric"}`) are only used to render human-friendly previews.

- **Push (sync):** send the raw `characters` template to Lokalise as the source
  value. Record the token list in `custom_attributes.placeholders`.
- **Preview (download):** after writing a translation into a clone node,
  substitute each `{token}` with its `placeholderSamples` value for display. If a
  token has no sample, leave it as `{token}`.
- The content hash (§3) is computed on the template, so editing a sample value
  never counts as source drift; editing the template does.

If the user's real workflow is the inverse (Figma stores resolved text and the
template lives only in Lokalise), this section flips — flag it before building
sync/download.

---

## 6. Lokalise key metadata mapping

How each Figma fact maps onto the Lokalise key, and via which MCP parameter.
Create with `create_lokalise_keys`, enrich/patch with `update_lokalise_key` or
`bulk_update_lokalise_keys`.

| Lokalise target | MCP param | Value / source |
| --- | --- | --- |
| Key name | `key_name` | §4 result, e.g. `home.hero.cta_primary`. Per-platform object only if project has `per_platform_key_names`. |
| Platforms | `platforms` | `defaultPlatforms` config (subset of ios/android/web/other) |
| Description | `description` | Translator-facing context |
| Context | `context` | Short machine-readable back-ref: `figma:12:9` |
| Tags | `tags` | Composed per §8. Use `merge_tags: true` to preserve existing tags. |
| Custom attributes | `custom_attributes` | **JSON-encoded string** of the object below |

`custom_attributes` object (then `JSON.stringify` it):

| Attribute | Source |
| --- | --- |
| `layer_name` | node's own name |
| `layer_path` | full ancestry, e.g. `Home > Header > Container > CONFIG2026` |
| `page_name` | Figma page name |
| `parent_frame` | `{ "id": "12:6", "name": "..." }` — immediate screen context |
| `figma_file_key` | file key |
| `figma_node_id` | this node's id |
| `figma_url` | deep link to the node |
| `component_name` | enclosing component/instance name, if any |
| `font_family`, `font_style`, `font_size` | rendered typography |
| `auto_resize`, `width_px` | resize mode + measured width |
| `variable_name`, `variable_id` | reserved, `null` in v1 (variables parked) |
| `placeholder_text` | seeded source text at creation (e.g. `CONFIG2026`) |
| `placeholders` | token list extracted from the template (§5) |
| `content_hash` | §9, mirrors node's `lastPushedContentHash` |
| `last_pushed_at` | ISO timestamp, Figma → Lokalise |
| `last_pulled_at` | `null` on source keys; set on clone pulls only |
| `linked_source_node_ids` | array of source node ids sharing this key (enables shared key) |

Reserve room for non-text origins later: `custom_attributes` can gain
`origin_type` beyond `text` (image/video) without schema changes.

---

## 7. Node-purpose controlled vocabulary

Used for the purpose tag (§8). Keep it small and controlled; don't invent new
values silently.

`heading` · `cta` · `nav_item` · `body`

Infer from layer name / role when unambiguous; otherwise default to `body` and
let the user correct. Propose additions to the user rather than minting ad-hoc
tags.

---

## 8. Tag composition

Compose the `tags` array from:

- `page:page_1` — page tag (slugified page name)
- screen/frame tag — the `screenName` (e.g. `home`)
- node purpose — one of §7 (`heading` / `cta` / `nav_item` / `body`)
- origin type — `text` (reserves room for image/video later)
- `component_name` — only if the node is inside an instance
- `shared_key` — only if `linked_source_node_ids.length > 1`
- origin — `figma` (from `defaultTags`)

Always push with `merge_tags: true` so re-syncing enriches rather than wipes
tags a translator or PM may have added.

---

## 9. Content hash and drift definition

- `lastPushedContentHash` = `contentHash(node.characters)` at push time (§3),
  stored on the node and mirrored into `custom_attributes.content_hash`.
- **Source drift** (check-stale): recompute `contentHash` on the live node and
  compare to `lastPushedContentHash`. Different ⇒ the Figma source changed since
  last push (needs re-sync). Equal ⇒ source is current.
- **Content kind (plain vs rich).** The hash compare above is only valid when
  both sides are the same encoding. Plain keys hash `node.characters`. Rich
  (HTML) keys currently store a hash of the **HTML source**, while the node still
  reports **plain** `characters` — so a direct hash compare always mismatches and
  would report permanent false drift. Policy:
  - Record the kind at push time on the node as `lastPushedContentKind`
    (`"html"` | `""`), mirrored by the Lokalise key `context` carrying an `html`
    token (`figma:<id>|html|…`). Either signal identifies a rich key; prefer the
    node flag (no Lokalise call).
  - For rich keys, do **not** trust the hash. Determine source drift by comparing
    plain-text projections instead: `norm(htmlToPlain(lokaliseHtmlSource))` vs
    `norm(node.characters)` (both helpers in §3). Equal ⇒ only markup differs
    (not drift); different ⇒ genuine text drift. This is implemented in
    check-stale §4b.
  - The **formatting** axis (do the emphasis/colour spans still align?) is a
    separate question that needs `getStyledTextSegments` and is not verifiable
    until rich sync/download automation lands — never infer it from a plain-text
    match. See `known-limitations.md`.
- A node with no `keyId` has never been synced — that's "new", not "drifted".
- Translation staleness (a different axis): compare the key's source
  `modified_at` in Lokalise against a target language's translation state, via
  `get_lokalise_key`. check-stale reports both axes separately.

---

## 10. Updating or removing keys (archive-and-recreate)

The MCP exposes no delete-key tool and no way to edit an existing key's
translation text (see `known-limitations.md`). So when a node's **source text
drifts** (live hash ≠ `lastPushedContentHash`), you cannot patch the key in
place — you archive the stale key and create a replacement. Metadata-only
changes (tags, description, context, custom_attributes) do NOT need this; use
`update_lokalise_key` / `bulk_update_lokalise_keys` directly for those.

**Recipe** (per drifted node, or batched):

1. **Read the old key.** `get_lokalise_key(key_id, include_translations=1)`.
   Capture `key_name`, `tags`, and every translation
   `{ language_iso, translation, is_reviewed }`.
2. **Decide translation policy.** Default: keep the target-language translation
   *text* but re-seed it as `is_unverified: true` / `is_reviewed: false`, so the
   changed source flags those targets for re-check. Replace the source-language
   value with the new Figma template text. (If the project prefers a clean slate,
   seed only the new source and let targets be created empty.)
3. **Create the replacement.** `create_lokalise_keys` with the original
   `key_name`, `platforms`, full `tags` (composed per §8, merged with the old
   key's tags), `description`, `context`, `custom_attributes` (JSON string with
   the **new** `content_hash`), and `translations` from step 2.
   - If create fails with a name collision (the archived key still holds the
     name), rename the old key first —
     `update_lokalise_key(old_key_id, { key_name: "<name>__retired_<ts>" })` —
     then retry the create.
4. **Archive the old key.** `update_lokalise_key(old_key_id, { is_archived: true })`.
5. **Rewrite node state.** Point the Figma node at the new key: write the new
   `keyName` / `keyId`, `lastPushedAt`, and `lastPushedContentHash` (see §3
   "Write node state").

Consequences to be aware of: `key_id` changes on every source edit; archived
keys pile up with no delete tool to purge them (manual UI cleanup). If a
delete-key or translation-update tool later appears, this recipe collapses back
to an in-place text update — track that in `known-limitations.md`.
