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
    "window_guard.ahk",
    "utils.ahk",
    "clipboard_html.ahk",
    "medex_color_reset_logic.ahk",
    "diagnostics.ahk",
    "adapters/medex_report_editor.ahk",
    "report_editor.ahk",
    "viewer_actions.ahk",
    "hotstrings.ahk",
    "main.ahk",
]


UIA_STANDALONE_ENTRYPOINT = (
    "if !A_IsCompiled && A_LineFile = A_ScriptFullPath\n"
    "    UIA.Viewer()\n"
)


def prepare_source(text: str, relative_name: str) -> str:
    if relative_name == "Lib/UIA.ahk":
        if UIA_STANDALONE_ENTRYPOINT not in text:
            raise ValueError("UIA standalone entrypoint was not found")
        text = text.replace(UIA_STANDALONE_ENTRYPOINT, "", 1)

    lines = []
    for line in text.splitlines():
        if line.lstrip().lower().startswith("#include"):
            continue
        lines.append(line.rstrip())
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    metadata = (SRC / "app_metadata.ahk").read_text(encoding="utf-8")
    version_marker = 'static Version := "'
    if version_marker not in metadata:
        raise ValueError("AppMetadata.Version was not found")
    version = metadata.split(version_marker, 1)[1].split('"', 1)[0]

    parts = [
        "; Generated file. Edit src/*.ahk instead.",
        f"; Application version: {version}",
        f"; Generated at: {timestamp}",
        "",
    ]

    for name in ORDER:
        path = SRC / name
        if not path.exists():
            raise FileNotFoundError(f"Missing source file: {path}")

        print(f"Adding {path.relative_to(ROOT)}")
        parts.append(f"; --- BEGIN {name} ---")
        parts.append(prepare_source(path.read_text(encoding="utf-8"), name))
        parts.append(f"; --- END {name} ---")
        parts.append("")

    OUTPUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
