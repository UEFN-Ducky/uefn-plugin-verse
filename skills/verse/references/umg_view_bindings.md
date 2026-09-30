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

### Workflow

1. `add_verse_field` (`umg_verse_fields`).
2. `list_bindable_properties(widget_path, widget_name)` for the destination name (`RenderOpacity`, `Visibility`, `ColorAndOpacity`, …).
3. `bind_verse_field(widget_path, source_field, widget_name, destination_property, conversion_name)`. Source context empty means the widget blueprint (the Verse field). Verified: `TriggerIntro` → `ButtonFill.RenderOpacity`.
4. `bind_widget_event` for clicks (`umg_verse_field_events`).
5. `get_widget_blueprint_info` → `view_bindings.binding_count`. Drive with `set MyWidget.Field = …`.

### Conversion functions agents use most

| Conversion name | Use |
|-----------------|-----|
| `Conv_IntToText` / `Conv_DoubleToText` | Numbers → text |
| `MakeImageBrushFromTexture` / `MakeImageBrushFromMaterial` | Texture or material → brush |
| `Conv_SetScalarParameter` / `Conv_SetVectorParameter` | Material parameter on the brush |
| `Conv_BoolToSlateVisibility` | `logic` / bool → visibility |
| `Conv_LinearColorToSlateColor` | Color field → `ColorAndOpacity` |

Pass `conversion_name` only when the source type differs from the property. Empty string is a direct bind (bool → `RenderOpacity` was accepted). Do not invent a name that is not in this list.

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

- `bind_verse_field` / `bind_widget_event` — the writes.
- `get_widget_blueprint_info` → `view_bindings`.
- Details: `umg_mcp_tools`.

### Related

- Field authoring: `umg_verse_fields`
- Button events: `umg_verse_field_events`
- UI materials: `umg_ui_materials`
