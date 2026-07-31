"""Verse — Store desktop plugin (MCP tools + New-file template packs)."""

from __future__ import annotations

import json
from typing import Any


def _templates() -> list[dict[str, Any]]:
    from backend.uefn_plugins.host import get_contributions

    rows = get_contributions().get("verse_templates") or []
    return [r for r in rows if isinstance(r, dict) and r.get("plugin_id") == "verse"]


def _find(template_id: str) -> dict[str, Any] | None:
    tid = (template_id or "").strip()
    if not tid:
        return None
    for row in _templates():
        if str(row.get("id") or "") == tid:
            return row
    return None


def _register_template_tools(api) -> None:
    @api.tool(
        intent=r"\b(verse\s*template|economy_manager|progression_manager|player_core|tycoon|shop_controller)\b"
    )
    def verse_template_list() -> str:
        """List Verse system template packs from the UEFN Verse plugin (id, name, files, connects).

        Call this BEFORE inventing player/economy/progression/tycoon/shop/timer Verse files.
        Prefer verse_template_apply / verse_template_get over writing parallel scaffolds.
        """
        out = []
        for row in _templates():
            files = row.get("files") or []
            paths = [
                str(f.get("path") or "")
                for f in files
                if isinstance(f, dict) and f.get("path")
            ]
            if not paths and row.get("file"):
                paths = [str(row.get("file"))]
            out.append(
                {
                    "id": row.get("id"),
                    "name": row.get("name"),
                    "description": row.get("description") or "",
                    "folder": row.get("folder") or "",
                    "paths": paths,
                    "connects": row.get("connects") or [],
                    "order": row.get("order") or 100,
                }
            )
        return json.dumps({"ok": True, "templates": out}, indent=2)

    @api.tool(intent=r"\b(verse\s*template|economy_manager|progression_manager|player_core)\b")
    def verse_template_get(template_id: str) -> str:
        """Return full Verse source for one template pack (paths + content).

        Use after verse_template_list. Prefer applying the pack over rewriting it.
        """
        row = _find(template_id)
        if not row:
            return json.dumps(
                {"ok": False, "error": f"unknown template_id: {template_id}"},
                indent=2,
            )
        files = row.get("files") or []
        pack = []
        if isinstance(files, list) and files:
            for f in files:
                if isinstance(f, dict) and f.get("path") is not None:
                    pack.append({"path": f.get("path"), "content": f.get("content") or ""})
        else:
            pack.append(
                {
                    "path": str(row.get("file") or f"{row.get('id')}.verse").split("/")[-1],
                    "content": row.get("content") or "",
                }
            )
        return json.dumps(
            {
                "ok": True,
                "id": row.get("id"),
                "name": row.get("name"),
                "description": row.get("description") or "",
                "folder": row.get("folder") or "",
                "connects": row.get("connects") or [],
                "files": pack,
            },
            indent=2,
        )

    @api.tool(intent=r"\b(verse\s*template|apply\s*template|scaffold)\b")
    def verse_template_apply(template_id: str, parent_relative: str = "Content/Verse") -> str:
        """Write a Verse template pack into the project (folder + .verse files).

        parent_relative defaults to Content/Verse. Multi-file packs create folder/
        then each file. Prefer this over inventing economy/progression/player scaffolds.
        """
        row = _find(template_id)
        if not row:
            return json.dumps(
                {"ok": False, "error": f"unknown template_id: {template_id}"},
                indent=2,
            )
        from frontend.ui_web.project_files import (
            create_project_folder,
            create_project_verse_file,
        )

        parent = (parent_relative or "Content/Verse").strip().replace("\\", "/").strip("/")
        if not parent:
            parent = "Content/Verse"
        files = row.get("files") or []
        created: list[str] = []
        try:
            pack_root = parent
            folder = str(row.get("folder") or "").strip().replace("\\", "/").strip("/")
            if folder and ".." not in folder.split("/"):
                for n in range(0, 50):
                    candidate = folder if n == 0 else f"{folder}{n + 1}"
                    try:
                        result = create_project_folder(parent, candidate)
                        pack_root = result["path"]
                        created.append(pack_root)
                        break
                    except ValueError as exc:
                        if "Already exists" not in str(exc):
                            raise
                else:
                    return json.dumps(
                        {"ok": False, "error": f"could not create folder {folder}"},
                        indent=2,
                    )

            pack_files: list[dict[str, str]] = []
            if isinstance(files, list) and files:
                for f in files:
                    if isinstance(f, dict) and f.get("path"):
                        pack_files.append(
                            {"path": str(f["path"]), "content": str(f.get("content") or "")}
                        )
            else:
                fname = str(row.get("file") or f"{row.get('id')}.verse").split("/")[-1]
                pack_files.append({"path": fname, "content": str(row.get("content") or "")})

            made_dirs: set[str] = {pack_root}
            for item in pack_files:
                rel = item["path"].replace("\\", "/").lstrip("/")
                if not rel or ".." in rel.split("/"):
                    continue
                parts = [p for p in rel.split("/") if p]
                if not parts:
                    continue
                file_name = parts[-1]
                dir_path = pack_root
                for seg in parts[:-1]:
                    nxt = f"{dir_path}/{seg}"
                    if nxt not in made_dirs:
                        try:
                            made = create_project_folder(dir_path, seg)
                            dir_path = made["path"]
                            made_dirs.add(dir_path)
                            created.append(dir_path)
                        except ValueError:
                            dir_path = nxt
                            made_dirs.add(nxt)
                    else:
                        dir_path = nxt
                result = create_project_verse_file(dir_path, file_name, item["content"])
                created.append(result["path"])
        except Exception as exc:  # noqa: BLE001
            return json.dumps({"ok": False, "error": str(exc)}, indent=2)

        return json.dumps(
            {
                "ok": True,
                "id": row.get("id"),
                "folder": pack_root if folder else "",
                "created": created,
            },
            indent=2,
        )

    api.log("verse template MCP tools registered")


