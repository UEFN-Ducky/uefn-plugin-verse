---
description: "UMG MCP tools — probe-first workflow, create/inspect/tree/bindings, what is scriptable vs designer-only, crash bans for ToolsetRegistry schema dumps"
metadata:
  order: 65
  label: "UMG MCP tools workflow"
  default_enabled: false
  load_condition: "Using umg_* MCP tools to create or edit Widget Blueprints, inspect Verse fields on a UW_*, or scaffold a widget tree"
---

## UMG MCP tools workflow

Listener-backed tools gated by the **verse** Store plugin. Always start with the probe.

### Probe first

```
umg_capabilities()
```

Returns class presence (`WidgetBlueprint`, `UMGToolSet`, `MVVMEditorSubsystem`, …), known UMGToolSet tool names, and notes. **Never** call from `execute_python`:

- `ToolsetRegistry.get_all_toolset_json_schemas()`
- `ToolsetRegistry.get_toolset_json_schema(...)`

Those dumps hard-crash UnrealEditorFortnite (`EXCEPTION_ACCESS_VIOLATION`). The umg_* tools call `execute_tool` with **small known payloads only**.

Also: `uefn_editor_python_hints(topic="umg")`.

### Tool map

| Tool | Job |
|------|-----|
| `umg_capabilities` | Probe |
| `list_widget_blueprints` | Find `UW_*` / WidgetBlueprint assets |
| `get_widget_blueprint_info` | Member vars (Verse fields), event dispatchers, tree (GetWidgets), bindings |
| `create_widget_blueprint` | Empty WidgetBlueprint via `WidgetBlueprintFactory` |
| `add_widget_to_tree` | Scaffold child via UMGToolSet.AddWidget |
| `remove_widget_from_tree` | Remove instance |
| `set_widget_property` | ObjectTools list → set (names vary — list first) |
| `list_widget_bindings` | MVVM bindings |
| `add_widget_binding` / `remove_widget_binding` | Best-effort MVVM; complex binds → designer |

### Recommended agent flow

1. `umg_capabilities`
2. `create_widget_blueprint(asset_name="UW_MyHud", folder="")` (auto-pins `{content_root}UI`) **or** `list_widget_blueprints(search="UW_")` — never invent `/Game/UI`
3. Optional scaffold: `add_widget_to_tree(..., widget_class="CanvasPanel", widget_name="RootCanvas")` then TextBlock / Button children with `parent_ref_path` from info
4. `open_asset_in_uefn` — add Verse fields, View Bindings, polish layout
5. After digest refresh: `list_verse_types(digest="assets", name_filter="UW_")` → write Verse (`umg_widgets` / `umg_verse_fields` / `umg_verse_field_events`)
6. Template: `verse_template_apply("umg_widget")` for the device + event helpers

### Scriptable vs designer-only

| Scriptable (tools) | Designer (open_asset_in_uefn) |
|--------------------|-------------------------------|
| Create empty WBP | Visual layout polish |
| Add/remove basic tree widgets | Anchors, fancy slots, animations |
| List/set properties when ObjectTools works | Verse field declaration UI |
| List bindings / attempt add_binding | View Binding conversion graphs |
| Compile + save after edits | Auto Play animation tracks |

Tree tools are **scaffolding**. If `add_widget_to_tree` fails on a build, fall back to the designer — do not poke protected `WidgetTree` via `get_editor_property` (it is protected and will error).

### Runtime is still Verse

MCP tools edit **assets**. Showing UI in-game is always:

`GetPlayerUI[Player].AddWidget(MyUW, player_ui_slot{…})`

See `umg_widgets`.
