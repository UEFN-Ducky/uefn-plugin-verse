---
description: "Where the Verse API and your custom assets live, and how to search them"
metadata:
  order: 1
  label: "Digests — find any API or asset"
  default_enabled: false
  load_condition: "Looking up a device, weapon, type, function signature, or a custom asset before writing Verse"
---

## Digests — the source of truth for names

**HARD RULE — READ ONLY. NEVER write, edit, delete, rename, or patch any
`*.digest.verse` (Fortnite / Verse / UnrealEngine / Assets).** UEFN **auto-edits**
digests itself on Verse build / import — you do not. Workflow: write project
Verse under `Content/Verse/**` → run Verse build (`workspace_compile_verse`
when UEFN is open) → then **look inside** with `search_verse_digest` /
`get_verse_api` / `list_verse_types`. Missing a new material/mesh/prefab in
Assets? Build first, then re-search — never invent by patching a digest.

For the open project, UEFN writes a digest (a `.verse` stub of every public
declaration, each with its `#` doc comment) under:

```
%LOCALAPPDATA%\UnrealEditorFortnite\Saved\VerseProject\<Project>\
    Fortnite\Fortnite.digest.verse          # Fortnite.com — devices, weapons, agents, playspace
    UnrealEngine\UnrealEngine.digest.verse  # UnrealEngine.com — math, transforms, meshes
    Verse\Verse.digest.verse                # Verse.org — language stdlib
    <Project>-Assets\Assets.digest.verse    # YOUR custom assets (meshes, materials, …)
```

`<Project>` is the open UEFN project's name (e.g. `…\VerseProject\MCPTest\…`). The
`<Project>-Assets` digest is regenerated when you import or create assets — it's how
you learn the **Verse identifier** of something you added in the editor.

## What a digest entry looks like

```verse
    # Grants an item to the agent.          # <- doc comment(s)
    @available { … }                        # <- optional attribute line
    GrantItem<public>(Agent:agent):void     # <- declaration: name, effects, params, return
```

Scope is by indentation under `X := class(...)` / `interface` / `module` / `enum`;
the innermost enclosing `class`/`module` owns the member.

## Tools — search, don't dump (files are up to ~1 MB)

These tools read digests from disk — **listener offline OK**.

| Tool | Use |
|------|-----|
| `list_verse_digests()` | Map of every digest found + purpose blurb + decl counts by kind. Start here. |
| `get_verse_api(name, digest_path="", max_chars=24000)` | **Full definition block** for an identifier (class/module/interface/enum/extension fn) with doc comments — the go-to before writing code against it. |
| `search_verse_digest(query, digest_path="", max_results=50)` | Ranked keyword search → `{path, line, text, module}`. Use when you don't know the exact identifier yet. |
| `list_verse_types(kind="", digest="", name_filter="", offset=0, limit=200)` | Enumerate declarations — e.g. all devices (`name_filter="_device"`), all custom assets (`digest="assets"`). |
| `list_verse_modules(digest_path="")` | Module map (with nesting + line numbers) across all digests — orient before drilling in. |
| `list_verse_devices(digest_path="")` | Device class names (`_device` suffix or `creative_device` parent). |

All auto-discover the open project's digests (including `<Project>-Assets`);
pass `digest_path=` an absolute path to target one file. Content Browser weapon/item
*assets* → `search_assets` (digests cover Verse API + Verse-visible identifiers).

## Worked lookups

- **A class you're about to use:** `get_verse_api("mesh_component")` / `get_verse_api("entity")` → exact members, effects, doc comments. Copy signatures, don't paraphrase.
- **A generated prefab class:** `get_verse_api("P_LightPost")` → its Assets.digest entry (exists only after a Verse build).
- **Weapon / item:** `search_verse_digest("rifle")` → note the exact type, then `get_verse_api(<type>)`.
- **A device + its API:** `get_verse_api("trigger_device")` → its events/functions (`TriggeredEvent`, `Enable()`).
- **A function signature:** `search_verse_digest("GrantItem")` → copy params + effects exactly.
- **Orientation:** `list_verse_modules()` → find `SceneGraph`, `Devices`, `SpatialMath`, your asset modules.

To read one digest in full (rarely needed — prefer search), open its path with
`workspace_read_file` only — never `workspace_write_file`. If a name appears in
no digest, don't write it (and never invent it by editing a digest).
