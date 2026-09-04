#!/usr/bin/env python3
"""Verse release gate — lint every Verse a plugin ships before it can be Store-published.

Checks ``templates/**/*.verse`` and every ```verse fence inside ``skills/**/*.md`` with the
app's ``verse_lint`` (backend/tools/verse/verse_lint.py in UEFN-Ducky-Release). Error-severity
findings fail the gate. The real UEFN build is still the final word (``verse_template_verify``
in the app); this gate catches the mechanical classes of mistake without UEFN.

Env:
  DUCKY_APP_ROOT  path to the UEFN-Ducky-Release checkout
                  (default: ../../UEFN-Ducky-Release next to uefn-plugins)
  DUCKY_VERSE_GATE=off  skip the gate (emergency only)

Usage:
  py scripts/verse_gate.py .
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_FENCE = re.compile(r"```verse[^\n]*\n(.*?)```", re.S)


def _import_lint():
    default_app = ROOT.parents[1] / "UEFN-Ducky-Release"  # GitHub/UEFN-Ducky-Release
    app_root = Path(os.environ.get("DUCKY_APP_ROOT") or default_app)
    ducky_app = app_root / "ducky_app"
    if not (ducky_app / "backend" / "tools" / "verse" / "verse_lint.py").is_file():
        return None
    if str(ducky_app) not in sys.path:
        sys.path.insert(0, str(ducky_app))
    try:
        from backend.tools.verse.verse_lint import lint_verse  # type: ignore
    except Exception:  # noqa: BLE001 - app import may need deps we do not have in CI
        return None
    return lint_verse


def _sources(folder: Path) -> list[tuple[str, str, bool]]:
    """(label, source, is_template) for every Verse the plugin ships."""
    out: list[tuple[str, str, bool]] = []
    for f in sorted((folder / "templates").rglob("*.verse")):
        out.append((str(f.relative_to(folder)).replace("\\", "/"), f.read_text(encoding="utf-8"), True))
    for md in sorted((folder / "skills").rglob("*.md")):
        text = md.read_text(encoding="utf-8", errors="replace")
        for i, m in enumerate(_FENCE.finditer(text), 1):
            out.append((f"{md.relative_to(folder)}#fence{i}".replace("\\", "/"), m.group(1), False))
    return out


def check_plugin(folder: Path, *, strict_fences: bool = False) -> tuple[int, list[str]]:
    """Return (error_count, report lines). Skill fences only count when strict_fences is set;
    they are often fragments (no class wrapper), so only template files are hard failures."""
    lint = _import_lint()
    if lint is None:
        return 0, ["verse gate: verse_lint not importable (set DUCKY_APP_ROOT) — skipped"]
    errors = 0
    lines: list[str] = []
    for label, src, is_template in _sources(folder):
        findings = lint(src, label)
        for f in findings:
            sev = str(f.get("severity") or "warning")
            counts = is_template or strict_fences
            if sev == "error" and counts:
                errors += 1
            lines.append(f"{'ERROR' if sev == 'error' and counts else 'warn '} {label}:{f.get('line')} [{f.get('rule')}] {f.get('message')}")
    lines.append(f"verse gate: {folder.name}: {errors} error(s), {len(lines)} finding(s)")
    return errors, lines


def main(argv: list[str]) -> int:
    if os.environ.get("DUCKY_VERSE_GATE", "").lower() == "off":
        print("verse gate: disabled by DUCKY_VERSE_GATE=off")
        return 0
    if not argv:
        print(__doc__)
        return 2
    total = 0
    for arg in argv:
        folder = (ROOT / arg) if not Path(arg).is_absolute() else Path(arg)
        if not (folder / "plugin.json").is_file():
            print(f"verse gate: {arg} is not a plugin folder")
            return 2
        errors, lines = check_plugin(folder)
        print("\n".join(lines))
        total += errors
    return 1 if total else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
