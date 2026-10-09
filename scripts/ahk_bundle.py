#!/usr/bin/env python3
"""Shared helpers for bundling AutoHotkey v2 sources into one standalone file.

Every generated artifact in this repository (the production release and the
Windows field harnesses) is a plain concatenation of source components with
``#Include`` lines and the per-file directives removed. This module owns that
logic so the individual builders only declare *which* components they bundle.
"""

from __future__ import annotations

from collections.abc import Callable, Iterable, Sequence
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

# Field harnesses run as a single foreground script per machine.
HARNESS_DIRECTIVES = (
    "#Requires AutoHotkey v2.0",
    "#SingleInstance Force",
    "#Warn",
)

# The production EXE manages its own singleton mutex in app_startup.ahk.
RELEASE_DIRECTIVES = (
    "#Requires AutoHotkey v2.0",
    "#SingleInstance Off",
    "#Warn",
)

# UIA-v2 opens its inspector when run directly; a bundle must never do that.
UIA_STANDALONE_ENTRYPOINT = (
    "if !A_IsCompiled && A_LineFile = A_ScriptFullPath\n"
    "    UIA.Viewer()\n"
)

Transform = Callable[[str, str], str]


def strip_bom(text: str) -> str:
    """Remove only a leading U+FEFF byte-order mark."""
    return text[1:] if text.startswith("﻿") else text


def read_component(path: Path) -> str:
    return strip_bom(path.read_text(encoding="utf-8"))


def is_uia_component(relative_path: str) -> bool:
    return relative_path.replace("\\", "/").endswith("Lib/UIA.ahk")


def strip_uia_entrypoint(text: str) -> str:
    if UIA_STANDALONE_ENTRYPOINT not in text:
        raise ValueError("UIA standalone entrypoint was not found")
    return text.replace(UIA_STANDALONE_ENTRYPOINT, "", 1)


def strip_includes_and_directives(
    text: str,
    directives: Sequence[str],
    *,
    strip_leading: bool = True,
) -> str:
    """Drop ``#Include`` lines and the listed directives; trim line ends.

    ``strip_leading`` controls whether leading blank lines are removed as
    well (harness builders) or only trailing ones (the release builder).
    """
    lowered = {directive.lower() for directive in directives}
    lines: list[str] = []
    for line in text.splitlines():
        if line.lstrip().lower().startswith("#include"):
            continue
        if line.strip().lower() in lowered:
            continue
        lines.append(line.rstrip())
    joined = "\n".join(lines)
    return (joined.strip() if strip_leading else joined.rstrip()) + "\n"


def between(text: str, start: str, end: str) -> str:
    """Return ``start`` plus everything up to (excluding) the next ``end``."""
    return start + text.split(start, 1)[1].split(end, 1)[0]


def verify_bundle(text: str, label: str = "bundle") -> str:
    if "﻿" in text:
        raise ValueError(f"Generated {label} contains an embedded U+FEFF")
    if any(
        line.lstrip().lower().startswith("#include")
        for line in text.splitlines()
    ):
        raise ValueError(f"Generated {label} still contains #Include")
    return text


def bundle(
    header: Iterable[str],
    components: Sequence[str],
    *,
    root: Path = ROOT,
    directives: Sequence[str] = HARNESS_DIRECTIVES,
    transform: Transform | None = None,
    strip_leading: bool = True,
    label: str = "bundle",
    missing_message: str = "Missing component",
    echo: Callable[[str], None] | None = None,
) -> str:
    """Concatenate ``components`` (repository-relative paths) after ``header``.

    ``transform`` receives ``(text, relative_path)`` for each component before
    includes and directives are stripped; use it for metadata stamping or for
    extracting a subset of a file.
    """
    parts = [*header, "", *directives, ""]
    for relative_path in components:
        path = root / relative_path
        if not path.is_file():
            raise FileNotFoundError(f"{missing_message}: {path}")
        if echo is not None:
            echo(relative_path)
        text = read_component(path)
        if is_uia_component(relative_path):
            text = strip_uia_entrypoint(text)
        if transform is not None:
            text = transform(text, relative_path)
        parts.extend(
            (
                f"; --- BEGIN {relative_path} ---",
                strip_includes_and_directives(
                    text, directives, strip_leading=strip_leading
                ),
                f"; --- END {relative_path} ---",
                "",
            )
        )
    return verify_bundle("\n".join(parts).rstrip() + "\n", label)


def write_bundle(text: str, output: Path) -> Path:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")
    print(f"Wrote {output}")
    print(f"Size: {output.stat().st_size} bytes")
    return output