_UMG_INTENT = (
    r"\b(umg|user\s*widget|widget\s*blueprint|view\s*binding|viewmodel|verse\s*field|"
    r"uw_|canvas\s*panel|text\s*block)\b"
)


def _umg_json(api, command: str, params: dict, *, pretty: bool = False) -> str:
    result = api.listener(command, params)
    if pretty:
        return json.dumps(result, indent=2, ensure_ascii=False, default=str)
    return json.dumps(result, ensure_ascii=False, default=str)


def _register_umg_tools(api) -> None:
    """UMG tools ship in this plugin zip via api.tool — app EXE may not have backend.tools.verse.umg yet."""

    @api.tool(intent=_UMG_INTENT)
    def umg_capabilities(pretty: bool = False) -> str:
        """Probe UMG / MVVM / ToolsetRegistry availability (run before other umg tools). Never dumps schemas."""
        return _umg_json(api, "umg_capabilities", {}, pretty=pretty)

    @api.tool(intent=_UMG_INTENT)
    def list_widget_blueprints(
        search: str = "", offset: int = 0, limit: int = 50, pretty: bool = False
    ) -> str:
        """List WidgetBlueprint assets in the project (filter with search, paged)."""
        return _umg_json(
            api,
            "list_widget_blueprints",
            {"search": search, "offset": offset, "limit": limit},
            pretty=pretty,
        )

    @api.tool(intent=_UMG_INTENT)
    def get_widget_blueprint_info(widget_path: str, pretty: bool = False) -> str:
        """Inspect a WidgetBlueprint: member vars (Verse fields), event dispatchers, tree, MVVM bindings."""
        return _umg_json(api, "get_widget_blueprint_info", {"widget_path": widget_path}, pretty=pretty)

    @api.tool(intent=_UMG_INTENT)
    def create_widget_blueprint(
        asset_name: str,
        folder: str = "",
        parent_class: str = "UserWidget",
        pretty: bool = False,
    ) -> str:
        """Create an empty WidgetBlueprint (errors if it already exists). Prefer UW_ name prefix."""
        return _umg_json(
            api,
            "create_widget_blueprint",
            {"asset_name": asset_name, "folder": folder, "parent_class": parent_class},
            pretty=pretty,
        )

    @api.tool(intent=_UMG_INTENT)
    def add_widget_to_tree(
        widget_path: str,
        widget_class: str,
        widget_name: str,
        parent_ref_path: str = "",
        pretty: bool = False,
    ) -> str:
        """Add a widget under a panel via UMGToolSet.AddWidget. Scaffold only — polish in the designer."""
        return _umg_json(
            api,
            "add_widget_to_tree",
            {
                "widget_path": widget_path,
                "widget_class": widget_class,
                "widget_name": widget_name,
                "parent_ref_path": parent_ref_path,
            },
            pretty=pretty,
        )

    @api.tool(intent=_UMG_INTENT)
    def remove_widget_from_tree(widget_path: str, widget_ref_path: str, pretty: bool = False) -> str:
        """Remove a widget instance from the tree via UMGToolSet.RemoveWidget."""
        return _umg_json(
            api,
            "remove_widget_from_tree",
            {"widget_path": widget_path, "widget_ref_path": widget_ref_path},
            pretty=pretty,
        )

    @api.tool(intent=_UMG_INTENT)
    def set_widget_property(
        widget_path: str,
        target_ref_path: str,
        properties: dict,
        list_first: bool = True,
        pretty: bool = False,
    ) -> str:
        """Set properties on a widget/slot via ObjectTools (list_properties first by default)."""
        return _umg_json(
            api,
            "set_widget_property",
            {
                "widget_path": widget_path,
                "target_ref_path": target_ref_path,
                "properties": properties,
                "list_first": list_first,
            },
            pretty=pretty,
        )

    @api.tool(intent=_UMG_INTENT)
    def list_widget_bindings(widget_path: str, pretty: bool = False) -> str:
        """List MVVM view bindings on a WidgetBlueprint."""
        return _umg_json(api, "list_widget_bindings", {"widget_path": widget_path}, pretty=pretty)

    @api.tool(intent=_UMG_INTENT)
    def add_widget_binding(
        widget_path: str,
        source_path: str = "",
        destination_path: str = "",
        pretty: bool = False,
    ) -> str:
        """Add an MVVM binding (best-effort; finish complex binds in the View Bindings panel)."""
        return _umg_json(
            api,
            "add_widget_binding",
            {
                "widget_path": widget_path,
                "source_path": source_path,
                "destination_path": destination_path,
            },
            pretty=pretty,
        )

    @api.tool(intent=_UMG_INTENT)
    def remove_widget_binding(widget_path: str, binding_index: int = 0, pretty: bool = False) -> str:
        """Remove an MVVM binding by index."""
        return _umg_json(
            api,
            "remove_widget_binding",
            {"widget_path": widget_path, "binding_index": binding_index},
            pretty=pretty,
        )

    api.log("umg MCP tools registered")


def register(api) -> None:
    """Import gated MCP tools onto the shared FastMCP instance."""
    import backend.tools.verse.verse  # noqa: F401
    import backend.tools.verse.verse_focused  # noqa: F401
    import backend.tools.verse.verse_editable  # noqa: F401
    import backend.tools.verse.verse_diagnostics  # noqa: F401
    import backend.tools.verse.skill_tool  # noqa: F401

    _register_template_tools(api)
    _register_umg_tools(api)
    api.log("verse tools registered")
