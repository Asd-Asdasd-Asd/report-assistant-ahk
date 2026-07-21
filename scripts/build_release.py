#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUTPUT = ROOT / "release" / "report_assistant.ahk"

ORDER = [
    "app_metadata.ahk",
    "Lib/UIA.ahk",
    "config.example.ahk",
    "app_config.ahk",
    "window_guard.ahk",
    "utils.ahk",
    "clipboard_html.ahk",
    "medex_color_reset_logic.ahk",
    "medex_candidate_g_logic.ahk",
    "diagnostics.ahk",
    "adapters/medex_report_editor.ahk",
    "report_editor.ahk",
    "viewer_actions.ahk",
    "feature_model.ahk",
    "hotstring_model.ahk",
    "hotstring_config.ahk",
    "config_reconciliation.ahk",
    "config_bootstrap.ahk",
    "hotstring_normalization.ahk",
    "hotstring_registration.ahk",
    "hotstrings.ahk",
    "feature_config.ahk",
    "feature_normalization.ahk",
    "hotkey_registration.ahk",
    "global_hjkl_arrows.ahk",
    "features.ahk",
    "main.ahk",
]


UIA_STANDALONE_ENTRYPOINT = (
    "if !A_IsCompiled && A_LineFile = A_ScriptFullPath\n"
    "    UIA.Viewer()\n"
)

RELEASE_DIRECTIVES = (
    "#Requires AutoHotkey v2.0",
    "#SingleInstance Force",
    "#Warn",
)


def strip_leading_component_bom(text: str) -> str:
    """Remove only a component's leading U+FEFF byte-order mark."""
    return text[1:] if text.startswith("\ufeff") else text


def read_component(path: Path) -> str:
    return strip_leading_component_bom(path.read_text(encoding="utf-8"))


def prepare_source(text: str, relative_name: str) -> str:
    if relative_name == "Lib/UIA.ahk":
        if UIA_STANDALONE_ENTRYPOINT not in text:
            raise ValueError("UIA standalone entrypoint was not found")
        text = text.replace(UIA_STANDALONE_ENTRYPOINT, "", 1)

    lines = []
    for line in text.splitlines():
        if line.lstrip().lower().startswith("#include"):
            continue
        if line.strip().lower() in {directive.lower() for directive in RELEASE_DIRECTIVES}:
            continue
        lines.append(line.rstrip())
    return "\n".join(lines).rstrip() + "\n"


def build_release_text(
    source_dir: Path = SRC,
    order: list[str] = ORDER,
    timestamp: str | None = None,
) -> str:
    if timestamp is None:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    metadata = read_component(source_dir / "app_metadata.ahk")
    version_marker = 'static Version := "'
    if version_marker not in metadata:
        raise ValueError("AppMetadata.Version was not found")
    version = metadata.split(version_marker, 1)[1].split('"', 1)[0]

    parts = [
        "; Generated file. Edit src/*.ahk instead.",
        f"; Application version: {version}",
        f"; Generated at: {timestamp}",
        "",
        *RELEASE_DIRECTIVES,
        "",
    ]

    for name in order:
        path = source_dir / name
        if not path.exists():
            raise FileNotFoundError(f"Missing source file: {path}")

        try:
            display_path = path.relative_to(ROOT)
        except ValueError:
            display_path = path
        print(f"Adding {display_path}")
        parts.append(f"; --- BEGIN {name} ---")
        parts.append(prepare_source(read_component(path), name))
        parts.append(f"; --- END {name} ---")
        parts.append("")

    release_text = "\n".join(parts)
    if "\ufeff" in release_text:
        raise ValueError("Generated release contains an embedded U+FEFF character")
    return release_text


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    release_text = build_release_text()
    OUTPUT.write_bytes(release_text.encode("utf-8"))

    written_text = OUTPUT.read_bytes().decode("utf-8")
    bom_count = written_text.count("\ufeff")
    if bom_count != 0:
        raise ValueError(f"Generated release BOM scan failed: count={bom_count}")

    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    print(f"Embedded U+FEFF count: {bom_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
