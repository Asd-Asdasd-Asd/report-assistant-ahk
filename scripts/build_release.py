#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUTPUT = ROOT / "release" / "report_assistant.ahk"

ORDER = [
    "config.example.ahk",
    "window_guard.ahk",
    "utils.ahk",
    "clipboard_html.ahk",
    "report_editor.ahk",
    "viewer_actions.ahk",
    "hotstrings.ahk",
    "main.ahk",
]


def strip_include_lines(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if line.lstrip().lower().startswith("#include"):
            continue
        lines.append(line)
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    parts = [
        "; Generated file. Edit src/*.ahk instead.",
        f"; Generated at: {timestamp}",
        "",
    ]

    for name in ORDER:
        path = SRC / name
        if not path.exists():
            raise FileNotFoundError(f"Missing source file: {path}")

        print(f"Adding {path.relative_to(ROOT)}")
        parts.append(f"; --- BEGIN {name} ---")
        parts.append(strip_include_lines(path.read_text(encoding="utf-8")))
        parts.append(f"; --- END {name} ---")
        parts.append("")

    OUTPUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
