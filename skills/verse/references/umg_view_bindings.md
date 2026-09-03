---
description: "UMG View Bindings + viewmodel — bind Verse fields / viewmodel properties to widget props, ToText conversions, textures from viewmodel, one-way vs two-way"
metadata:
  order: 63
  label: "UMG View Bindings & viewmodel"
  default_enabled: false
  load_condition: "Wiring View Bindings or a viewmodel on a User Widget, ToText conversions, or showing textures/materials from bindings"
---

## UMG View Bindings & viewmodel

**View Bindings** connect a data source (Verse field on the User Widget, or a viewmodel) to a widget property (text, brush, visibility, material param, etc.). This is how Verse fields actually paint the UI — `set MyWidget.Progress = 0.5` only updates the bar if Progress is bound.

Epic docs: *Using View Bindings in UMG*, conversion-function tutorials (ToText Int/Double, textures from viewmodel, material parameters).

### Workflow in the designer

1. Open the User Widget.
2. Add Verse fields (`umg_verse_fields`) and/or a **viewmodel** entry in the View Bindings panel.
3. For each visual you want driven: create a binding **source → destination**.
4. Add a **conversion function** when types differ (float → text, soft texture → brush, etc.).
5. Save. Drive sources from Verse with `set MyWidget.Field = …`.

### Conversion functions agents use most

| Conversion | Use |
|------------|-----|
| **ToText (Int)** / **ToText (Double)** | Numbers → `Text` / message display |
| Texture / soft texture → brush | Icons and images from a viewmodel or Verse texture field |
| Material parameter setters | Drive scalar/vector params on a UI material (see `umg_ui_materials`) |

Always pick the conversion from the **available conversion functions** list in the binding UI (or `MVVMEditorSubsystem.get_available_conversion_functions` via tools) — do not invent names.

### One-way vs two-way

- **38.00 Verse fields:** Verse → widget (one-way). Good for HUD values, materials, messages.
- **Widget → Verse:** use **Verse field events** (39.40+) for clicks, not two-way field writes, unless digests show a two-way binding mode for your case.
- Viewmodel bindings may support more modes in the MVVM panel — check Binding Mode on the binding itself.

### When a binding re-evaluates

Bindings refresh when the **source** changes (Verse `set`, viewmodel notify). If the UI is stale:

1. Confirm the widget is on `player_ui`.
2. Confirm the field name matches the digest.
3. Confirm the binding exists (`list_widget_bindings` / designer).
4. Confirm the conversion function accepts the source type.

### MCP helpers

- `list_widget_bindings(widget_path)` — see what is already wired.
- `add_widget_binding` / `remove_widget_binding` — best-effort via `MVVMEditorSubsystem`; complex paths often finish faster in the designer (`open_asset_in_uefn`).
- Details: `umg_mcp_tools`.

### Related

- Field authoring: `umg_verse_fields`
- Button events: `umg_verse_field_events`
- UI materials: `umg_ui_materials`
