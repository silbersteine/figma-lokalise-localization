# Flow: Setup

Configure a Figma file for Lokalise localization. This writes the file-wide
config that every other flow reads. Run it once per file, and re-run it to edit
settings later.

## When to use

- "Set up localization for this file", "configure Lokalise for this Figma file"
- Any other flow discovers `lokaliseProjectId` is missing on the file
- The user wants to change target languages, key naming, default tags/platforms

## Preflight

Read `reference.md` first (storage contract §1, config schema §2, snippets §3).
Get the Figma file key from the file URL. All Figma writes use `use_figma`.

## Steps

1. **Resolve the Figma file.** Ask for the file URL if not given; extract the
   file key. Confirm you can reach it (e.g. a light `get_metadata`/`use_figma`
   read) before gathering settings.

2. **Check for existing config.** Run the "Read root config" snippet (reference
   §3). If `lokaliseProjectId` is already set, tell the user the file is already
   configured, show the current values, and ask whether to **edit** specific
   fields or **start fresh**. Never silently overwrite an existing config.

3. **Resolve the Lokalise project.**
   - If the user gives a project ID, call `get_lokalise_project` to confirm it
     exists and to read: the project's base language, and
     `settings.per_platform_key_names` (record this — it decides whether
     `key_name` is sent as a string or a per-platform object during sync).
   - If they don't know the ID, call `list_lokalise_projects` and let them pick.
   - Do not invent a project ID. If it can't be found, stop and ask.

4. **Gather config interactively.** Ask for these, offering the defaults so the
   user can accept quickly. Keep it to a couple of grouped questions, not an
   interrogation.

   | Field | Required | Default | Notes |
   | --- | --- | --- | --- |
   | `sourceLanguage` | yes | project base language | ISO code, e.g. `en` |
   | `targetLanguages` | yes | — | ISO codes, e.g. `["de","es","th"]` |
   | `defaultPlatforms` | yes | `["web"]` | subset of ios/android/web/other |
   | `defaultTags` | no | `["figma"]` | applied to every key |
   | `keyNamingConvention` | no | `{screen}.{component}.{element}` | see reference §4 |
   | `previewPlacement` | no | `new_page_per_language` | where download puts clones; see reference §2 |
   | `placeholderSamples` | no | — | e.g. `{"username":"Eric"}`, preview-only |

5. **Validate languages against the project.** Call `list_project_languages`.
   For any `sourceLanguage`/`targetLanguages` not present in the project, offer
   to add them with `add_project_language` (confirm first) or to correct the
   code. A target language absent from the project will block translation later,
   so resolve it now, not at download time.

6. **Confirm the full config** back to the user as a compact summary before
   writing. This is a write to the file, so get an explicit go-ahead.

7. **Write the config** to root plugin data with the snippet below.

8. **(Optional) Mark screen frames.** Ask whether to mark any top-level frames
   as syncable screens now. If yes, for each chosen frame set `isScreen="true"`
   (and `screenName` if the frame name shouldn't be used verbatim). This is
   optional — sync can also mark a frame the first time it runs on it.

9. **Report.** Confirm what was written and where (in the file itself), and note
   the natural next step: run **sync** on a screen frame to create keys.

## Config-write snippet

Run via `use_figma`. Scalars are stored as plain strings; list/object values are
stored as JSON strings (the read snippet in reference §3 parses them back).

```javascript
const NS = "lokalise";
// Values gathered in steps 3–4, injected by the flow:
const cfg = {
  lokaliseProjectId: LOKALISE_PROJECT_ID,   // string
  sourceLanguage:    SOURCE_LANGUAGE,        // e.g. "en"
  targetLanguages:   TARGET_LANGUAGES,       // e.g. ["de","es","th"]
  defaultPlatforms:  DEFAULT_PLATFORMS,      // e.g. ["web"]
  defaultTags:       DEFAULT_TAGS,           // e.g. ["figma"]
  keyNamingConvention: KEY_NAMING,           // e.g. "{screen}.{component}.{element}"
  previewPlacement:  PREVIEW_PLACEMENT,      // "new_page_per_language" | "previews_page" | "alongside_source"
  placeholderSamples:  PLACEHOLDER_SAMPLES   // object or null
};
const scalars = ["lokaliseProjectId","sourceLanguage","keyNamingConvention","previewPlacement"];
const jsonVals = ["targetLanguages","defaultPlatforms","defaultTags","placeholderSamples"];
for (const k of scalars) {
  if (cfg[k] != null) figma.root.setSharedPluginData(NS, k, String(cfg[k]));
}
for (const k of jsonVals) {
  if (cfg[k] != null) figma.root.setSharedPluginData(NS, k, JSON.stringify(cfg[k]));
}
return "ok";
```

To **mark a screen frame** (step 8):
```javascript
const NS = "lokalise";
const f = figma.getNodeById(FRAME_ID);
f.setSharedPluginData(NS, "isScreen", "true");
if (SCREEN_NAME) f.setSharedPluginData(NS, "screenName", SCREEN_NAME);
return "ok";
```

## Editing existing config

When the user chose "edit" in step 2, only rewrite the fields they changed —
re-run the write snippet with just those keys, leaving the others untouched.
`setSharedPluginData` with an empty string `""` clears a key; use that to remove
an optional field like `placeholderSamples`.

## Example

**Input:** "Set up localization for this file — https://figma.com/design/kgL9.../
App. Source English, translate to German, Spanish, Thai."

**Actions:** confirm the file → user provides/we pick the Lokalise project →
`get_lokalise_project` (base language, per_platform_key_names) →
propose defaults (`web` platform, `figma` tag, `{screen}.{component}.{element}`)
→ `list_project_languages` shows `th` missing → offer `add_project_language` →
confirm summary → write config → report.

**Output summary:** config written to the file (project, `en` → `de/es/th`,
platform `web`, tag `figma`, naming `{screen}.{component}.{element}`). Next: run
sync on a screen frame.
