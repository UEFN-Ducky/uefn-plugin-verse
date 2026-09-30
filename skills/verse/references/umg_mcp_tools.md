---
description: "UMG MCP tools — probe-first workflow, create/inspect/tree/bindings, what is scriptable vs designer-only, crash bans for ToolsetRegistry schema dumps"
metadata:
  order: 65
  label: "UMG MCP tools workflow"
  default_enabled: false
  load_condition: "Using umg_* MCP tools to create or edit Widget Blueprints, inspect Verse fields on a UW_*, or scaffold a widget tree"
---

## UMG MCP tools workflow

**Probe first:** `ducky_get_status` → when `epic_mcp_online` use nested `unreal__*`
`UMGToolSet.UMGToolSet` / `MVVMToolset.MVVMToolset` / `VerseFieldsToolset.VerseFieldsToolset`
(describe then call). Listener `umg_*` is second. Never `execute_python`
`ToolsetRegistry.get_all_toolset_json_schemas()` (hard-crash).

Listener-backed tools gated by the **verse** Store plugin.

### Probe first

```
ducky_get_status
# epic_mcp_online → unreal__describe_toolset({ "toolset_name": "UMGToolSet.UMGToolSet" })
umg_capabilities()   # listener second
```

Returns class presence (`WidgetBlueprint`, `UMGToolSet`, `MVVMEditorSubsystem`, …), known UMGToolSet tool names, and notes. **Never** call from `execute_python`:

- `ToolsetRegistry.get_all_toolset_json_schemas()`
- `ToolsetRegistry.get_toolset_json_schema(...)`

Those dumps hard-crash UnrealEditorFortnite (`EXCEPTION_ACCESS_VIOLATION`). The umg_* tools call `execute_tool` with **small known payloads only**.

Also: `uefn_editor_python_hints(topic="umg")`.

### Tool map

| Tool | Job |
|------|-----|
| `umg_capabilities` | Probe classes and toolsets |
| `list_widget_classes` / `get_widget_class_info` | Palette. Call before a class name |
| `build_widget_tree` | Nested `{class, name, slot, properties, children}`. One compile |
| `set_widget_slot` | Anchors, offsets, alignment, ZOrder, padding, grid |
| `list_named_slots` / `set_named_slot_content` | Named slot fill |
| `get_widget_blueprint_info` | Tree, `slots`, animation key counts, `verse_fields`, `view_bindings` |
| `create_widget_animation` / `add_animation_keys` / `list_widget_animations` | Opacity, Color, Transform keys |
| `add_verse_field` / `list_verse_fields` | bool, int, float, string, message, color, texture, material. `logic` → bool. `event` is refused |
| `bind_verse_field` | Verse field → widget property, optional conversion |
| `bind_widget_event` | `OnClicked` / `OnButtonHighlight` → a Verse field |
| `list_bindable_properties` | Destination and event names |

### Recommended agent flow

1. `ducky_get_status`. Epic `unreal__*` when `epic_mcp_online`. Listener tools otherwise.
2. `list_widget_classes`.
3. `build_widget_tree` (`umg_recipes`). Folder `""` pins `{content_root}/UI`. Never invent `/Game/UI`.
4. `create_widget_animation` + `add_animation_keys`.
5. `add_verse_field` + `bind_verse_field` + `bind_widget_event`.
6. `get_widget_blueprint_info` must show anchors, `z_order`, key counts, and `view_bindings.binding_count`.
7. Verse build, then `list_verse_types(digest="assets")`. Device: `verse_template_apply("umg_widget")`.

### In-editor preview (v42.20)

Preview and interact with widgets **in the UMG editor** — do not Launch Session
just to see an animation play or button text update. Multiple in-world UMG
instances of the same class now all show Verse-bound values (pre-42.20 only
the first instance did).

### What the tools write

Tree, canvas anchors, ZOrder, image brushes, opacity/color/transform keys, Verse fields except `event`, and event→field bindings. `event()` creation is refused by `AddVerseField` — use a bool field or an event the digest already lists. Material-parameter MovieScene tracks are not exposed; use a Verse float and `Conv_SetScalarParameter`.

Never `get_editor_property` on `WidgetTree`. Never dump a toolset JSON schema. Never patch `.uasset` bytes.

### Runtime is still Verse

MCP tools edit **assets**. Showing UI in-game is always:

`GetPlayerUI[Player].AddWidget(MyUW, player_ui_slot{…})`

See `umg_widgets`.
