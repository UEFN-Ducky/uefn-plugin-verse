---
description: "UI materials for UMG — Fortnite UI Material folder, MI_* as Verse field types, material-parameter conversion in View Bindings, Feature Template migration"
metadata:
  order: 64
  label: "UMG UI materials & textures"
  default_enabled: false
  load_condition: "Using UI materials/textures on a User Widget, Verse material fields, progress-bar materials, or migrating from the UI Feature Template"
---

## UMG UI materials & textures

Epic's Verse-fields tutorials build styling from materials under **Fortnite → UI → Material**. Create **Material Instances** (`MI_*`), expose them as Verse fields on the User Widget, and swap them from Verse with `set MyWidget.ProgressBarMaterial = Style1Material`.

### Source content

| Source | Use |
|--------|-----|
| `Fortnite > UI > Material` | Base UI materials / functions for flat or dynamic HUD looks |
| **User Interfaces Feature Template** | Packaged widgets, MI_*, textures per Creative device — migrate into your project (Epic: *Migrating Template Assets*) |
| Project `/Game/...` MI_* / textures | Your instances — these become Assets digest ids |

### Verse side

1. Create / migrate `MI_Style1ProgressBar`, `MI_Style2ProgressBar`, etc.
2. On the User Widget, add a Verse field of **material** type (name e.g. `ProgressBarMaterial`).
3. Bind it to the Image / progress widget's material (or brush) via View Bindings — often with a material-parameter conversion function.
4. In Verse (after digest refresh):

```verse
var Style1Material : MI_Style1ProgressBar = MI_Style1ProgressBar{}
var Style2Material : MI_Style2ProgressBar = MI_Style2ProgressBar{}

EnterStyle1(InAgent : agent):void =
    set MyWidget.ProgressBarMaterial = Style1Material
```

Confirm exact type names with `list_verse_types(digest="assets", name_filter="MI_")` — never invent `MI_` stubs.

### Material parameters in UMG

Epic's *Conversion Function: Setting Material Parameters in UMG* shows binding a float/vector Verse field (or viewmodel property) into a dynamic material parameter (progress fill, tint, etc.). Pattern:

1. UI material exposes a scalar/vector parameter.
2. View Binding source = Verse `float` / `int` field (or viewmodel).
3. Conversion = material-parameter setter from the available conversion list.
4. Verse updates the field → parameter updates → bar/fill animates.

For motion that is not a material param: UMG **Auto Play** animations, or procedural Verse updates — Verse cannot call `PlayAnimation` by name (see `umg_widgets` myths).

### Textures

- Soft / hard texture fields bind through View Bindings (texture → brush conversion).
- Prefer Content Browser textures referenced by digest ids.
- Do not put `http://` image URLs in UI materials — use project assets.

### Related

- Fields: `umg_verse_fields`
- Bindings: `umg_view_bindings`
- General materials skill pack (`materials`) is for world meshes — UI materials stay on this path.
